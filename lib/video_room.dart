import 'dart:convert';
import 'dart:async';
//import 'dart:html';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'flutterjanus/flutterjanus.dart';
import 'package:crypto/crypto.dart';

class JanusVideoRoom extends StatefulWidget {
  JanusVideoRoom({Key key, this.myRoom, this.roomPass, this.userName}) : super(key: key);

  final String myRoom; // Demo room
  final String roomPass;
  final String userName;

  @override
  _JanusVideoRoomState createState() => _JanusVideoRoomState();
}

class _JanusVideoRoomState extends State<JanusVideoRoom> {
  // String server = "wss://janutter.tzty.net:7007";
  // String server = "https://janutter.tzty.net:8008/janus";
  String server = "https://room.yourcompany.com:8089/janus";
  //List<String> server = ["wss://room.yourcompany.com:8188", "/janus"];

  String opaqueId = "videoroom-" + Janus.randomString(12);

  bool audioEnabled = false;
  bool videoEnabled = false;

  String myUsername;
  int myId;
  MediaStream myStream;
  //MediaStreamTrack myStreamTrack;
  Map<int, MediaStream> theirStreams = {};
  //Map<int, MediaStreamTrack> theirStreamTracks = {};
  int myPvtId; // We use this other ID just to map our subscriptions to us
  List<Plugin> feeds = [];
  List<dynamic> list = [];
  Map<String, dynamic> bitrateTimer;

  Digest md5Digest;

  bool doSimulcast = false;
  bool doSimulcast2 = false;
  bool simulcastStarted = false;

  Session session;
  Plugin sfutest;

  RTCVideoRenderer localRenderer = new RTCVideoRenderer();
  Future<String> hasInitRenderers;
  List<RTCVideoRenderer> remoteRenderer = [];

  //bool _inCalling = false;
  //bool _registered = false;

  TextEditingController textController = TextEditingController();

  _JanusVideoRoomState({Key key});

  @override
  void initState() {
    super.initState();
    Janus.init(options: {"debug": "all"}, callback: null);
    if (widget.roomPass != null) {
      var md5key = utf8.encode(widget.roomPass);
      var md5bytes = utf8.encode(widget.myRoom);
      var hmacMd5 = new Hmac(md5, md5key);
      md5Digest = hmacMd5.convert(md5bytes);
    }
    hasInitRenderers = initRenderers();
  }

  Future<String> initRenderers() async {
    await localRenderer.initialize();
    for (int i = 0; i < 5; i++) {
      RTCVideoRenderer rend = new RTCVideoRenderer();
      remoteRenderer.add(rend);
      await rend.initialize();
    }
    _connect();
  }

  @override
  void deactivate() {
    super.deactivate();
    localRenderer.dispose();
    for (int i = 0; i < 5; i++) {
      remoteRenderer[i].dispose();
    }
    if (session != null) session.destroy();
  }

  registerUsername(username) {
    if (sfutest != null) {
      Callbacks callbacks = Callbacks();
      callbacks.success = (result) {
        bool exists = result["exists"];
        if (!exists) {
          Callbacks cbs = Callbacks();
          cbs.success = (value) {
            joinToRoom(username);
          };
          cbs.message = {
            "request": "create",
            "room": int.parse(widget.myRoom),
            if(widget.roomPass!=null) "secret": widget.roomPass,
            if(widget.roomPass!=null) "pin": md5Digest.toString(), // xmur3(widget.roomPass)(),
            "permanent": false,
            "is_private_id": true,
            //"record": $('#record_meeting').val==='true',
            "rec_dir": '/home/janus/share/video',
            "publishers": 200
          };
          sfutest.send(cbs);
        } else {
          joinToRoom(username);
        }
      };
      callbacks.message = {
        "request" : "exists",
        if(widget.roomPass!=null) "pin": md5Digest.toString(), // xmur3(widget.roomPass)(),
        "room" : int.parse(widget.myRoom),
      };
      sfutest.send(callbacks);
    }
  }

  joinToRoom(String username) {
    Callbacks cbs = Callbacks();
    cbs.success = (result) {
      //_registered = true;
    };
    cbs.message = {
      "request": "join",
      "room" : int.parse(widget.myRoom),
      if(widget.roomPass!=null) "pin": md5Digest.toString(), // xmur3(widget.roomPass)(),
      "ptype": "publisher",
      "display": username
    };
    myUsername = username;
    sfutest.send(cbs);
  }

  publishOwnFeed({bool useAudio = true}) {
    if (sfutest != null) {
      Callbacks callbacks = Callbacks();
      callbacks.media = {
        "audioRecv": false,
        "videoRecv": false,
        "audioSend": useAudio,
        "videoSend": true
      };
      callbacks.simulcast = doSimulcast;
      callbacks.simulcast2 = doSimulcast2;
      callbacks.success = (RTCSessionDescription jsep) {
        Janus.debug("Got publisher SDP!");
        if (jsep != null)
          Janus.debug(jsep.toMap());
        Map<String, dynamic> publish = {
          "request": "configure",
          if(widget.roomPass!=null) "secret": widget.roomPass,
          if(widget.roomPass!=null) "pin": md5Digest.toString(), // xmur3(widget.roomPass)(),
          "audio": useAudio,
          "video": true
        };
        // You can force a specific codec to use when publishing by using the
        // audiocodec and videocodec properties, for instance:
        // 		publish["audiocodec"] = "opus"
        // to force Opus as the audio codec to use, or:
        // 		publish["videocodec"] = "vp9"
        Callbacks cbs = Callbacks();
        cbs.message = publish;
        if (jsep != null)
          cbs.jsep = jsep.toMap();
        sfutest.send(cbs);
        //setState(() {
        //  _inCalling = true;
        //});
      };
      callbacks.error = (error) {
        Janus.error("WebRTC error:", error);
        Janus.log("WebRTC error... " + jsonEncode(error));
      };
      Janus.debug("Trying a createOffer too (audio/video sendrecv)");
      sfutest.createOffer(callbacks: callbacks);
    }
  }

  unpublishOwnFeed() {
    if (sfutest != null) {
      Callbacks callbacks = Callbacks();
      callbacks.message = {
        "request": "unpublish",
        if(widget.roomPass!=null) "pin": md5Digest.toString(), // xmur3(widget.roomPass)(),
      };
      sfutest.send(callbacks);
    }
  }

  newRemoteFeed(id, display, audio, video) {
    // A new feed has been published, create a new plugin handle and attach to it as a subscriber
    Plugin remoteFeed;
    Callbacks callbacks = Callbacks();
    callbacks.plugin = "janus.plugin.videoroom";
    callbacks.opaqueId = opaqueId;
    callbacks.success = (Plugin pluginHandle) {
      if (pluginHandle == null)
        return;
      remoteFeed = pluginHandle;
      Janus.log("Plugin attached! (" +
          remoteFeed.getPlugin().toString() +
          ", id=" +
          remoteFeed.getId().toString() +
          ")");
      Janus.log("  -- This is a subscriber");
      Map<String, dynamic> subscribe = {
        "request": "join",
        "room": int.parse(widget.myRoom),
        if(widget.roomPass!=null) "pin": md5Digest.toString(), // xmur3(widget.roomPass)(),
        "ptype": "subscriber",
        "feed": id,
        "private_id": myPvtId
      };
      // You can force a specific codec to use when publishing by using the
      // audiocodec and videocodec properties, for instance:
      // 		publish["audiocodec"] = "opus"
      // to force Opus as the audio codec to use, or:
      // 		publish["videocodec"] = "vp9"
      callbacks.message = subscribe;
      remoteFeed.send(callbacks);
    };
    callbacks.error = _error;
    callbacks.consentDialog = _consentDialog;
    callbacks.iceState = _iceState;
    callbacks.mediaState = _mediaState;
    callbacks.webrtcState = _webrtcState;
    callbacks.slowLink = _slowLink;
    callbacks.onMessage = (Map<String, dynamic> msg, jsep) {
      Janus.debug(" ::: Got a message (subscriber) :::");
      Janus.debug(msg);
      String event = msg["videoroom"];
      Janus.debug("Event: " + event.toString());
      if (msg["error"] != null) {
        Janus.error(msg["error"]);
      } else if (event != null) {
        if (event == "attached") {
          // Subscriber created and attached
          if (feeds.length < 5) {
            feeds.add(remoteFeed);
            remoteFeed.remoteFeedIndex = feeds.length - 1;
          }
          remoteFeed.remoteFeedId = msg["id"];
          remoteFeed.remoteFeedDisplay = msg["display"];
          Janus.log("Successfully attached to feed " +
              remoteFeed.remoteFeedId.toString() +
              " (" +
              remoteFeed.remoteFeedDisplay +
              ") in room " +
              msg["room"].toString());
        } else if (event == "event") {
          // Check if we got an event on a simulcast-related event from this publisher
          var substream = msg["substream"];
          var temporal = msg["temporal"];
          if (substream != null || temporal != null) {
            Janus.log("Feed supports simulcast");
          }
        }
      }
      if (jsep != null) {
        Janus.debug("Handling SDP as well...");
        Janus.debug(jsep);
        Callbacks callbacks = Callbacks();
        callbacks.jsep = jsep;
        callbacks.media = {"audioSend": false, "videoSend": false};
        callbacks.success = (RTCSessionDescription jsep) {
          Janus.debug("Got SDP!");
          if (jsep == null) {
            Janus.debug("jsep is null");
          } else {
            Janus.debug(jsep.toMap());
          }
          Callbacks cbs = Callbacks();
          cbs.message = {
            "request": "start",
            "room": int.parse(widget.myRoom),
            if(widget.roomPass!=null) "pin": md5Digest.toString(), // xmur3(widget.roomPass)(),
          };
          if (jsep != null)
            cbs.jsep = jsep.toMap();
          remoteFeed.send(cbs);
        };
        callbacks.error = (error) {
          Janus.error("WebRTC error:", error);
          Janus.log("WebRTC error... " + jsonEncode(error));
        };
        remoteFeed.createAnswer(callbacks);
      }
    };
    callbacks.onLocalStream = () {
      // The subscriber stream is recvonly, we don't expect anything here
      Janus.log("The subscriber stream is receive only.");
    };
    callbacks.onRemoteStream = (MediaStream stream) {
      Janus.debug("Remote feed #" + remoteFeed.remoteFeedId.toString());
      Janus.debug("Remote index #" + remoteFeed.remoteFeedIndex.toString());
      theirStreams[remoteFeed.remoteFeedIndex] = stream;
      setState(() {
        remoteRenderer[remoteFeed.remoteFeedIndex].srcObject = stream;
      });
      /*
      Timer.periodic(Duration(seconds: 1), (Timer timer) {
        List<MediaStreamTrack> tracks = remoteRenderer[remoteFeed.remoteFeedIndex].srcObject.getVideoTracks();
        if (tracks.length > 0) {
          var track = tracks[0];
          if (track.enabled) {
            timer.cancel();
          }
        }
        setState(() {
          remoteRenderer[remoteFeed.remoteFeedIndex].srcObject = stream;
        });
      });
       */
    };
    callbacks.webrtcState = (bool on, [List<dynamic> extra]) {
      //sometimes we get extra here? an error?
      Janus.log("Janus says our WebRTC PeerConnection is " +
          (on ? "up" : "down") + " now");
      Janus.debug('WebRTC state message, had extra: ${extra.toString()}');
      if (on && theirStreams[remoteFeed.remoteFeedIndex] != null) {
        setState(() {
          remoteRenderer[remoteFeed.remoteFeedIndex].srcObject = theirStreams[remoteFeed.remoteFeedIndex];
        });
      }
    };
    callbacks.onDataOpen = _onDataOpen;
    callbacks.onData = _onData;
    callbacks.onCleanup = () {
      Janus.log(" ::: Got a cleanup notification (remote feed " +
          remoteFeed.remoteFeedId.toString() +
          ") :::");
      setState(() {
        remoteRenderer[remoteFeed.remoteFeedIndex].srcObject = null;
      });
    };
    this.session.attach(callbacks: callbacks);
  }

  updateCall(jsep) {
    Callbacks callbacks = Callbacks();
    callbacks.jsep = jsep;
    if (jsep.type == 'answer') {
      sfutest.handleRemoteJsep(callbacks);
    } else {
      callbacks.media["data"] = false;
      callbacks.simulcast = doSimulcast;
      callbacks.simulcast2 = doSimulcast2;
      callbacks.success = (RTCSessionDescription jsep) {
        Janus.debug("Got SDP!");
        Janus.debug(jsep.toMap());
        callbacks.message = {
          "request": "set",
          if(widget.roomPass!=null) "pin": md5Digest.toString(), // xmur3(widget.roomPass)(),
        };
        callbacks.jsep = jsep.toMap();
        sfutest.send(callbacks);
      };
      callbacks.error = (error) {
        Janus.error("WebRTC error:", error);
        Janus.log("WebRTC error... " + jsonEncode(error));
      };
      sfutest.createAnswer(callbacks);
    }
  }

  getRegisteredUsers() {
    Callbacks callbacks = Callbacks();
    callbacks.message = {
      "request": "list",
      if(widget.roomPass!=null) "pin": md5Digest.toString(), // xmur3(widget.roomPass)(),
    };
    sfutest.send(callbacks);
  }

  void _connect() async {
    GatewayCallbacks gatewayCallbacks = GatewayCallbacks();
    gatewayCallbacks.server = this.server;
    gatewayCallbacks.success = _attach;
    gatewayCallbacks.error = (error) => Janus.error(error.toString());
    gatewayCallbacks.destroyed = () => deactivate();
    Session(gatewayCallbacks); // async httpd call
  }

  void _attach(int sessionId) {
    session = Janus.sessions[sessionId.toString()];

    Callbacks callbacks = Callbacks();
    callbacks.plugin = "janus.plugin.videoroom";
    callbacks.opaqueId = opaqueId;
    callbacks.success = _success;
    callbacks.error = _error;
    callbacks.consentDialog = _consentDialog;
    callbacks.iceState = _iceState;
    callbacks.mediaState = _mediaState;
    callbacks.webrtcState = _webrtcState;
    callbacks.slowLink = _slowLink;
    callbacks.onMessage = _onMessage;
    callbacks.onLocalStream = _onLocalStream;
    callbacks.onRemoteStream = _onRemoteStream;
    callbacks.onDataOpen = _onDataOpen;
    callbacks.onData = _onData;
    callbacks.onCleanup = _onCleanup;
    this.session.attach(callbacks: callbacks);
  }

  _success(Plugin pluginHandle) {
    sfutest = pluginHandle;
    Janus.log("Plugin attached! (" +
        this.sfutest.getPlugin() +
        ", id=" +
        sfutest.getId().toString() +
        ")");
    Janus.log("  -- This is a publisher/manager");
    // Prepare the username registration
    // registerDialog();
    registerUsername(widget.userName);
  }

  _error(error) {
    Janus.log("  -- Error attaching plugin...", error.toString());
  }

  _consentDialog(bool on) {
    Janus.debug("Consent dialog should be " + (on ? "on" : "off") + " now");
  }

  _iceState(RTCIceConnectionState state) {
    Janus.log("ICE state changed to " + state.toString());
  }

  _mediaState(String medium, bool on) {
    Janus.log(
        "Janus " + (on ? "started" : "stopped") + " receiving our " + medium);
  }

  _webrtcState(bool on, [List<dynamic> extra]) {
    //sometimes we get extra here? an error?
    Janus.log("Janus says our WebRTC PeerConnection is " +
        (on ? "up" : "down") + " now");
    Janus.debug('WebRTC state message, had extra: ${extra.toString()}');
    if (on && myStream != null) {
      //List<MediaStreamTrack> tracks = myStream.getVideoTracks();
      //if (tracks == null || tracks.length == 0) {
      setState(() {
        localRenderer.srcObject = myStream;
      });
      //}
    }
  }

  // onMessage is main application flow control
  _onMessage(Map<String, dynamic> msg, jsep) {
    Janus.debug(" ::: Got a message (publisher) :::");
    Janus.debug(msg);
    String event = msg["videoroom"];
    Janus.debug("Event: " + event.toString());

    if (event != null) {
      if (event == "joined") {
        // Publisher/manager created, negotiate WebRTC and attach to existing feeds, if any
        myId = msg["id"];
        myPvtId = msg["private_id"];
        Janus.log("Successfully joined room " +
            msg["room"].toString() +
            " with ID " +
            myId.toString());
        publishOwnFeed(useAudio: true);
        // Any new feed to attach to?
        if (msg["publishers"] != null) {
          list = msg["publishers"];
          Janus.debug("Got a list of available publishers/feeds:");
          Janus.debug(list.toString());
          list.forEach((value) {
            var id = value["id"];
            var display = value["display"];
            var audio = value["audio_codec"];
            var video = value["video_coded"];
            Janus.debug("  >> [" +
                id.toString() +
                "] " +
                display.toString() +
                " (audio: " +
                audio.toString() +
                ", video: " +
                video.toString() +
                ")");
            newRemoteFeed(id, display, audio, video);
          });
        }
      } else if (event == 'destroyed') {
        // The room has been destroyed
        Janus.warn("The room has been destroyed!");
      } else if (event == "event") {
        // Any new feed to attach to?
        if (msg["publishers"] != null) {
          list = msg["publishers"];
          Janus.debug("Got a list of available publishers/feeds:");
          Janus.debug(list.toString());
          list.forEach((value) {
            var id = value["id"];
            var display = value["display"];
            var audio = value["audio_codec"];
            var video = value["video_coded"];
            Janus.debug("  >> [" +
                id.toString() +
                "] " +
                display.toString() +
                " (audio: " +
                audio.toString() +
                ", video: " +
                video.toString() +
                ")");
            newRemoteFeed(id, display, audio, video);
          });
        } else if (msg["leaving"] != null) {
          var leaving = msg["leaving"];
          Janus.log("Publisher left: " + leaving.toString());
          Plugin remoteFeed;

          feeds.forEach((element) {
            if (element.getId() == leaving) {
              remoteFeed = element;
            }
          });
          if (remoteFeed != null) {
            Janus.debug("Feed " +
                remoteFeed.remoteFeedId.toString() +
                " (" +
                remoteFeed.remoteFeedDisplay +
                ") has left the room, detaching");
            feeds.remove(remoteFeed);
            remoteFeed.getPlugin().detach({});
          }
        } else if (msg["unpublished"] != null) {
          var unpublished = msg["unpublished"];
          Janus.log("Publisher left: " + unpublished.toString());
          if (unpublished == 'ok') {
            // That's us
            sfutest.hangup(false);
            return;
          }
          Plugin remoteFeed;
          feeds.forEach((element) {
            if (element.getId() == unpublished) {
              remoteFeed = element;
            }
          });
          if (remoteFeed != null) {
            Janus.debug("Feed " +
                remoteFeed.remoteFeedId.toString() +
                " (" +
                remoteFeed.remoteFeedDisplay +
                ") has left the room, detaching");
            feeds.remove(remoteFeed);
            remoteFeed.getPlugin().detach({});
          }
        } else if (msg["error"] != null) {
          if (msg["error_code"] == 426) {
            // This is a "no such room" error: give a more meaningful description
            Janus.error("No such room exists");
          } else {
            Janus.error("Unknown Error: " + msg["error"].toString());
          }
        }
      }
    }

    if (jsep != null) {
      Janus.debug("Handling SDP as well...");
      Janus.debug(jsep);
      Callbacks callbacks = Callbacks();
      callbacks.jsep = jsep;
      sfutest.handleRemoteJsep(callbacks);
      var audio = msg["audio_codec"];
      if (myStream != null &&
          myStream.getAudioTracks().length > 0 &&
          audio == null) {
        Janus.log("Our audio stream has been rejected, viewers won't hear us");
      }
      var video = msg["audio_codec"];
      if (myStream != null &&
          myStream.getVideoTracks().length > 0 &&
          video == null) {
        Janus.log("Our video stream has been rejected, viewers won't see us");
      }
    }
  }

  _slowLink(bool uplink, lost) {
    Janus.warn("Janus reports problems " +
        (uplink ? "sending" : "receiving") +
        " packets on this PeerConnection (" +
        (lost is String ? lost:lost.toString()) +
        " lost packets)");
  }

  _onLocalStream(MediaStream stream) {
    Janus.debug(" ::: Got a local stream :::");
    myStream = stream;
    setState(() {
      localRenderer.srcObject = myStream;
      localRenderer.muted = false;
    });
  }

  _onRemoteStream(MediaStream stream) {
    // The publisher stream is sendonly, we don't expect anything here
    Janus.debug(" ::: Got a remote stream :::");
  }

  _onDataOpen(data) {
    Janus.log("The DataChannel is available!");
  }

  _onData(data) {
    Janus.debug("We got data from the DataChannel! " + data);
  }

  _onCleanup() {
    Janus.log(" ::: Got a cleanup notification :::");
    myStream = null;
    setState(() {
      localRenderer.srcObject = null;
    });
  }

  _hangUp() async {
    try {
      GatewayCallbacks gatewayCallbacks;
      session.destroy(gatewayCallbacks: gatewayCallbacks);
      setState(() {
        localRenderer.srcObject = null;
        for (int i = 0; i < 5; i++) {
          remoteRenderer[i].srcObject = null;
        }
      });
    } catch (e) {
      print(e.toString());
    }
    Janus.log('Hangup called');
    //setState(() {
    //  _inCalling = false;
    //  Navigator.of(context).pop();
    //});
    Navigator.of(context).pop();
  }

  _switchCamera() {
    Janus.log('Switching camera');
  }

  _muteMic() {
    Janus.log('Mute mic.');
  }

  /*
  Function xmur3(String str) {
    int i;
    int h = 1779033703 ^ str.length;
    for(i = 0; i < str.length; i++) {
      h = h ^ str.codeUnits[i] * 3432918353;
      int j = h << 13;
      h = (j == 0 ? (h & 0xFFFFFFFF) >> 19 : j);
    }
    return () {
      h = (h ^ (h & 0xFFFFFFFF) >>  16) * 2246822507;
      h = (h ^ (h & 0xFFFFFFFF) >> 13) * 3266489909;
      return (((h ^= (h & 0xFFFFFFFF) >> 16) & 0xFFFFFFFF) >> 0).toString();
    };
  }
   */

  @override
  Widget build(BuildContext context) {
    return new Scaffold(
      appBar: new AppBar(
        title: new Text('Videoroom Test'),
        actions: <Widget>[],
      ),
      body: new FutureBuilder(
          future: hasInitRenderers,
          builder: (BuildContext context, AsyncSnapshot<String> snapshot) {
            switch (snapshot.connectionState) {
              case ConnectionState.none:
              case ConnectionState.waiting:
                return new Text('loading...');
              default:
                if (snapshot.hasError)
                  return new Text('Error: ${snapshot.error}');
                else
                  return new OrientationBuilder(
                    builder: (context, orientation) {
                      return Container(
                        decoration: BoxDecoration(color: Colors.white),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Column(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                Container(
                                  decoration:
                                      new BoxDecoration(color: Colors.black54),
                                  child: new RTCVideoView(localRenderer, mirror: true),
                                  width:
                                      MediaQuery.of(context).size.width / 2.1,
                                  height:
                                      MediaQuery.of(context).size.height / 4.1,
                                ),
                                Container(
                                  decoration:
                                      new BoxDecoration(color: Colors.black54),
                                  child: new RTCVideoView(remoteRenderer[0]),
                                  width:
                                      MediaQuery.of(context).size.width / 2.1,
                                  height:
                                      MediaQuery.of(context).size.height / 4.1,
                                ),
                                Container(
                                  decoration:
                                      new BoxDecoration(color: Colors.black54),
                                  child: new RTCVideoView(remoteRenderer[1]),
                                  width:
                                      MediaQuery.of(context).size.width / 2.1,
                                  height:
                                      MediaQuery.of(context).size.height / 4.1,
                                ),
                              ],
                            ),
                            Column(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                Container(
                                  decoration:
                                      new BoxDecoration(color: Colors.black54),
                                  child: new RTCVideoView(remoteRenderer[2]),
                                  width:
                                      MediaQuery.of(context).size.width / 2.1,
                                  height:
                                      MediaQuery.of(context).size.height / 4.1,
                                ),
                                Container(
                                  decoration:
                                      new BoxDecoration(color: Colors.black54),
                                  child: new RTCVideoView(remoteRenderer[3]),
                                  width:
                                      MediaQuery.of(context).size.width / 2.1,
                                  height:
                                      MediaQuery.of(context).size.height / 4.1,
                                ),
                                Container(
                                  decoration:
                                      new BoxDecoration(color: Colors.black54),
                                  child: new RTCVideoView(remoteRenderer[4]),
                                  width:
                                      MediaQuery.of(context).size.width / 2.1,
                                  height:
                                      MediaQuery.of(context).size.height / 4.1,
                                ),
                              ],
                            )
                          ],
                        ),
                      );
                    },
                  );
            }
          }),
      floatingActionButton: new FloatingActionButton(
        onPressed: /*_registered ? */_hangUp/* : registerDialog*/,
        tooltip: /*_registered ? */'Hangup'/* : 'Register'*/,
        child: new Icon(/*_registered ? */Icons.call_end/* : Icons.phone*/),
      ),
    );
  }

  /*
  registerDialog() {
    showDialog(
        context: context,
        builder: (BuildContext context) {
          return Dialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20.0)), //this right here
            child: Container(
              height: 200,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      decoration: InputDecoration(
                          border: InputBorder.none,
                          hintText: 'Register as username ...'),
                      controller: textController,
                    ),
                    SizedBox(
                      width: 320.0,
                      child: RaisedButton(
                        onPressed: () {
                          registerUsername(textController.text);
                          Navigator.of(context).pop();
                        },
                        child: Text(
                          "Register",
                          style: TextStyle(color: Colors.white),
                        ),
                        color: Colors.green,
                      ),
                    )
                  ],
                ),
              ),
            ),
          );
        });
  }
   */

  showAlert(String title, String text) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        // return object of type Dialog
        return AlertDialog(
          title: new Text(title),
          content: new Text(text),
          actions: <Widget>[
            // usually buttons at the bottom of the dialog
            new TextButton(
              child: new Text("Close"),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
}
