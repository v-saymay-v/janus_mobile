import 'dart:convert' show json;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_facebook_login/flutter_facebook_login.dart';
import 'package:flutter_twitter/flutter_twitter.dart';
import 'package:flutter_email_sender/flutter_email_sender.dart';

import 'globals.dart' as globals;
import "drawer.dart";
import "VideoRoom.dart";
import "video_room.dart";
import "video_call.dart";
import "callkeepdelegate.dart";

class MemberPage extends StatefulWidget {
  MemberPage({Key key, this.delegate, this.googleSignIn, this.twitterLogin, this.facebookSignIn}) : super(key: key);

  final CallKeepDelegate delegate;
  final GoogleSignIn googleSignIn;
  final FacebookLogin facebookSignIn;
  final TwitterLogin twitterLogin;

  @override
  _MemberPageState createState() => new _MemberPageState();
}

class _MemberPageState extends State<MemberPage> {

  String _token;
  String _userID;
  String _myRoom;
  String _roomPass;
  String _loginType;
  String _fullName;
  List<Map<String, dynamic>> _members = []; //List<Map<String, dynamic>>();

  @override
  void initState() {
    globals.readLoginInfo(/*context*/).then((value) {
      if (!value) {
        Navigator.of(context).pushNamed('/login');
      }
    });
    super.initState();
    readMemberList();
  }

  void readMemberList() async {
    _token = await globals.storage.read(key: "token");
    _userID = await globals.storage.read(key: "userID");
    _myRoom = await globals.storage.read(key: "number");
    _fullName = await globals.storage.read(key: "fullName");
    _loginType = await globals.storage.read(key: "loginType");
    _roomPass = await globals.storage.read(key: "roomPass");
    String sess = await globals.storage.read(key: "session");
    if (sess != null) {
      String photo = await globals.storage.read(key: "photo");
      String session = Uri.encodeQueryComponent(sess);
      final uri = "https://room.yourcompany.com/janusmobile/member_list.php?token=" + session;
      http.Response response = await http.get(Uri.parse(uri));
      if (response.statusCode != 200) {
        await globals.showPopupDialog(context: context, title: "エラー", content: "サイトにアクセスできません", cancel: "閉じる");
        return;
      }
      final meetings = json.decode(response.body);
      if (meetings['result'] != 0) {
        print(meetings['result_string']);
        await globals.showPopupDialog(context: context, title: "エラー", content: meetings['result_string'], cancel: "閉じる");
        return;
      }
      var mt = meetings['members'];
      setState(() {
        _members.clear();
        for (int i = 0; i < mt.length; ++i) {
          var meeting = mt[i] as Map<String, dynamic>;
          meeting['photo'] = photo;
          meeting['cookie'] = "";
          _members.add(meeting);
        }
      });
    }
  }

  Future<bool> sendPushToken(String userid, String username) async {
    String sess = await globals.storage.read(key: "session");
    String session = Uri.encodeQueryComponent(sess);
    final uri = 'https://room.yourcompany.com/janusmobile/joinroomrequest.php?askto='+userid+'&token='+session;
    http.Response response = await http.get(Uri.parse(uri));

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
    await globals.showPopupDialog(context: context, title: "ルームに招待",
        content: username+"さんをミーティングに招待しました", cancel: "閉じる");
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return new Scaffold(
      appBar: AppBar(
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text("メンバー"),
        actions: <Widget>[
          IconButton(
            icon: Icon(FontAwesomeIcons.globe),
            onPressed: () {
              Navigator.push(
                context,
                //MaterialPageRoute(builder: (context) => VideoRoom(roomno:int.parse(_myRoom), displayname:_fullName)));
                MaterialPageRoute(builder: (context) => JanusVideoRoom(myRoom: _myRoom, roomPass: _roomPass, userName:_fullName)));
            },
            tooltip: "プライベートルーム",
          ),
          IconButton(
            icon: Icon(Icons.add),
            onPressed: () {
              inviteNewMember();
            },
            tooltip: "招待",
          )
        ],
      ),
      drawer: MyDrawer(googleSignIn: widget.googleSignIn, twitterLogin:widget.twitterLogin, facebookSignIn:widget.facebookSignIn),
      body: RefreshIndicator(
        onRefresh: () async {
          print('Loading New Data');
          readMemberList();
        },
        child: ListView.builder(
          itemBuilder: (BuildContext context, int index) => ExpansionTile(
            leading: Image(image: NetworkImage(_members[index]['photo'], headers: {'Cookie': _members[index]['cookie']})),
            title: Text(_members[index]['username']),
            subtitle: Text(_members[index]['groupname']),
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: <Widget>[
                    if(_members[index]['cancall']) ElevatedButton(
                      child: Text("通話"),
                      onPressed: () {
                        String callTo = _members[index]['userid'].toString()+'_'+_members[index]['username'];
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) =>
                            JanusVideoCall(delegate: widget.delegate,
                              callTo: callTo,
                              numberTo: _members[index]['roomid'].toString(),
                              photoTo: _members[index]['photo'].toString(),
                            )));
                      }
                    ),
                    ElevatedButton(
                      child: Text("ルームに参加"),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) =>
                              //VideoRoom(roomno:int.parse(_members[index]['roomid']), displayname:_fullName)));
                              JanusVideoRoom(myRoom: _members[index]['roomid'], roomPass:_members[index]['roompass'], userName:_fullName)));
                      },
                    ),
                    ElevatedButton(
                      child: Text("ルームに招待"),
                      onPressed: () {
                        sendPushToken(_members[index]['userid'].toString(), _members[index]['username'].toString());
                      },
                    ),
                  ]
                )
              )
            ],
          ),
          itemCount: _members.length,
        ),
      )
    );
  }

  inviteNewMember() async {
    bool isEditingMail = false;
    var textController = TextEditingController();
    String memberMail;
    String groupID;
    String groupName;
    bool bGuest = false;
    Map<String, String> groups = await globals.getGroupMap(context);
    return await showDialog<int>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, setState) {
            return AlertDialog(
              title: Text('メンバーを招待'),
              actions: <Widget>[
                TextButton(
                  child: Text('キャンセル'),
                  onPressed: () => Navigator.of(context).pop(0),
                ),
                TextButton(
                  child: Text('招待'),
                  onPressed: () {
                    if (bGuest) {

                    } else {
                      if (isEditingMail && groupID != null) {
                        sendMailToMember(memberMail, groupID, groupName).then((
                            val) =>
                            Navigator.of(context).pop(val));
                      }
                    }
                  },
                ),
              ],
              content: Container(
                width: double.maxFinite,
                //height: double.maxFinite,
                child: SingleChildScrollView(
                  physics: BouncingScrollPhysics(),
                  child: Padding(
                    padding: const EdgeInsets.only(left: 16.0, right: 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        /*
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            RichText(
                              text: TextSpan(
                                text: 'ゲストとして招待',
                                style: TextStyle(
                                  color: Colors.cyan,
                                  fontFamily: 'Raleway',
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                            Switch(
                              activeColor: Colors.cyan,
                              value: bGuest,
                              onChanged: (bool e) {
                                setState(() {
                                  bGuest = e;
                                });
                              }
                            ),
                          ]
                        ),
                        SizedBox(height: 10),
                         */
                        RichText(
                          text: TextSpan(
                            text: '招待するメンバーのメールアドレスを入力してください',
                            style: TextStyle(
                              color: Colors.cyan,
                              fontFamily: 'Raleway',
                              fontSize: 16,
                              //fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                        TextField(
                          enabled: true,
                          cursorColor: Colors.blueAccent,
                          controller: textController,
                          textCapitalization: TextCapitalization.sentences,
                          textInputAction: TextInputAction.next,
                          onChanged: (value) {
                            setState(() {
                              isEditingMail = true;
                              memberMail = value;
                            });
                          },
                          style: TextStyle(
                            color: Colors.black87,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                          decoration: new InputDecoration(
                            disabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.all(Radius.circular(10.0)),
                              borderSide: BorderSide(color: Colors.grey, width: 1),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.all(Radius.circular(10.0)),
                              borderSide: BorderSide(color: Colors.blueAccent, width: 1),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.all(Radius.circular(10.0)),
                              borderSide: BorderSide(color: Colors.blueAccent, width: 2),
                            ),
                            errorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.all(Radius.circular(10.0)),
                              borderSide: BorderSide(color: Colors.redAccent, width: 2),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.all(Radius.circular(10.0)),
                            ),
                            contentPadding: EdgeInsets.only(
                              left: 16,
                              bottom: 16,
                              top: 16,
                              right: 16,
                            ),
                            hintText: 'メールアドレス',
                            hintStyle: TextStyle(
                              color: Colors.grey.withOpacity(0.6),
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                            errorText: isEditingMail ? globals.validateEmail(memberMail) : null,
                            errorStyle: TextStyle(
                              fontSize: 12,
                              color: Colors.redAccent,
                            ),
                          ),
                        ),
                        SizedBox(height: 10),
                        Visibility(
                          visible: !bGuest,
                          child: RichText(
                            text: TextSpan(
                              text: '招待するメンバーが所属するグループを選択してください',
                              style: TextStyle(
                                color: Colors.cyan,
                                fontFamily: 'Raleway',
                                fontSize: 16,
                                //fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                        ),
                        Visibility(
                          visible: !bGuest,
                          child: DropdownButton<String>(
                            value: groupName,
                            icon: const Icon(Icons.arrow_downward, color: Colors.cyan,),
                            iconSize: 24,
                            elevation: 16,
                            style: const TextStyle(color: Colors.cyan),
                            underline: Container(
                              height: 2,
                              color: Colors.deepPurpleAccent,
                            ),
                            onChanged: (String newValue) {
                              for (var id in groups.keys) {
                                if (groups[id] == newValue) {
                                  groupID = id;
                                  break;
                                }
                              }
                              setState(() {
                                groupName = newValue;
                              });
                            },
                            items: groups.values.map<DropdownMenuItem<String>>((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(value),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }
        );
      }
    );
  }

  Future<int> sendMailToMember(String mail, String groupID, String groupName) async {
    String companyId = await globals.storage.read(key: "companyID");
    String name = await globals.storage.read(key: "fullName");
    String group = Uri.encodeQueryComponent(groupName);
    String body = name+"さんがあなたをjanusmobileに招待しています。\r\n\r\n"+
        "AppStoreからjanusmobileをインストールし、ユーザー登録後、Safariで下記のリンクにアクセスしてください。\r\n\r\n"+
        "janusmobile://join?company="+companyId+"&group="+groupID+"&name="+group+"\r\n\r\n"+
        "今後とも『janusmobile』よろしくお願い申し上げます。\r\n\r\n"+
        "janusmobileサポートチーム\r\n";
    final Email email = Email(
      body: body,
      subject: "BizAcces3へのご招待",
      recipients: [mail],
      isHTML: false,
    );

    int returnVal = 0;
    String platformResponse;

    try {
      await FlutterEmailSender.send(email);
      platformResponse = 'メールを送信しました';
      returnVal = 1;
    } catch (error) {
      platformResponse = error.toString();
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(platformResponse),
          backgroundColor: returnVal==0?Colors.redAccent:Colors.blueAccent,
          duration: Duration(seconds: 3, milliseconds: 500),
        ),
      );
    }
    return returnVal;
  }

  @override
  dispose() {
    super.dispose();
    _members.clear();
  }
}
