import 'dart:async';
import 'dart:convert' show json;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'package:callkeep/callkeep.dart';

import 'globals.dart' as globals;
import 'video_call.dart';
import 'call.dart';

class Call {
  Call(this.number, this.name, {this.photo, this.cookie});
  String number;
  String name;
  String photo;
  String cookie;
  bool held = false;
  bool muted = false;
}

class CallKeepDelegate {
  static final CallKeepDelegate _instance = CallKeepDelegate._internal();
  final FlutterCallkeep _callKeep = FlutterCallkeep();
  BuildContext _context;
  Map<String, Call> calls = {};
  bool _callKeepInited = false;

  String newUUID() => Uuid().v4();

  factory CallKeepDelegate() {
    return _instance;
  }

  CallKeepDelegate._internal() {
    if (!_callKeepInited) {
      _callKeep.setup(_context, <String, dynamic>{
        'ios': {
          'appName': 'janusmobile3',
        },
        'android': {
          'alertTitle': 'アクセス権限が必要です',
          'alertDescription': 'この電話のアカウントにアクセスする必要があります',
          'cancelButton': 'キャンセル',
          'okButton': 'OK',
        },
      });
      _callKeepInited = true;
    }
    _callKeep.on(CallKeepDidDisplayIncomingCall(), didDisplayIncomingCall);
    _callKeep.on(CallKeepPerformAnswerCallAction(), answerCall);
    _callKeep.on(CallKeepDidPerformDTMFAction(), didPerformDTMFAction);
    _callKeep.on(
        CallKeepDidReceiveStartCallAction(), didReceiveStartCallAction);
    _callKeep.on(CallKeepDidToggleHoldAction(), didToggleHoldCallAction);
    _callKeep.on(
        CallKeepDidPerformSetMutedCallAction(), didPerformSetMutedCallAction);
    _callKeep.on(CallKeepPerformEndCallAction(), endCall);
    _callKeep.on(CallKeepPushKitToken(), onPushKitToken);
    _callKeep.on(CallKeepDidActivateAudioSession(), didActivateAudioSession);
    _callKeep.on(CallKeepDidDeactivateAudioSession(), didDeactivateAudioSession);
    _callKeep.on(CallKeepProviderReset(), onProviderReset);
    _callKeep.on(CallKeepCheckReachability(), onCheckReachability);
    _callKeep.on(CallKeepDidLoadWithEvents(), didLoadWithEvents);
  }

  void set context(context) => _context = context;
  FlutterCallkeep get callKeep => _callKeep;

  void didDisplayIncomingCall(CallKeepDidDisplayIncomingCall event) {
    final callUUID = event.callUUID;
    if (Platform.isAndroid) {
      var call = calls[callUUID];
      var callPage = CallPage(numberCall: call.number,
        nameCall: call.name,
        photoCall: call.photo,
        photoCookie: call.cookie,
        isIncomming: true,);
      Navigator.push(
        _context,
        MaterialPageRoute(builder: (context) => callPage)).then((result) {
          if (result != "answer") {
            Navigator.of(_context).pop(result);
            return;
          }
          answerToCall(callUUID);
        });
    } else {
      final number = event.handle;
      print('[displayIncomingCall] $callUUID number: $number');
      calls[callUUID] = Call(number, event.localizedCallerName);
    }
  }

  Future<void> answerCall(CallKeepPerformAnswerCallAction event) async {
    /*
    final String callUUID = event.callUUID;
    final String number = calls[callUUID].number;
    print('[answerCall] $callUUID, number: $number');

    _callKeep.startCall(event.callUUID, number, number);
    Timer(const Duration(seconds: 1), () {
      print('[setCurrentCallActive] $callUUID, number: $number');
      _callKeep.setCurrentCallActive(callUUID);
    });
     */
    final callUUID = event.callUUID ?? Uuid().v4();
    answerToCall(callUUID);
    /*
    final String number = calls[callUUID].number;
    print('[answerCall] $callUUID, number: $number');

    String sess = await globals.storage.read(key: "session");
    String session = Uri.encodeQueryComponent(sess);
    final uri = "https://room.yourcompany.com/janusmobile/answerpush.php?tag="+callUUID+"&session="+session;
    http.Response response = await http.get(Uri.parse(uri));
    if (response.statusCode != 200) {
      await globals.showPopupDialog(context: _context, title: "エラー", content: "サイトにアクセスできません", cancel: "閉じる");
      return;
    }
    print(response.body.toString());
    _callKeep.setCurrentCallActive(callUUID);

    Navigator.push(
        _context,
        MaterialPageRoute(builder: (context) =>
            JanusVideoCall(delegate: this, alreadyAnswered: true, numberTo: number,
              photoTo: calls[callUUID].photo, callUUID: callUUID,) ));
     */
  }

  void didPerformDTMFAction(CallKeepDidPerformDTMFAction event) {
    print('[didPerformDTMFAction] ${event.callUUID}, digits: ${event.digits}');
  }

  void didReceiveStartCallAction(CallKeepDidReceiveStartCallAction event) {
    if (event.handle == null) {
      // @TODO: sometime we receive `didReceiveStartCallAction` with handle` undefined`
      return;
    }
    final String callUUID = event.callUUID ?? newUUID();
    if (calls[callUUID] == null) {
      calls[callUUID] = Call(event.handle, event.handle);
      print('[didReceiveStartCallAction] $callUUID, number: ${event.handle}');
    }
    updateDisplay(callUUID);
    //_callKeep.startCall(callUUID, event.handle, event.name, handleType: 'number', hasVideo: true);

    print('[setCurrentCallActive] $callUUID, number: ${event.handle}');
    _callKeep.setCurrentCallActive(callUUID);
    _callKeep.reportConnectingOutgoingCallWithUUID(callUUID);
  }

  void didToggleHoldCallAction(CallKeepDidToggleHoldAction event) {
    final String number = calls[event.callUUID].number;
    print(
        '[didToggleHoldCallAction] ${event.callUUID}, number: $number (${event.hold})');

    setCallHeld(event.callUUID, event.hold);
  }

  void didPerformSetMutedCallAction(
      CallKeepDidPerformSetMutedCallAction event) {
    final String number = calls[event.callUUID].number;
    print(
        '[didPerformSetMutedCallAction] ${event.callUUID}, number: $number (${event.muted})');

    setCallMuted(event.callUUID, event.muted);
  }

  Future<void> endCall(CallKeepPerformEndCallAction event) async {
    print('endCall: ${event.callUUID}');
    _callKeep.endCall(event.callUUID);
    removeCall(event.callUUID);
  }

  void onPushKitToken(CallKeepPushKitToken event) {
    print('[onPushKitToken] token => ${event.token}');
    writeIosToken(event.token);
  }

  void didActivateAudioSession(CallKeepDidActivateAudioSession event) {
    print('[didActivateAudioSession] called');
  }

  void didDeactivateAudioSession(CallKeepDidDeactivateAudioSession event) {
    print('[didDeactivateAudioSession] called');
  }

  void onProviderReset(CallKeepProviderReset event) {
    print('[onProviderReset] called');
  }

  void onCheckReachability(CallKeepCheckReachability event) {
    print('[onCheckReachability] called');
  }

  void didLoadWithEvents(CallKeepDidLoadWithEvents event) {
    print('[didLoadWithEvents] called');
  }

  Future<void> answerToCall(String callUUID) async {
    final String number = calls[callUUID].number;
    print('[answerCall] $callUUID, number: $number');

    String sess = await globals.storage.read(key: "session");
    String session = Uri.encodeQueryComponent(sess);
    final uri = "https://room.yourcompany.com/janusmobile/answerpush.php?tag="+callUUID+"&session="+session;
    http.Response response = await http.get(Uri.parse(uri));
    if (response.statusCode != 200) {
      await globals.showPopupDialog(context: _context, title: "エラー", content: "サイトにアクセスできません", cancel: "閉じる");
      return;
    }
    print(response.body.toString());
    _callKeep.setCurrentCallActive(callUUID);

    Navigator.push(
        _context,
        MaterialPageRoute(builder: (context) =>
            JanusVideoCall(delegate: this, alreadyAnswered: true, numberTo: number,
              photoTo: calls[callUUID].photo, callUUID: callUUID,) ));
  }

  Future<void> updateDisplay(String callUUID) async {
    final String number = calls[callUUID].number;
    final String name = calls[callUUID].name;
    // Workaround because Android doesn't display well displayName, so we have to switch ...
    if (isIOS) {
      _callKeep.updateDisplay(callUUID,
          displayName: name, handle: number);
    } else {
      _callKeep.updateDisplay(callUUID,
          displayName: name, handle: number);
    }

    print('[updateDisplay: $number] $callUUID');
  }

  void setCallHeld(String callUUID, bool held) {
    calls[callUUID].held = held;
  }

  void setCallMuted(String callUUID, bool muted) {
    calls[callUUID].muted = muted;
  }

  writeIosToken(voipToken) async {
    String userID = await globals.storage.read(key: "userID");
    String sess = await globals.storage.read(key: "session");
    if (sess != null) {
      String session = Uri.encodeQueryComponent(sess);
      var isRelease = const bool.fromEnvironment('dart.vm.product');
      var map = new Map<String, dynamic>();
      map['user'] = userID;
      map['token'] = session;
      map['voip'] = voipToken;
      map['debug'] = isRelease?"0":"1";
      final uri = "https://room.yourcompany.com/janusmobile/write_voip_token.php";
      http.Response response = await http.post(Uri.parse(uri), body: map);
      if (response.statusCode != 200) {
        await globals.showPopupDialog(context: _context, title: "エラー", content: "サイトにアクセスできません", cancel: "閉じる");
        return;
      }
      final meetings = json.decode(response.body);
      if (meetings['result'] != 0) {
        print(meetings['result_string']);
        await globals.showPopupDialog(context: _context, title: "エラー", content: meetings['result_string'], cancel: "閉じる");
        return;
      }
      await globals.storage.write(key: "voipToken", value: voipToken);
    }
  }

  Future<String> startCall(String number, String contactName, String photo,
      {String cookie = '', String handleType = 'number', bool hasVideo = true}) async {
    final String callUUID = newUUID();
    calls[callUUID] = Call(number, contactName, photo: photo, cookie: cookie);
    _callKeep.startCall(callUUID, number, contactName, handleType: handleType, hasVideo: hasVideo);
    return callUUID;
  }

  Future<void> hangup(String callUUID) async {
    _callKeep.endCall(callUUID);
    removeCall(callUUID);
  }

  void removeCall(String callUUID) {
    calls.remove(callUUID);
  }

  void createIncomingCall(String uuid, String number, String name,
      String photo, String cookie) {
    calls[uuid] = Call(number, name, photo: photo, cookie: cookie);
  }

  Future<void> setOnHold(String callUUID, bool held) async {
    _callKeep.setOnHold(callUUID, held);
    final String handle = calls[callUUID].number;
    print('[setOnHold: $held] $callUUID, number: $handle');
    setCallHeld(callUUID, held);
  }

  Future<void> setMutedCall(String callUUID, bool muted) async {
    _callKeep.setMutedCall(callUUID, muted);
    final String handle = calls[callUUID].number;
    print('[setMutedCall: $muted] $callUUID, number: $handle');
    setCallMuted(callUUID, muted);
  }
}
