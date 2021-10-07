import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'janus_client/Plugin.dart';
import 'janus_client/janus_client.dart';
import 'janus_client/utils.dart';

import "globals.dart" as globals;
import "call.dart";

class VideoCall extends StatefulWidget {
  VideoCall({this.publishVideo, this.sdpJsep, this.gotVideoCall, this.calleeName, this.receiveCall=false});
  final String calleeName;
  final bool receiveCall;
  final Plugin publishVideo;
  final dynamic sdpJsep;
  final Function(VideoCallState state) gotVideoCall;
  @override
  VideoCallState createState() => VideoCallState();
}

class VideoCallState extends State<VideoCall> {
  /*
  final JanusClient janusClient = JanusClient(iceServers: [
    RTCIceServer(
      url: "stun:40.85.216.95:3478",
      username: "onemandev",
      credential: "SecureIt"),
    RTCIceServer(
      url: "turn:40.85.216.95:3478",
      username: "onemandev",
      credential: "SecureIt")
  ], server: [
    //'wss://janus.conf.meetecho.com/ws',
    //'wss://janus.onemandev.tech/janus/websocket',
    'https://room.yourcompany.com:8089/janus',
  ], withCredentials: true, apiSecret: "SecureIt");
   */
  //TextEditingController nameController = TextEditingController();
  RTCVideoRenderer _localRenderer = new RTCVideoRenderer();
  RTCVideoRenderer _remoteRenderer = new RTCVideoRenderer();
  MediaStream myStream;

  @override
  void didChangeDependencies() async {
    // TODO: implement didChangeDependencies
    super.didChangeDependencies();
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    widget.gotVideoCall(this);
    registerUser();
  }

  void makeCall() async {
    await _localRenderer.initialize();
    MediaStream stream = await widget.publishVideo.initializeMediaDevices(
      mediaConstraints: {
        "audio": true,
        "video": {
          "mandatory": {
            "minFrameRate": '60',
          },
          "facingMode": "user",
          "optional": [],
        }
      }
    );
    setState(() {
      myStream = stream;
    });
    setState(() {
      _localRenderer.srcObject = myStream;
    });
    RTCSessionDescription offerToCall = await widget.publishVideo.createOffer();
    final String name = Uri.encodeQueryComponent(widget.calleeName);
    var body = {"request": "call", "username": name.replaceAll('+', '%20')};
    widget.publishVideo.send(
      message: body,
      jsep: offerToCall,
      onSuccess: () {
        print("Calling");
      },
      onError: (e) {
        print('got error in calling');
        print(e);
      });
    //nameController.text = "";
  }

  void receiveCall() async {
    await _localRenderer.initialize();
    MediaStream stream = await widget.publishVideo.initializeMediaDevices(
      mediaConstraints: {
        "audio": true,
        "video": {
          "mandatory": {
            "minFrameRate": '60',
          },
          "facingMode": "user",
          "optional": [],
        }
      }
    );
    setState(() {
      myStream = stream;
    });
    setState(() {
      _localRenderer.srcObject = myStream;
    });
    if (widget.sdpJsep != null) {
      widget.publishVideo.handleRemoteJsep(widget.sdpJsep);
    }
    // Notify user
    var offer = await widget.publishVideo.createAnswer();
    var body = {"request": "accept"};
    widget.publishVideo.send(
      message: body,
      jsep: offer,
      onSuccess: () {
        print('call connected');
      });
  }

  void setRemoteStream(dynamic stream) {
    setState(() {
      _remoteRenderer.srcObject = stream;
    });
  }

  registerUser() async {
    if (widget.publishVideo != null) {
      if (!widget.receiveCall) {
        makeCall();
      } else {
        receiveCall();
      }
    }
  }

  destroy() async {
    //await publishVideo.destroy();
    //janusClient.destroy();
    if (_remoteRenderer != null) {
      _remoteRenderer.srcObject = null;
      await _remoteRenderer.dispose();
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(children: [
        Column(
          children: [
            Expanded(
              child: RTCVideoView(
                _remoteRenderer,
                mirror: true,
                objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
              ),
            ),
            Expanded(
              child: Container(
              width: double.maxFinite,
              decoration: BoxDecoration(boxShadow: [BoxShadow(color: Colors.black45)]),
              child: RTCVideoView(
                _localRenderer,
                mirror: true,
                objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
              ),
            ))
          ],
        ),
        Align(
          alignment: Alignment.topRight,
          child: Padding(
            child: IconButton(
              icon: Icon(Icons.refresh),
              color: Colors.white,
              onPressed: () {
                widget.publishVideo.switchCamera();
              }),
            padding: EdgeInsets.all(25),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            child: CircleAvatar(
              backgroundColor: Colors.red,
              radius: 30,
              child: IconButton(
                icon: Icon(Icons.call_end),
                color: Colors.white,
                onPressed: () {
                  widget.publishVideo.send(
                    message: {'request': 'hangup'},
                    onSuccess: () async {
                      Navigator.of(context).pop();
                    },
                    onError: (error) async {
                      Navigator.of(context).pop();
                    }
                  );
                  widget.publishVideo.hangup();
                }
              )
            ),
            padding: EdgeInsets.all(10),
          ),
        )
      ]),
    );
  }

  @override
  void dispose() async {
    // TODO: implement dispose
    super.dispose();
  }
}
