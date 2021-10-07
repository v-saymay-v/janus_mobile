import 'dart:collection';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'janus_client/janus_client.dart';
import 'janus_client/utils.dart';
import 'janus_client/Plugin.dart';

import 'dart:async';

class VideoRoom extends StatefulWidget {
  VideoRoom({this.roomno, this.displayname});
  List<RTCVideoView> remote_videos = new List();
  final int roomno;
  final String displayname;
  @override
  _VideoRoomState createState() => _VideoRoomState();
}

class _VideoRoomState extends State<VideoRoom> {
  JanusClient j;
  RTCVideoRenderer _localRenderer = new RTCVideoRenderer();
  List<RTCVideoRenderer> _remoteRenderer = new List<RTCVideoRenderer>();
  Plugin pluginHandle;
  Plugin subscriberHandle;
  List<MediaStream> remoteStream = new List<MediaStream>();
  MediaStream myStream;

  @override
  void didChangeDependencies() async {
    // TODO: implement didChangeDependencies
    super.didChangeDependencies();
  }

  @override
  void initState() {
    super.initState();
    //initRenderers();
    initRoom();
  }

  initRoom() async {
    await this.initRenderers();
    await this.initPlatformState();
  }

  initRenderers() async {
    int count = 0;
    while (count < 4) {
      _remoteRenderer.add(new RTCVideoRenderer());
      count++;
    }
    await _localRenderer.initialize();
    for (var renderer in _remoteRenderer) {
      await renderer.initialize();
    }
    count = 0;
    while (count < 4) {
      createLocalMediaStream("local").then((value) => remoteStream.add(value));
      count++;
    }
  }

  _newRemoteFeed(JanusClient j, List<Map> feeds) async {
    List<Map> myFeeds = feeds;
    print('remote plugin attached');
    j.attach(Plugin(
      plugin: 'janus.plugin.videoroom',
      onMessage: (msg, jsep) async {
        if (jsep != null) {
          await subscriberHandle.handleRemoteJsep(jsep);
          // var body = {"request": "start", "room": 2157};
          var body = {
            "request": "start",
            "room": widget.roomno,
          };
          await subscriberHandle.send(
              message: body,
              jsep: await subscriberHandle.createAnswer(),
              onSuccess: () {});
        }
      },
      onSuccess: (plugin) {
        setState(() {
          subscriberHandle = plugin;
        });
        var register = {
          "request": "join",
          "room": widget.roomno,
          "ptype": "subscriber",
          "streams": feeds,
        };
        print("Requesting to subscribe to publishers...");
        subscriberHandle.send(message: register, onSuccess: () async {});
      },
      onRemoteStream: (dyn/*, track, mid, on*/) {
        MediaStream stream = dyn as MediaStream;
        print('got remote track with mid=${stream.id}');
        setState(() {
          for (MediaStreamTrack track in stream.getVideoTracks()) {
            if ((track as MediaStreamTrack).kind == "video"/* && on == true*/) {
              if (num.tryParse(stream.id).toInt() < 4) {
                remoteStream
                  .elementAt(num.tryParse(stream.id).toInt())
                  .addTrack(track, addToNative: true);
                print('added track to stream locally');
                _remoteRenderer
                  .elementAt(num.tryParse(stream.id as String).toInt())
                  .srcObject =
                  remoteStream.elementAt(num.tryParse(stream.id).toInt());
              }
            }
          }
        });
      }));
  }

  registerToRoom(plugin) {
    var register = {
      "request": "join",
      "room": widget.roomno,
      "ptype": "publisher",
      "display": widget.displayname // 'User test'
    };
    plugin.send(
      message: register,
      onSuccess: () async {
        var publish = {
          "request": "configure",
          "audio": true,
          "video": true,
          "bitrate": 2000000
        };
        RTCSessionDescription offer = await plugin.createOffer();
        plugin.send(message: publish, jsep: offer, onSuccess: () {});
      });
  }

  Future<void> initPlatformState() async {
    setState(() {
      j = JanusClient(iceServers: [
        RTCIceServer(
            url: "stun:40.85.216.95:3478",
            username: "onemandev",
            credential: "SecureIt"),
        RTCIceServer(
            url: "turn:40.85.216.95:3478",
            username: "onemandev",
            credential: "SecureIt"),
      ], server: [
        //'https://janus.conf.meetecho.com/janus',
        //'https://janus.onemandev.tech/janus',
        'https://room.yourcompany.com:8089/janus',
      ], withCredentials: true/*, isUnifiedPlan: true*/);
      j.connect(onSuccess: (sessionId) async {
        debugPrint('voilla! connection established with session id as' +
            sessionId.toString());
        Map<String, dynamic> configuration = {
          "iceServers": j.iceServers.map((e) => e.toMap()).toList()
        };

        j.attach(Plugin(
          opaqueId: "videoroom_user",
          plugin: 'janus.plugin.videoroom',
          onMessage: (msg, jsep) async {
            print('publisheronmsg');
            if (msg["publishers"] != null) {
              var list = msg["publishers"];
              print('got publihers');
              print(list);
              List<Map> subscription = new List<Map>();
              //    _newRemoteFeed(j, list[0]["id"]);
              final filtereList = List.from(list);
              filtereList.forEach((item) => {
                subscription.add({
                  "feed": LinkedHashMap.of(item).remove("id"),
                  "mid": "1"
                })
              });
              //Map.from(item)..forEach((key, value) => if(key != ("id")) ));
              _newRemoteFeed(j, subscription);
            }

            if (jsep != null) {
              pluginHandle.handleRemoteJsep(jsep);
            }
          },
          onSuccess: (plugin) async {
            setState(() {
              pluginHandle = plugin;
            });
            MediaStream stream = await plugin.initializeMediaDevices();
            setState(() {
              myStream = stream;
            });
            setState(() {
              _localRenderer.srcObject = myStream;
            });

            var exists = {
              "request" : "exists",
              //"pin": $('#videoRoomPin').val(),
              "room" : widget.roomno
            };
            plugin.send(
              message: exists,
              onSuccess: (result) async {
                bool exists = false;
                Map<String, dynamic> results = result as Map<String, dynamic>;
                if (results.containsKey('exists')) {
                  exists = results['exists'];
                }
                if (!exists) {
                  var create = {
                    "request": "create",
                    "room": widget.roomno,
                    //"secret": $('#videoRoomPass').val(),
                    //"pin": $('#videoRoomPin').val(),
                    "permanent": false,
                    "is_private_id": true,
                    //"record": $('#record_meeting').val==='true',
                    "rec_dir": '/home/janus/share/video',
                    "publishers": 200
                  };
                  plugin.send(
                    message: create,
                    onSuccess: () async {
                      registerToRoom(plugin);
                    });
                } else {
                  registerToRoom(plugin);
                }
              });
            /*
            var register = {
              "request": "join",
              "room": widget.roomno,
              "ptype": "publisher",
              "display": widget.displayname // 'User test'
            };
            plugin.send(
                message: register,
                onSuccess: () async {
                  var publish = {
                    "request": "configure",
                    "audio": true,
                    "video": true,
                    "bitrate": 2000000
                  };
                  RTCSessionDescription offer = await plugin.createOffer();
                  plugin.send(
                      message: publish, jsep: offer, onSuccess: () {});
                });
             */
          }));
      }, onError: (e) {
        debugPrint('some error occured');
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: [
          /*
          IconButton(
            icon: Icon(
              Icons.call,
              color: Colors.greenAccent,
            ),
            onPressed: () async {
              await this.initRenderers();
              await this.initPlatformState();
//                  -_localRenderer.
            }),
          */
          IconButton(
            icon: Icon(
              Icons.call_end,
              color: Colors.red,
            ),
            onPressed: () {
              j.destroy();
              pluginHandle.hangup();
              if (subscriberHandle != null) {
                subscriberHandle.hangup();
              }
              _localRenderer.srcObject = null;
              _localRenderer.dispose();
              _remoteRenderer.map((e) => e.srcObject = null);
              _remoteRenderer.map((e) => e.dispose());
              setState(() {
                pluginHandle = null;
                subscriberHandle = null;
              });
              Navigator.of(context).pop();
            }),
          IconButton(
            icon: Icon(
              Icons.switch_camera,
              color: Colors.white,
            ),
            onPressed: () {
              if (pluginHandle != null) {
                pluginHandle.switchCamera();
              }
            })
        ],
        title: const Text('janus_client'),
      ),
      body: Row(children: [
        Expanded(
            child: (_remoteRenderer != null &&
                _remoteRenderer.elementAt(0) != null)
                ? RTCVideoView(_remoteRenderer.elementAt(0))
                : Text(
              "Waiting...",
              style: TextStyle(color: Colors.black),
            )),
        Expanded(
            child: (_remoteRenderer != null &&
                _remoteRenderer.elementAt(1) != null)
                ? RTCVideoView(_remoteRenderer.elementAt(1))
                : Text(
              "Waiting...",
              style: TextStyle(color: Colors.black),
            )),
        Expanded(
            child: (_remoteRenderer != null &&
                _remoteRenderer.elementAt(2) != null)
                ? RTCVideoView(_remoteRenderer.elementAt(2))
                : Text(
              "Waiting...",
              style: TextStyle(color: Colors.black),
            )),
        Expanded(
            child: (_remoteRenderer != null &&
                _remoteRenderer.elementAt(3) != null)
                ? RTCVideoView(_remoteRenderer.elementAt(3))
                : Text(
              "Waiting...",
              style: TextStyle(color: Colors.black),
            )),
        Align(
          child: Container(
            child: RTCVideoView(
              _localRenderer,
            ),
            height: 200,
            width: 200,
          ),
          alignment: Alignment.bottomRight,
        )
      ]),
    );
  }
}
