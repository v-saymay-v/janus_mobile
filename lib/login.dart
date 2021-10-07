import 'dart:async';
import 'dart:convert';
import 'dart:convert' show json;
import 'dart:ui';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:dio/dio.dart';
import 'package:html/parser.dart';
import 'package:flutter/material.dart';
import 'package:uni_links/uni_links.dart';
import 'package:auth_buttons/auth_buttons.dart';
import 'package:nonce/nonce.dart';
import 'package:crypto/crypto.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:dart_notification_center/dart_notification_center.dart';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:flutter_facebook_login/flutter_facebook_login.dart';
import 'package:flutter_twitter/flutter_twitter.dart';
import 'package:twitter_api/twitter_api.dart';

import 'globals.dart' as globals;
import 'qrcode.dart';

enum UniLinksType { string, uri }

class MyLoginPage extends StatefulWidget {
  MyLoginPage({Key key, this.title, this.googleSignIn, this.twitterLogin, this.facebookSignIn}) : super(key: key);

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;
  final GoogleSignIn googleSignIn;
  final FacebookLogin facebookSignIn;
  final TwitterLogin twitterLogin;

  @override
  _MyLoginPageState createState() => _MyLoginPageState();
}

class _MyLoginPageState extends State<MyLoginPage> {
  /*
  GoogleSignInAccount _currentUser;
  */
  final _formKey = GlobalKey<FormState>();
  final urlController = TextEditingController();
  final uidController = TextEditingController();
  final pwdController = TextEditingController();

  String _message = 'Log in by pressing the buttons above.';
  bool _showPassword = false;

  //String _latestLink = 'Unknown';
  //Uri _latestUri;
  StreamSubscription _sub;
  UniLinksType _type = UniLinksType.string;

  @override
  void initState() {
    super.initState();
    /*
    _googleSignIn.onCurrentUserChanged.listen((GoogleSignInAccount account) {
      setState(() {
        _currentUser = account;
      });
      if (_currentUser != null) {
        print("google displayName = ${_currentUser.displayName}");
        print("google email = ${_currentUser.email}");
        print("google photo = ${_currentUser.photoUrl}");
        //_handleGetContact();
      }
    });
    _googleSignIn.signInSilently();
     */
    DartNotificationCenter.registerChannel(channel: globals.kJoinedSuccess);
    DartNotificationCenter.subscribe(
      channel: globals.kJoinedSuccess,
      observer: 1,
      onNotification: (result) {
        globals.showPopupDialog(context: context, title: "登録完了", content: "janusmobileに登録されました", cancel: "閉じる");
      },
    );
  }

  @override
  void dispose() {
    if (_sub != null) _sub.cancel();
    DartNotificationCenter.unsubscribe(observer: 1, channel: globals.kJoinedSuccess);
    DartNotificationCenter.unregisterChannel(channel: globals.kJoinedSuccess);
    super.dispose();
  }

  /*
  Future<void> _handleGetContact() async {
    print("Loading contact info...");
    final http.Response response = await http.get(
      'https://people.googleapis.com/v1/people/me/connections'
          '?requestMask.includeField=person.names,person.email_addresses',
      headers: await _currentUser.authHeaders,
    );
    if (response.statusCode != 200) {
      print("People API gave a ${response.statusCode} "
            "response. Check logs for details.");
      print('People API ${response.statusCode} response: ${response.body}');
      return;
    }
    final Map<String, dynamic> data = json.decode(response.body);
    final String namedContact = _pickFirstNamedContact(data);
    if (namedContact != null) {
      print("I see you know $namedContact!");
    } else {
      print("No contacts to display.");
    }
  }

  String _pickFirstNamedContact(Map<String, dynamic> data) {
    final List<dynamic> connections = data['connections'];
    final Map<String, dynamic> contact = connections?.firstWhere(
          (dynamic contact) => contact['names'] != null,
      orElse: () => null,
    );
    if (contact != null) {
      final Map<String, dynamic> name = contact['names'].firstWhere(
            (dynamic name) => name['displayName'] != null,
        orElse: () => null,
      );
      if (name != null) {
        return name['displayName'];
      }
    }
    return null;
  }
  */

  Future<void> _loginGoogle() async {
    await widget.googleSignIn.signIn().then((result) {
      result.authentication.then((googleKey) async {
        print(googleKey.idToken);
        var fullName = widget.googleSignIn.currentUser.displayName;
        var email = widget.googleSignIn.currentUser.email;
        var token = googleKey.accessToken;
        var userid = googleKey.idToken;
        var secret = '';
        var photo = widget.googleSignIn.currentUser.photoUrl;
        var cover = '';
        print("google displayName = $fullName");
        print("google email = $email");
        print("google token = $token");
        print("google photo = $photo");
        bool result = await _loginWithjanusmobile("google", fullName, email, token, secret, userid, photo, cover);
      }).catchError((err){
        print('inner error');
      });
    }).catchError((err){
      print('error occured');
    });
  }

  Future<Null> _loginFacebook() async {
    final FacebookLoginResult result = await widget.facebookSignIn.logIn(['email']);
    switch (result.status) {
      case FacebookLoginStatus.loggedIn:
        final FacebookAccessToken accessToken = result.accessToken;
        var graphResponse = await http.get(
            Uri.parse('https://graph.facebook.com/v2.12/me?fields=name,email,picture,cover&access_token=${accessToken.token}'));
        var profile = json.decode(graphResponse.body);
        var fullName = profile['name'];
        var email = profile['email'];
        var token = accessToken.token;
        var secret = '';
        var userid = accessToken.userId;
        var photo = profile['picture']!=null?profile['picture']['url']:"";
        var cover = profile['cover']!=null?profile['cover']['source']:"";
        print("Facebook displayName = $fullName");
        print("Facebook email = $email");
        print("Facebook token = $token");
        print("Facebook photo = $photo");
        print("Facebook cover = $cover");
        bool rt = await _loginWithjanusmobile("facebook", fullName, email, token, secret, userid, photo, cover);
        break;
      case FacebookLoginStatus.cancelledByUser:
        print('Login cancelled by the user.');
        break;
      case FacebookLoginStatus.error:
        print('Something went wrong with the login process.\n'
            'Here\'s the error Facebook gave us: ${result.errorMessage}');
        break;
    }
  }

  Future<Null> _loginTwitter() async {
    final TwitterLoginResult result = await widget.twitterLogin.authorize();

    switch (result.status) {
      case TwitterLoginStatus.loggedIn:
        var session = result.session;
        // Creating the twitterApi Object with the secret and public keys
        // These keys are generated from the twitter developer page
        // Don't share the keys with anyone
        final _twitterOauth = new twitterApi(
            consumerKey: globals.twitterConsumerApiKey,
            consumerSecret: globals.twitterConsumerApiSecret,
            token: session.token,
            tokenSecret: session.secret
        );

        // Make the request to twitter
        Future twitterRequest = _twitterOauth.getTwitterRequest(
          // Http Method
          "GET",
          // Endpoint you are trying to reach
          //"users/show.json",
          "account/verify_credentials.json",
          // The options for the request
          options: {
            "user_id": session.userId,
            "screen_name": session.username,
            //"include_entities": 'false',
            "include_email": 'true',
            //"count": "20",
            //"trim_user": "true",
            //"tweet_mode": "extended", // Used to prevent truncating tweets
          },
        );

        // Wait for the future to finish
        var res = await twitterRequest;

        // Print off the response
        print(res.statusCode);
        try {
          Map<String, dynamic> user = json.decode(res.body);
          //_sendTokenAndSecretToServer(session.token, session.secret);
          var fullName = user['name'];
          var email = user['email'];
          var token = session.token;
          var secret = session.secret;
          var userid = session.userId;
          var photo = user['profile_image_url_https'];
          var cover = user['profile_background_image_url_https'];
          print("Twitter displayName = $fullName");
          print("Twitter email = $email");
          print("Twitter token = $token");
          print("Twitter secret = $secret");
          print("Twitter photo = $photo");
          print("Twitter cover = $cover");
          bool result = await _loginWithjanusmobile("twitter", fullName, email, token, secret, userid, photo, cover);
        } catch (err) {
          print("JSON parse failed");
        }
        break;
      case TwitterLoginStatus.cancelledByUser:
      //_showCancelMessage();
        break;
      case TwitterLoginStatus.error:
      //_showErrorMessage(result.error);
        break;
    }
  }

  Future<Null> _loginApple() async {
    final rawNonce = Nonce.generate();
    final state = Nonce.generate();
    final webAuthenticationOptions = (Platform.isIOS || Platform.isMacOS)?null:
    WebAuthenticationOptions(
      // TODO: Set the `clientId` and `redirectUri` arguments to the values you entered in the Apple Developer portal during the setup
      clientId: 'jp.asj.janusmobile.service',
      redirectUri: Uri.parse(
        'https://room.yourcompany.com/janusmobile/janusmobile.php',
      ),
    );
    final credential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      webAuthenticationOptions: webAuthenticationOptions,
      // TODO: Remove these if you have no need for them
      nonce: sha256.convert(utf8.encode(rawNonce)).toString(),
      state: state,
    );
    print(credential);

    var map = parseJwt(credential.identityToken);
    var fullName = credential.familyName!=null&&credential.givenName!=null?credential.familyName + " " + credential.givenName:null;
    var email = map['email'];
    var token = credential.userIdentifier;
    var userid =  map['sub'];
    var secret = '';
    var photo = '';
    var cover = '';
    print("Apple displayName = $fullName");
    print("Apple email = $email");
    print("Apple token = $token");
    print("Apple secret = $secret");
    bool result = await _loginWithjanusmobile("apple", fullName, email, token, secret, userid, photo, cover);
  }

  Map<String, dynamic> parseJwt(String token) {
    final parts = token.split('.');
    if (parts.length != 3) {
      throw Exception('invalid token');
    }

    final payload = _decodeBase64(parts[1]);
    final payloadMap = json.decode(payload);
    if (payloadMap is! Map<String, dynamic>) {
      throw Exception('invalid payload');
    }

    return payloadMap;
  }

  String _decodeBase64(String str) {
    String output = str.replaceAll('-', '+').replaceAll('_', '/');

    switch (output.length % 4) {
      case 0:
        break;
      case 2:
        output += '==';
        break;
      case 3:
        output += '=';
        break;
      default:
        throw Exception('Illegal base64url string!"');
    }

    return utf8.decode(base64Url.decode(output));
  }

  Future onScan(String data) async {
    Uri uri = Uri.parse(data);
    final pos = uri.path.lastIndexOf('/');
    final path = uri.path.substring(0, pos+1);
    String url = uri.scheme + '://' + uri.host + path;
    urlController.text = url;
  }


  // Platform messages are asynchronous, so we initialize in an async method.
  initPlatformState() async {
    if (_type == UniLinksType.string) {
      await initPlatformStateForStringUniLinks();
    } else {
      await initPlatformStateForUriUniLinks();
    }
    //print(_latestLink);
  }

  /// An implementation using a [String] link
  initPlatformStateForStringUniLinks() async {
    // Attach a second listener to the stream
    _sub = /*getLinksStream()*/linkStream.listen((String link) async {
      print('got link: $link');
      try {
        final hbUri = Uri.parse(link);
        if (hbUri.scheme == "janusmobile") {
          if (hbUri.host == "join") {
            var company;
            var group;
            var name;
            hbUri.queryParameters.forEach((k, v) {
              print('key: $k - value: $v');
              if (k == "company") {
                company = v;
              } else if (k == "group") {
                group = v;
              } else if (k == "name") {
                name = v;
              }
            });
            if (company != null && group != null) {
              String sess = await globals.storage.read(key: "session");
              String session = Uri.encodeQueryComponent(sess);
              var uri = "https://room.yourcompany.com/janusmobile/change_group.php?token=" +
                  session + "&company=" + company + "&group=" + group;
              http.Response response = await http.get(Uri.parse(uri));
              if (response.statusCode != 200) {
                await globals.showPopupDialog(context: context,
                    title: "エラー",
                    content: "サイトにアクセスできません",
                    cancel: "閉じる");
                return;
              }
              var groups = json.decode(response.body);
              if (groups['result'] != 0) {
                print(groups['result_string']);
                await globals.showPopupDialog(context: context,
                    title: "エラー",
                    content: groups['result_string'],
                    cancel: "閉じる");
                return;
              }
              await globals.storage.write(key: "groupID", value: group);
              await globals.storage.write(key: "groupName", value: name);
              await globals.storage.write(key: "companyID", value: company);
              DartNotificationCenter.post(
                channel: globals.kJoinedSuccess,
              );
            }
          } else if (hbUri.host == "guest") {
            var cmd;
            var gid;
            var mid;
            var pwd;
            hbUri.queryParameters.forEach((k, v) {
              print('key: $k - value: $v');
              if (k == "gid") {
                gid = v;
              } else if (k == "mid") {
                mid = v;
              } else if (k == "cmd") {
                cmd = v;
              } else if (k == "pwd") {
                pwd = v;
              }
            });
            if (cmd == "login") {
              loginGuest(gid, mid, pwd);
            }
          }
        } else {
          await closeWebView();
        }
      } on FormatException {}
    }, onError: (err) {
      print('got err: $err');
    });
  }

  /// An implementation using the [Uri] convenience helpers
  initPlatformStateForUriUniLinks() async {
    // Attach a second listener to the stream
    _sub = /*getUriLinksStream()*/linkStream.listen((String url) async {
      Uri uri = Uri.parse(url);
      await closeWebView();
    }, onError: (err) {
      print('got err: $err');
    });
  }

  loginGuest(String gid, String mid, String pwd) async {
    if (await globals.readLoginInfo()) {
      var loginType = await globals.storage.read(key: "loginType");
      switch (loginType) {
        case 'twitter':
          await widget.twitterLogin.logOut();
          break;
        case 'facebook':
          await widget.facebookSignIn.logOut();
          break;
        case 'google':
          await widget.googleSignIn.disconnect();
          break;
        case 'apple':
          break;
        case 'guest':
          break;
      }
      await globals.storage.delete(key: "userID");
      await globals.storage.delete(key: "loginType");
      await globals.storage.delete(key: "session");
    }
    String push = await globals.storage.read(key: "pushToken");
    String apns = await globals.storage.read(key: "apnsToken");
    String voip = await globals.storage.read(key: "voipToken");
    var isRelease = const bool.fromEnvironment('dart.vm.product');
    final uri = 'https://room.yourcompany.com/janusmobile/guestlogin.php';
    var map = new Map<String, dynamic>();
    map['os'] = Platform.isIOS?'ios':'android';
    map['push'] = push;
    map['apns'] = apns==null?'':apns;
    map['voip'] = voip==null?'':voip;
    map['debug'] = isRelease?"0":"1";
    map['gid'] = gid;
    map['mid'] = mid;
    map['pwd'] = pwd;
    http.Response response = await http.post(Uri.parse(uri), body: map);

    print(response.body);
    if (response.statusCode != 200) {
      await globals.showPopupDialog(context: context, title: "エラー", content: "サイトにアクセスできません", cancel: "閉じる");
      return false;
    }
    final bodyMap = json.decode(response.body);
    if (bodyMap['result'] != 0) {
      print(bodyMap['result_string']);
      await globals.showPopupDialog(context: context, title: "エラー", content: bodyMap['result_string'], cancel: "閉じる");
      return false;
    }

    List<dynamic> mails = bodyMap['mails'];
    await globals.storage.write(key: "email", value: mails[0]);
    await globals.storage.write(key: "userID", value: bodyMap['user_id'].toString());
    await globals.storage.write(key: "loginType", value: 'guest');
    await globals.storage.write(key: "session", value: bodyMap['result_string']);
    await globals.storage.write(key: "groupID", value: bodyMap['group_id'].toString());
    await globals.storage.write(key: "groupName", value: bodyMap['group_name']);
    await globals.storage.write(key: "companyID", value: bodyMap['company_id'].toString());
    await globals.storage.write(key: "companyName", value: bodyMap['company_name']);
    await globals.storage.write(key: "isAdmin", value: bodyMap['is_admin'].toString());
    await globals.storage.write(key: "number", value: bodyMap['my_room']);
    await globals.storage.write(key: "roomPass", value: bodyMap['room_pass']);
    await globals.storage.write(key: "snsID", value: "");
    await globals.storage.write(key: "token", value: "");
    await globals.storage.write(key: "secret", value: "");
    await globals.storage.write(key: "fullName", value: bodyMap['disp_name']);
    await globals.storage.write(key: "photo", value: "");
    await globals.storage.write(key: "cover", value: "");

    Navigator.of(context).pushReplacementNamed('/home');
    return true;
  }

  Future<bool> _loginWithjanusmobile(String type, String fullName, String email, String token, String secret, String userid, String photo, String cover) async {
    // This is the endpoint that will convert an authorization code obtained
    // via Sign in with Apple into a session in your system
    String push = await globals.storage.read(key: "pushToken");
    String apns = await globals.storage.read(key: "apnsToken");
    String voip = await globals.storage.read(key: "voipToken");
    var isRelease = const bool.fromEnvironment('dart.vm.product');
    final uri = 'https://room.yourcompany.com/janusmobile/balogin.php';
    var map = new Map<String, dynamic>();
    map['os'] = Platform.isIOS?'ios':'android';
    map['type'] = type;
    map['uid'] = userid;
    map['name'] = fullName==null?'':fullName;
    map['email'] = email;
    map['push'] = push;
    map['apns'] = apns==null?'':apns;
    map['voip'] = voip==null?'':voip;
    map['debug'] = isRelease?"0":"1";
    map['token'] = token;
    map['secret'] = secret;
    map['photo'] = photo;
    map['cover'] = cover;
    http.Response response = await http.post(Uri.parse(uri), body: map);

    print(response.body);
    if (response.statusCode != 200) {
      await globals.showPopupDialog(context: context, title: "エラー", content: "サイトにアクセスできません", cancel: "閉じる");
      return false;
    }
    final bodyMap = json.decode(response.body);
    if (bodyMap['result'] != 0) {
      print(bodyMap['result_string']);
      await globals.showPopupDialog(context: context, title: "エラー", content: bodyMap['result_string'], cancel: "閉じる");
      return false;
    }

    await globals.storage.write(key: "userID", value: bodyMap['user_id'].toString());
    await globals.storage.write(key: "snsID", value: userid);
    await globals.storage.write(key: "loginType", value: type);
    await globals.storage.write(key: "session", value: bodyMap['result_string']);
    await globals.storage.write(key: "token", value: token);
    await globals.storage.write(key: "secret", value: secret);
    await globals.storage.write(key: "groupID", value: bodyMap['group_id'].toString());
    await globals.storage.write(key: "groupName", value: bodyMap['group_name'].toString());
    await globals.storage.write(key: "companyID", value: bodyMap['company_id'].toString());
    await globals.storage.write(key: "companyName", value: bodyMap['company_name'].toString());
    await globals.storage.write(key: "isAdmin", value: bodyMap['is_admin'].toString());
    await globals.storage.write(key: "email", value: email);
    if (fullName != null) {
      await globals.storage.write(key: "fullName", value: fullName);
    }
    await globals.storage.write(key: "photo", value: photo);
    await globals.storage.write(key: "cover", value: cover);
    await globals.storage.write(key: "number", value: bodyMap['my_room']);
    await globals.storage.write(key: "roomPass", value: bodyMap['room_pass']);

    //Navigator.of(context).pop();
    Navigator.of(context).pushReplacementNamed('/home');
    return true;
  }

  @override
  Widget build(BuildContext context) {
    bool darkMode = false;
    //AuthButtonStyle authButtonStyle = AuthButtonStyle.icon;
    return MaterialApp(
      home: new Scaffold(
        appBar: new AppBar(
          title: new Text(widget.title),
        ),
        body: new Container(
          color: darkMode ? Color(0xff303030) : Colors.white,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GoogleAuthButton(
                onPressed: _loginGoogle,
                darkMode: darkMode,
                //style: authButtonStyle,
              ),
              Divider(),
              FacebookAuthButton(
                onPressed: _loginFacebook,
                darkMode: darkMode,
                //style: authButtonStyle,
              ),
              Divider(),
              TwitterAuthButton(
                onPressed: _loginTwitter,
                darkMode: darkMode,
                //style: authButtonStyle,
              ),
              Divider(),
              AppleAuthButton(
                onPressed: _loginApple,
                darkMode: darkMode,
                //style: authButtonStyle,
              ),
              Divider(),
              new Text(_message),
            ],
          ),
        ),
      ),
    );
  }
}
