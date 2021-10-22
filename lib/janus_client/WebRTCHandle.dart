
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'utils.dart';

class WebRTCHandle {
  bool started;
  MediaStream _myStream;

  MediaStream get myStream => _myStream;

  set myStream(MediaStream value) {
    _myStream = value;
  }

  bool streamExternal;
  List<RTCIceServer> iceServers;
  MediaStream remoteStream;
  RTCSessionDescription mySdp;
  dynamic mediaConstraints;
  RTCPeerConnection pc;

  Map<dynamic, RTCDataChannel> dataChannel = {};
  bool trickle;
  bool iceDone;
  Map<dynamic, dynamic> volume;
  Map<dynamic, dynamic> bitrate;

  WebRTCHandle(
      {this.started,
      this.streamExternal,
      this.remoteStream,
      this.mySdp,
      this.mediaConstraints,
      this.dataChannel,
      this.trickle,
      this.pc,
      this.iceDone,
      this.volume,
      this.bitrate,
      this.iceServers});
}
