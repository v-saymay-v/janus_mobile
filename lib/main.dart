import 'dart:io';
import 'dart:async';
import 'dart:convert' show json;

import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:uuid/uuid.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart' as firebasemessaging;
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
//import 'package:flutter_voip_push_notification/flutter_voip_push_notification.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:dart_notification_center/dart_notification_center.dart';
import 'package:uni_links/uni_links.dart';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_facebook_login/flutter_facebook_login.dart';
import 'package:flutter_twitter/flutter_twitter.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'janus_client/Plugin.dart';
//import 'components/size_config.dart';

import 'globals.dart' as globals;
import 'meeting.dart';
import 'member.dart';
import 'message.dart';
import 'VideoCall.dart';
import 'login.dart';
import 'callkeepdelegate.dart';
import "video_room.dart";

final CallKeepDelegate callDelegate = CallKeepDelegate();

final GoogleSignIn googleSignIn = GoogleSignIn(
  scopes: <String>[
    'email',
    'https://www.googleapis.com/auth/contacts.readonly',
  ],
);
final FacebookLogin facebookSignIn = new FacebookLogin();
final twitterLogin = TwitterLogin(
  // Consumer API keys
  consumerKey: globals.twitterConsumerApiKey,
  // Consumer API Secret keys
  consumerSecret: globals.twitterConsumerApiSecret,
);

List<Widget> _pageList = [
  MeetingPage(
      googleSignIn: googleSignIn,
      twitterLogin: twitterLogin,
      facebookSignIn: facebookSignIn),
  MemberPage(delegate: callDelegate,
      googleSignIn: googleSignIn,
      twitterLogin: twitterLogin,
      facebookSignIn: facebookSignIn),
  MessagePage(),
];

List<BottomNavigationBarItem> bottomBarItems = [
  BottomNavigationBarItem(
    icon: Icon(FontAwesomeIcons.globe),
    label: 'ミーティング',
    backgroundColor: Colors.blue,
  ),
  BottomNavigationBarItem(
    icon: Icon(FontAwesomeIcons.users),
    label: 'メンバー',
    backgroundColor: Colors.blue,
  ),
  BottomNavigationBarItem(
    icon: Icon(FontAwesomeIcons.mailBulk),
    label: 'メッセージ',
    backgroundColor: Colors.blue,
  ),
];

void handleIncommingCall(Map<String, dynamic> payload) {
  print('handleIncommingCall: data => ${payload.toString()}');
  var command = payload['command'] as String;
  var callerName = payload['from_name'] as String;
  var callerPhoto = payload['from_photo'] as String;

  if (command == "asktojoin") {
    var callerId = payload['from_number'] as String;
    var uuid = payload['uuid'] as String;
    var hasVideo = true;  // payload['has_video'] == "true";
    print('handleIncommingCall: displayIncomingCall ($callerId)');
    final callUUID = uuid ?? Uuid().v4();
    callDelegate.callKeep.displayIncomingCall(callUUID, callerId,
        localizedCallerName: callerName, hasVideo: hasVideo);
    if (Platform.isAndroid) {
      globals.storage.read(key: "token").then((token) {
        globals.storage.read(key: "uid").then((uid) {
          String cookie = "LOGINKEY="+token.toString()+"; LOGINID="+uid;
          callDelegate.createIncomingCall(callUUID, callerId, callerName,
              callerPhoto, cookie);
        });
      });
    }
  } else if (command == "joinroomrequest") {
    if (!NotificationManger.dialogShowing)
      NotificationManger._showDialog(data: payload, goToRoom: () async {
        await Navigator.push(
            NotificationManger._context,
            MaterialPageRoute(builder: (context) =>
              JanusVideoRoom(myRoom: payload['meeting'], roomPass:payload['room_pass'], userName:payload['from_name'])));
      });
  } else if (command == "makemenewadmin") {
    String content = payload['meeting']=="yes"?"管理者の変更が承認されました":"管理者の変更が否認されました";
    globals.showPopupDialog(context: NotificationManger._context, title: "管理者変更", content: content, submit: "確認");
    globals.storage.write(key: "isAdmin", value: payload['meeting']=="yes"?"1":"0");
    DartNotificationCenter.post(
      channel: globals.kAdminChanged,
      options: payload['meeting']=="yes"?"1":"0",
    );
  }
}

Future<dynamic> myBackgroundMessageHandler(firebasemessaging.RemoteMessage message) async {
  print("myBackgroundMessageHandler: "+message.toString());
  if (message.data != null) {
    handleIncommingCall(message.data);
    callDelegate.callKeep.backToForeground();
  }
  // Or do other work.
}

/// Create a [AndroidNotificationChannel] for heads up notifications
const AndroidNotificationChannel channel = AndroidNotificationChannel(
  'janus_mobile_importance_channel', // id
  'janusmobile Importance Notifications', // title
  'This channel is used for important notifications.', // description
  importance: Importance.high,
);

/// Initialize the [FlutterLocalNotificationsPlugin] package.
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  initializeDateFormatting("ja_JP");
  runApp(MyApp());
}

class NotificationManger {
  static BuildContext _context;
  static bool dialogShowing = false;

  static init({@required BuildContext context}) {
    _context = context;
  }

  //this method used when notification come and app is closed or in background and
  // user click on it, i will left it empty for you
  static handleDataMsg(Map<String, dynamic> data){
    _showDialog(data: data);
  }

  //this our method called when notification come and app is foreground
  static handleNotificationMsg(Map<String, dynamic> message) {
    debugPrint("from mangger  $message");

    final dynamic data = message['data'];
    //as ex we have some data json for every notification to know how to handle that
    //let say showDialog here so fire some action
    if (data.containsKey('showDialog')) {
      // Handle data message with dialog
      _showDialog(data: data);
    }
  }

  static _showDialog({@required Map<String, dynamic> data, goToRoom()}) async {
    //you can use data map also to know what must show in MyDialog
    var cookie = data['from_cookie'] as String;
    var uid = data['from_id'] as String;
    if (cookie == null) {
      cookie = await globals.storage.read(key: "token");
      uid = await globals.storage.read(key: "uid");
    }
    String cookieString = 'LOGINKEY='+cookie+'; LOGINID='+uid;
    dialogShowing = true;
    return showDialog<void>(
      barrierDismissible: true,
      context: _context,
      builder: (BuildContext context) {
        return new Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(0),
              child: new Container(
                height: 200,
                width: MediaQuery.of(context).size.width,
                color: Colors.purple,
                child: new Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    new Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget> [
                          new Image(image: NetworkImage(data['from_photo'], headers: {'Cookie': cookieString}), width:64, height:64),
                          new Padding(padding: EdgeInsets.only(right: 10)),
                          new Text(
                            data['from_name'] + "さんからミーティング参加要請",
                            style: new TextStyle(
                              fontSize: 14,
                              color: Colors.white,
                            ),
                          ),
                        ]
                    ),
                    new Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget> [
                          TextButton(
                            child: Text("参加する"),
                            onPressed: () {
                              Navigator.of(context).pop(true);
                              goToRoom();
                              dialogShowing = false;
                            },
                          ),
                          Padding(padding: EdgeInsets.only(right: 40)),
                          TextButton(
                            child: Text("見送る"),
                            onPressed: () {
                              Navigator.of(context).pop(false);
                              dialogShowing = false;
                            },
                          ),
                        ]
                    ),
                  ],
                ),
              ),
            )
          ],
        );
      },
    );
  }
}

class Splash extends StatefulWidget {
  @override
  _SplashState createState() => new _SplashState();
}

class _SplashState extends State<Splash> {
  @override
  void initState() {
    super.initState();

    new Future.delayed(const Duration(seconds: 3))
        .then((value) => handleTimeout());
  }

  @override
  Widget build(BuildContext context) {
    return new Scaffold(
      body: new Center(
        // TODO: スプラッシュアニメーション
        child: const CircularProgressIndicator(),
      ),
    );
  }

  void handleTimeout() {
    // ログイン画面へ
    Navigator.of(context).pushReplacementNamed("/home");
  }
}

class MyApp extends StatelessWidget {
  MyApp();

  // This widget is the root of your application.
  final String loginTitle = '各サービスを用いてログイン';

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'janusmobile Top page',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // Try running your application with "flutter run". You'll see the
        // application has a blue toolbar. Then, without quitting the app, try
        // changing the primarySwatch below to Colors.green and then invoke
        // "hot reload" (press "r" in the console where you ran "flutter run",
        // or simply save your changes to "hot reload" in a Flutter IDE).
        // Notice that the counter didn't reset back to zero; the application
        // is not restarted.
        primarySwatch: Colors.blue,
        // This makes the visual density adapt to the platform that you run
        // the app on. For desktop platforms, the controls will be smaller and
        // closer together (more dense) than on mobile platforms.
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      //home: MyHomePage(title: 'janusmobile'),
      initialRoute: '/',
      routes: <String, WidgetBuilder> {
        '/': (BuildContext context) => Splash(),
        '/home': (BuildContext context) => MyHomePage(title: 'janusmobile'),
        '/login': (BuildContext context) =>
            MyLoginPage(title: loginTitle,
                googleSignIn: googleSignIn,
                twitterLogin: twitterLogin,
                facebookSignIn: facebookSignIn),
      },
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  MyHomePageState createState() => MyHomePageState();
}

class MyHomePageState extends State<MyHomePage> /*with WidgetsBindingObserver*/ {
  //int _counter = 0;
  String _token;
  String _apnsToken;
  //final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final homePageKey = GlobalKey<MyHomePageState>();

  StreamSubscription _sub;
  //UniLinksType _type = UniLinksType.string;

  int _selectedIndex = 0;

  VideoCallState _videoCallState;
  Plugin publishVideo;
  List<dynamic> memberList;
  bool haveToPush = false;
  String makingCallNumber;
  String makingCallName;
  String makingCallPhoto;
  String makingCallCookie;

  //String _voipPushToken = '';
  //FlutterVoipPushNotification _voipPush = FlutterVoipPushNotification();

  @override
  void initState() {
    super.initState();

    callDelegate.context = context;

    /*
    setState(() {
      _pageList.add(MeetingPage(googleSignIn:_googleSignIn,
          twitterLogin:twitterLogin,
          facebookSignIn:facebookSignIn));
      _pageList.add(MemberPage(delegate: callDelegate,
          googleSignIn: _googleSignIn,
          twitterLogin: twitterLogin,
          facebookSignIn: facebookSignIn));
      _pageList.add(MessagePage());
      //SettingPage()
    });
     */

    DartNotificationCenter.registerChannel(channel: globals.kAdminChanged);
    /*
    DartNotificationCenter.registerChannel(channel: globals.kJoinedSuccess);
    DartNotificationCenter.subscribe(
      channel: globals.kJoinedSuccess,
      observer: 1,
      onNotification: (result) {
        globals.showPopupDialog(context: context, title: "登録完了", content: "janusmobileに登録されました", cancel: "閉じる");
      },
    );
     */

    initFireBase();
    NotificationManger.init(context: context);
    //initPlatformState();
    if (Platform.isAndroid)
      initPermission();
  }

  Future<void> initFireBase() async {
    await Firebase.initializeApp();

    firebasemessaging.NotificationSettings settings = await firebasemessaging.FirebaseMessaging.instance.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    if (settings.authorizationStatus == firebasemessaging.AuthorizationStatus.authorized) {
      print('User granted permission');
    } else if (settings.authorizationStatus == firebasemessaging.AuthorizationStatus.provisional) {
      print('User granted provisional permission');
    } else {
      print('User declined or has not accepted permission');
    }

    /// Create an Android Notification Channel.
    ///
    /// We use this channel in the `AndroidManifest.xml` file to override the
    /// default FCM channel to enable heads up notifications.
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    /// Update the iOS foreground notification presentation options to allow
    /// heads up notifications.
    await firebasemessaging.FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // Set the background messaging handler early on, as a named top-level function
    firebasemessaging.FirebaseMessaging.onBackgroundMessage(myBackgroundMessageHandler);

    firebasemessaging.FirebaseMessaging.instance
        .getToken().then((String token) {
      assert(token != null);
      _token = token;
      writePushToken();
      debugPrint("token: $_token");
    });

    firebasemessaging.FirebaseMessaging.instance
        .getAPNSToken().then((String token) {
      assert(token != null);
      _apnsToken = token;
      writeApnsToken();
      debugPrint("token: $_apnsToken");
    });

    firebasemessaging.FirebaseMessaging.instance
        .getInitialMessage()
        .then((firebasemessaging.RemoteMessage message) {
      print('Got Initial Message!');
      if (message != null) {
        //Navigator.pushNamed(context, '/message',
        //    arguments: MessageArguments(message, true));
      }
    });

    firebasemessaging.FirebaseMessaging.onMessage.listen((firebasemessaging.RemoteMessage message) {
      print('Got Normal Message!');
      firebasemessaging.RemoteNotification notification = message.notification;
      firebasemessaging.AndroidNotification android = message.notification?.android;
      Map<String, dynamic> data  = message.data;

      if (data != null) {
        handleIncommingCall(data);
      } else if (notification != null && android != null) {
        flutterLocalNotificationsPlugin.show(
          notification.hashCode,
          notification.title,
          notification.body,
          NotificationDetails(
            android: AndroidNotificationDetails(
              channel.id,
              channel.name,
              channel.description,
              // TODO add a proper drawable resource to android, for now using
              //      one that already exists in example app.
              icon: 'ic_launcher',
            ),
            iOS: IOSNotificationDetails(
              //attachments: [IOSNotificationAttachment('ic_launcher')]
            ),
          ));
      }
    });

    firebasemessaging.FirebaseMessaging.onMessageOpenedApp.listen((firebasemessaging.RemoteMessage message) {
      print('A new onMessageOpenedApp event was published!');
      //Navigator.pushNamed(context, '/message',
      //    arguments: MessageArguments(message, true));
    });
  }

  initPermission() async {
    Map<Permission, PermissionStatus> permissions = await [Permission.phone].request();
    print(permissions);
    if (permissions[Permission.phone] == PermissionStatus.granted) {
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void writePushToken() async {
    await globals.storage.write(key: "pushToken", value: _token);
  }

  void writeApnsToken() async {
    await globals.storage.write(key: "apnsToken", value: _apnsToken);
  }

  destroy() async {
    await _videoCallState.destroy();
  }

  @override
  dispose() {
    //WidgetsBinding.instance.removeObserver(this);
    if (_sub != null) _sub.cancel();
    //DartNotificationCenter.unsubscribe(observer: 1, channel: globals.kJoinedSuccess);
    //DartNotificationCenter.unregisterChannel(channel: globals.kJoinedSuccess);
    DartNotificationCenter.unregisterChannel(channel: globals.kAdminChanged);
    debugPrint("MyHomePageState disposed");
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      body: _pageList[_selectedIndex],
      bottomNavigationBar: Theme(
        data: ThemeData(
          primaryColor: Theme.of(context).primaryColor,
          canvasColor: Theme.of(context).canvasColor,
          textTheme: Theme.of(context).textTheme,
        ),
        child: BottomNavigationBar(
          selectedIconTheme: IconThemeData(
            color: Theme.of(context).iconTheme.color,
          ),
          //unselectedIconTheme: IconThemeData(
          //  color: Theme.of(context).primaryIconTheme.color,
          //),
          //type: BottomNavigationBarType.fixed,
          items: bottomBarItems,
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
        ),
      ),
    );
  }
}
