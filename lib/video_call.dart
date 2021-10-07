import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'flutterjanus/flutterjanus.dart';

import 'package:http/http.dart' as http;
import "globals.dart" as globals;
import "callkeepdelegate.dart";
import "call.dart";

class JanusVideoCall extends StatefulWidget {
  JanusVideoCall({Key key, this.delegate, this.alreadyAnswered, this.callTo,
      this.numberTo, this.photoTo, this.callUUID}) : super(key: key);

  final CallKeepDelegate delegate;
  final bool alreadyAnswered;
  final String callTo;
  final String numberTo;
  final String photoTo;
  final String callUUID;

  @override
  _JanusVideoCallState createState() => _JanusVideoCallState();
}

class _JanusVideoCallState extends State<JanusVideoCall> {
  // String server = "wss://janutter.tzty.net:7007";
  // String server = "https://janutter.tzty.net:8008/janus";
  String server = "https://room.yourcompany.com:8089/janus";
  // List<String> server = ["wss://room.yourcompany.com:8188", "/janus"];

  String opaqueId = "videocall-" + Janus.randomString(12);
  var bitrateTimer;

  bool audioEnabled = false;
  bool videoEnabled = false;

  String myUsername;
  String yourUsername;
  //Map<String, dynamic> peers;
  List<dynamic> peers;

  String _userID;
  String _userName;
  String _cookie;
  String startUUID;

  bool doSimulcast = false;
  bool doSimulcast2 = false;
  bool simulcastStarted = false;

  Session session;
  Plugin videocall;
  CallPage _callPage;

  MediaStream _localStream;
  MediaStream _remoteStream;
  RTCVideoRenderer _localRenderer = new RTCVideoRenderer();
  RTCVideoRenderer _remoteRenderer = new RTCVideoRenderer();

  Timer _callTimer;

  //bool _inCalling = false;
  bool _registered = false;
  bool _registering = false;
  bool _initialized = false;
  bool _gotpeers = false;

  TextEditingController textController = TextEditingController();

  _JanusVideoCallState({Key key});

  @override
  void initState() {
    super.initState();
    Janus.init(options: {"debug": "all"}, callback: null);
    initRenderers();
  }

  initRenderers() async {
    _userID = await globals.storage.read(key: "userID");
    _userName = await globals.storage.read(key: "fullName");
    _cookie = await globals.storage.read(key: "token");
    textController.text = _userName;
    startUUID = widget.callUUID;
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
    _connect();
    _callTimer = Timer.periodic(
      Duration(seconds: 1),
      _onTimer,
    );
  }

  void _onTimer(Timer timer) {
    if (_initialized) {
      if (_registered) {
        if (widget.callTo != null) {
          if (_gotpeers) {
            String callto = Uri.encodeQueryComponent(widget.callTo);
            doCall(callto.replaceAll('+', '%20'));
            _callTimer.cancel();
          }
        } else {
          _callTimer.cancel();
        }
      } else if (!_registering) {
        _registering = true;
        registerUsername(_userID + '_' + _userName);
      }
    }
  }

  @override
  void deactivate() {
    super.deactivate();
    if (session != null) session.destroy();
    _localRenderer.dispose();
    _remoteRenderer.dispose();
  }

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

  answerCallDialog(jsep) {
    if (widget.alreadyAnswered == true) {
      answerCall(jsep);
    } else {
      String you = Uri.decodeQueryComponent(yourUsername);
      final id_name = you.split('_');
      final name = id_name[1];
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('ビデオコール'),
            content: Text(name + "さんからビデオコール呼び出しです"),
            actions: <Widget>[
              TextButton(
                child: Text("応答する"),
                onPressed: () {
                  answerCall(jsep);
                  Navigator.of(context).pop();
                },
              ),
              TextButton(
                child: Text("拒否する"),
                onPressed: () {
                  declineCall();
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        },
      );
    }
  }

  registerUsername(username) {
    if (videocall != null) {
      String callto = Uri.encodeQueryComponent(username);
      Callbacks callbacks = Callbacks();
      callbacks.message = {"request": "register", "username": callto.replaceAll('+', '%20')};
      videocall.send(callbacks);
    }
  }

  realDoCall(String username) {
    Callbacks callbacks = Callbacks();
    callbacks.media["data"] = false;
    callbacks.simulcast = doSimulcast;
    callbacks.simulcast2 = doSimulcast2;
    callbacks.success = (RTCSessionDescription jsep) {
      if (jsep != null) {
        Janus.debug("Got SDP!");
        Janus.debug(jsep.toString());
        Map<String, dynamic> body = {
          "request": "call",
          "username": username
        };
        Callbacks cbks = Callbacks();
        cbks.message = body;
        cbks.jsep = jsep.toMap();
        videocall.send(cbks);
        //setState(() {
        //  _inCalling = true;
        //});
        _callPage = CallPage(numberCall: widget.numberTo,
          nameCall: widget.callTo,
          photoCall: widget.photoTo,
          photoCookie: _cookie,);
        widget.delegate.startCall(
            widget.numberTo, widget.callTo, widget.photoTo, cookie: _cookie)
            .then((uuid) {
          startUUID = uuid;
          Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => _callPage)
          ).then((result) {
            if (result != "accept")
              Navigator.of(context).pop(result);
          });
        });
      }
    };
    callbacks.error = (error) {
      Janus.error("WebRTC error:", error);
      Janus.log("WebRTC error... " + jsonEncode(error));
    };
    Janus.debug("Trying a createOffer too (audio/video sendrecv)");
    videocall.createOffer(callbacks: callbacks);
  }

  doCall(String username) async {
    if (videocall != null) {
      if (peers.contains(username)) {
        realDoCall(username);
      } else {
        String sess = await globals.storage.read(key: "session");
        String session = Uri.encodeQueryComponent(sess);
        List<String> pair = widget.callTo.split('_');
        final uri = 'https://room.yourcompany.com/janusmobile/asktojoinroom.php?askto='+pair[0]+'&token='+session;
        http.Response response = await http.get(Uri.parse(uri));

        print(response.body);
        if (response.statusCode != 200) {
          await globals.showPopupDialog(context: context, title: "エラー", content: "サイトにアクセスできません", cancel: "閉じる");
          Navigator.of(context).pop("error");
          return false;
        }
        final bodyMap = json.decode(response.body);
        if (bodyMap['result'] != 0) {
          print(bodyMap['result_string']);
          await globals.showPopupDialog(context: context, title: "エラー", content: bodyMap['result_string'], cancel: "閉じる");
          Navigator.of(context).pop("error");
          return false;
        }
        _callPage = CallPage(numberCall: widget.numberTo, nameCall: widget.callTo,
            photoCall: widget.photoTo, photoCookie: _cookie,);
        startUUID = await widget.delegate.startCall(
            widget.numberTo, widget.callTo, widget.photoTo, cookie: _cookie);
        Timer.periodic(
          Duration(seconds: 1),
          (timer) {
            getRegisteredUsers();
            if (peers.contains(username)) {
              timer.cancel();
              _callPage.status = "register";
              realDoCall(username);
            }
          },
        );
        var result = await Navigator.push(
            context, MaterialPageRoute(builder: (context) => _callPage));
        if (result != "accept" && result != "register")
          Navigator.of(context).pop(result);
      }
    }
  }

  answerCall(jsep) {
    Janus.debug(jsep.toString());
    Callbacks callbacks = Callbacks();
    callbacks.jsep = jsep;
    callbacks.media["data"] = false;
    callbacks.simulcast = doSimulcast;
    callbacks.simulcast2 = doSimulcast2;
    callbacks.success = (RTCSessionDescription jsep) {
      Janus.debug("Got SDP!");
      if (jsep != null)
        Janus.debug(jsep.toMap());
      Callbacks cbks = Callbacks();
      cbks.message = {"request": "accept"};
      if (jsep != null)
        cbks.jsep = jsep.toMap();
      videocall.send(cbks);
      //setState(() {
      //  _inCalling = true;
      //});
    };
    callbacks.error = (error) {
      Janus.error("WebRTC error:", error);
      Janus.log("WebRTC error... " + jsonEncode(error));
    };
    videocall.createAnswer(callbacks);
  }

  declineCall() {
    Janus.log("Decline call pressed");
  }

  updateCall(jsep) {
    Callbacks callbacks = Callbacks();
    callbacks.jsep = jsep;
    if (jsep.type == 'answer') {
      videocall.handleRemoteJsep(callbacks);
    } else {
      callbacks.media["data"] = false;
      callbacks.simulcast = doSimulcast;
      callbacks.simulcast2 = doSimulcast2;
      callbacks.success = (RTCSessionDescription jsep) {
        Janus.debug("Got SDP!");
        Janus.debug(jsep.toMap());
        Callbacks cbks = Callbacks();
        cbks.message = {"request": "set"};
        cbks.jsep = jsep.toMap();
        videocall.send(cbks);
      };
      callbacks.error = (error) {
        Janus.error("WebRTC error:", error);
        Janus.log("WebRTC error... " + jsonEncode(error));
      };
      videocall.createAnswer(callbacks);
    }
  }

  getRegisteredUsers() {
    Callbacks callbacks = Callbacks();
    callbacks.message = {"request": "list"};
    videocall.send(callbacks);
  }

  _onMessage(msg, jsep) {
    Janus.debug(" ::: Got a message :::");
    Janus.debug(msg);
    Map<String, dynamic> result = msg["result"];
    if (result != null) {
      if (result["list"] != null) {
        peers = result["list"];
        Janus.debug("Got a list of registered peers:");
        Janus.debug(peers.toString());
        _gotpeers = true;
      } else if (result["event"] != null) {
        String event = result["event"];
        if (event == 'registered') {
          _registered = true;
          _registering = false;
          myUsername = result["username"];
          Janus.log("Successfully registered as " + myUsername + "!");
          //showAlert(
          //    "Registered", "Successfully registered as " + myUsername + "!");
          // Get a list of available peers, just for fun
          getRegisteredUsers();
          // TODO Enable buttons to call now
        } else if (event == 'calling') {
          Janus.log("Waiting for the peer to answer...");
          // TODO Any ringtone?
          //showAlert('Calling', "Waiting for the peer to answer...");
        } else if (event == 'incomingcall') {
          Janus.log("Incoming call from " + result["username"] + "!");
          yourUsername = result["username"];
          // Notify user
          answerCallDialog(jsep);
        } else if (event == 'accepted') {
          if (result["username"] == null) {
            Janus.log("Call started!");
          } else {
            yourUsername = result["username"];
            Janus.log(yourUsername + " accepted the call!");
          }
          if (_callPage != null)
            _callPage.status = "accept";
          // Video call can start
          if (jsep != null) {
            Callbacks callbacks = Callbacks();
            callbacks.jsep = jsep;
            videocall.handleRemoteJsep(callbacks);
          }
          widget.delegate.callKeep.reportConnectedOutgoingCallWithUUID(startUUID);
        } else if (event == 'update') {
          if (jsep != null) {
            updateCall(jsep);
          }
        } else if (event == 'hangup') {
          Janus.log("Call hung up by ${result["username"]} (${result["reason"]})!");
          if (_callPage != null)
            _callPage.status = "hangup";
          widget.delegate.callKeep.reportEndCallWithUUID(startUUID, 1);
          videocall.hangup(false);
          _hangUp();
        }
      }
    } else {
      var error = msg["error"];
      showAlert("Error", error.toString());
      _hangUp();
    }
  }

  @override
  Widget build(BuildContext context) {
    return new Scaffold(
      appBar: new AppBar(
        title: new Text('Videocall Test'),
        actions: <Widget>[],
      ),
      body: new OrientationBuilder(
        builder: (context, orientation) {
          return new Center(
            child: new Container(
              decoration: new BoxDecoration(color: Colors.white),
              child: new Stack(
                children: <Widget>[
                  new Align(
                    alignment: orientation == Orientation.portrait
                        ? const FractionalOffset(0.5, 0.1)
                        : const FractionalOffset(0.0, 0.5),
                    child: new Container(
                      margin: new EdgeInsets.fromLTRB(0.0, 0.0, 0.0, 0.0),
                      width: 320.0,
                      height: 240.0,
                      child: new RTCVideoView(_localRenderer),
                      decoration: new BoxDecoration(color: Colors.black54),
                    ),
                  ),
                  new Align(
                    alignment: orientation == Orientation.portrait
                        ? const FractionalOffset(0.5, 0.9)
                        : const FractionalOffset(1.0, 0.5),
                    child: new Container(
                      margin: new EdgeInsets.fromLTRB(0.0, 0.0, 0.0, 0.0),
                      width: 320.0,
                      height: 240.0,
                      child: new RTCVideoView(_remoteRenderer),
                      decoration: new BoxDecoration(color: Colors.black54),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: new FloatingActionButton(
        onPressed: () {
          _hangUp();
          widget.delegate.hangup(startUUID);
        },
            //_registered
            //  ? (_inCalling ? _hangUp : makeCallDialog)
            //  : registerDialog,
        tooltip: 'Hangup',  //_registered ? (_inCalling ? 'Hangup' : 'Call') : 'Register',
        child: new Icon(Icons.call_end),
            //_registered
            //  ? (_inCalling ? Icons.call_end : Icons.phone)
            //  : Icons.verified_user),
      ),
    );
  }

  void _connect() async {
    GatewayCallbacks gatewayCallbacks = GatewayCallbacks();
    gatewayCallbacks.server = this.server;
    gatewayCallbacks.success = _attach;
    gatewayCallbacks.error = (error) => Janus.log(error.toString());
    gatewayCallbacks.destroyed = () => deactivate();
    Session(gatewayCallbacks); // async httpd call
  }

  void _attach(int sessionId) {
    session = Janus.sessions[sessionId.toString()];

    Callbacks callbacks = Callbacks();
    callbacks.plugin = "janus.plugin.videocall";
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
    videocall = pluginHandle;
    Janus.log("Plugin attached! (" +
        this.videocall.getPlugin() +
        ", id=" +
        videocall.getId().toString() +
        ")");
    _initialized = true;
    //registerUsername(_userID + '_' + _userName);
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

  _webrtcState(bool on, [reason]) {
    Janus.log("Janus says our WebRTC PeerConnection is " +
        (on ? "up" : "down") +
        " now");
  }

  _slowLink(bool uplink, lost) {
    Janus.warn("Janus reports problems " +
        (uplink ? "sending" : "receiving") +
        " packets on this PeerConnection (" +
        ((lost is int)?lost.toString():lost) +
        " lost packets)");
  }

  _onLocalStream(MediaStream stream) {
    Janus.debug(" ::: Got a local stream :::");
    _localStream = stream;
    setState(() {
      _localRenderer.srcObject = _localStream;
    });
  }

  _onRemoteStream(MediaStream stream) {
    Janus.debug(" ::: Got a remote stream :::");
    _remoteStream = stream;
    setState(() {
      _remoteRenderer.srcObject = _remoteStream;
    });
  }

  _onDataOpen(data) {
    Janus.log("The DataChannel is available!");
  }

  _onData(data) {
    Janus.debug("We got data from the DataChannel! " + data);
  }

  _onCleanup() {
    Janus.log(" ::: Got a cleanup notification :::");
  }

  _hangUp() async {
    try {
      GatewayCallbacks gatewayCallbacks;
      session.destroy(gatewayCallbacks: gatewayCallbacks);
      setState(() {
        _localRenderer.srcObject = null;
        _remoteRenderer.srcObject = null;
      });
    } catch (e) {
      print(e.toString());
    }
    Janus.log('Hangup called');
    //setState(() {
    //  _inCalling = false;
    //  Navigator.of(context).pop();
    //});
    if (mounted)
      Navigator.of(context).pop();
  }

  _switchCamera() {
    Janus.log('Switching camera');
  }

  _muteMic() {
    Janus.log('Mute mic.');
  }
}
