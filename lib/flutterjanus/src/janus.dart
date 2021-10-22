import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:logger/logger.dart';
import 'package:random_string/random_string.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../flutterjanus.dart';

class Janus {
  // A number of variable and functions are not relevant
  // but they are captured to create 1 to 1 mapping
  // between janus.js and the flutter_janus

  // List of sessions
  static Map<String, Session> sessions = {};

  // Extension
  static bool isExtensionEnable() => true;

  // Default extension
  static Map defaultExtension = {};

  // Default dependencies
  static Map useDefaultDependencies = {};

  // Old dependencies
  static Map useOldDependencies = {};

  static String dataChanDefaultLabel = "JanusDataChannel";
  static RTCIceCandidate
      endOfCandidates; // https://github.com/meetecho/janus-gateway/issues/1670

  static String debugLevel;
  static Logger logger;
  static int methodCount = 0;
  static int errorMethodCount = 0;

  static vdebug(dynamic msg, [dynamic err, StackTrace stackTrace]) {
    logger.v(msg, err, stackTrace);
  }

  static debug(dynamic msg, [dynamic err, StackTrace stackTrace]) {
    if (debugLevel == 'all' || debugLevel == 'debug')
      logger.d(msg, err, stackTrace);
  }

  static log(dynamic msg, [dynamic err, StackTrace stackTrace]) {
    if (debugLevel == 'all' || debugLevel == 'log')
      logger.i(msg, err, stackTrace);
  }

  static warn(dynamic msg, [dynamic err, StackTrace stackTrace]) {
    if (debugLevel == 'all' || debugLevel == 'warn')
      logger.w(msg, err, stackTrace);
  }

  static error(dynamic msg, [dynamic err, StackTrace stackTrace]) {
    if (debugLevel == 'all' || debugLevel == 'error')
      logger.e(msg, err, stackTrace);
  }

  static trace(dynamic msg, [dynamic err, StackTrace stackTrace]) {
    if (debugLevel == 'all' || debugLevel == 'trace')
      logger.wtf(msg, err, stackTrace);
  }

  static bool initDone = false;

  static bool unifiedPlan = false;

  static Map<String, dynamic> webRTCAdapter = {
    'browserDetails': {'browser': null, 'vesion': null}
  };

  static init({@required Map options, Function callback}) {
    if (Janus.initDone) {
      Janus.log("Library alreaday Initialised");
      if (callback is Function) callback();
    } else {
      if (options['debug'] != null) debugLevel = options['debug'];
      logger = Logger();
      Janus.log("Initializing library");
      initDone = true;
      if (callback is Function) callback();
    }
  }

  static isArray(arr) {
    return (arr is List) ? true : false;
  }

  static isWebrtcSupported() => true;

  static isGetUserMediaAvailable() => true;

  static randomString(int len) {
    return randomAlpha(len);
  }

  static httpAPICall(url, options, [GatewayCallbacks callbacks]) {
    int timeout = 60;
    Future<http.Response> fetching;
    final jsonEncoder = JsonEncoder();

    Map<String, String> fetchOptions = {
      // 'headers': 'Accept': 'application/json, text/plain, */*',
      'cache': 'no-cache'
    };
    Janus.debug(options.toString());
    if (options['withCredentials'] != null) {
      if (options['withCredentials']) {
        fetchOptions['credentials'] = 'include';
      } else {
        fetchOptions['credentials'] = 'omit';
      }
    }

    if (options['timeout'] != null) {
      timeout = options['timeout'];
    }
    if (options['verb'] == "GET" || options['verb'] == 'get') {
      fetching = http.get(Uri.parse(url), headers: fetchOptions);
    }
    if (options['verb'] == "POST" || options['verb'] == 'post') {
      String body;
      if (options['body'] != null) {
        body = jsonEncoder.convert(options['body']);
      }

      // fetchOptions['headers']['Content-Type'] = 'application/json';
      fetching = http.post(Uri.parse(url), headers: fetchOptions, body: body);
    }

    try {
      fetching.timeout(Duration(seconds: timeout),
          onTimeout: () =>
              Janus.error('Request timed out: ' + timeout.toString()))
          .then((response) {
        if (response != null && response.statusCode == 200) {
          if (callbacks != null && callbacks.success is Function) {
            callbacks.success(jsonDecode(response.body));
          }
        } else {
          if (response != null) {
            callbacks.error(
                'API call failed ',
                response.statusCode.toString() + response.body);
          } else {
            callbacks.error(
                'API call failed ', 'respone is null');
          }
        }
      /*
      }).catchError((error, StackTrace stackTrace) {
        Janus.error('Internal Error', error);
        Janus.debug(options);
       */
      });
    } catch (error) {
      Janus.debug(error.toString());
    }
  }

  static listDevices(Function callback, Map config) {
    if (config == null) {
      config = {
        'audio': true,
        'video': true,
      };
      MediaDevices.getUserMedia(config).then((MediaStream stream) {
        MediaDevices.getSources().then((devices) {
          Janus.debug(devices.toString());
          callback(devices);
          // Get rid of the now useless stream
          try {
            List<MediaStreamTrack> audioTracks = stream.getAudioTracks();
            for (var mst in audioTracks) {
              if (mst != null) mst.dispose();
            }
            List<MediaStreamTrack> videoTracks = stream.getVideoTracks();
            for (var mst in videoTracks) {
              if (mst != null) mst.dispose();
            }
          } catch (e) {
            Janus.error(e);
          }
        }).catchError((err) => Janus.error(err));
      }).catchError((err) => Janus.error(err));
    }
  }
}
