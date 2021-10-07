import 'dart:convert' show json;

import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_facebook_login/flutter_facebook_login.dart';
import 'package:flutter_twitter/flutter_twitter.dart';

import 'setting.dart';
import 'group.dart';
import 'globals.dart' as globals;

class MyDrawer extends StatefulWidget {
  MyDrawer({Key key, this.googleSignIn, this.twitterLogin, this.facebookSignIn}) : super(key: key);

  final GoogleSignIn googleSignIn;
  final FacebookLogin facebookSignIn;
  final TwitterLogin twitterLogin;

  @override
  _MyDrawerState createState() => new _MyDrawerState();
}

class _MyDrawerState extends State<MyDrawer> {
  String _companyID;
  String _companyName;

  @override
  void initState() {
    super.initState();
    setState(() {
      globals.storage.read(key: "companyID").then((value) => _companyID = value);
      globals.storage.read(key: "companyName").then((value) => _companyName = value);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        children: <Widget>[
          DrawerHeader(
            child: Text(
              'janusmobile3',
              style: TextStyle(
                fontSize: 24,
                color: Colors.white,
              ),
            ),
            decoration: BoxDecoration(
              color: Colors.blue,
            ),
          ),
          ListTile(
            leading: Icon(FontAwesomeIcons.building),
            title: Text('組織'),
            onTap: () {
              chageOrganizationName().then((val) => Navigator.pop(context));
            },
          ),
          ListTile(
            leading: Icon(FontAwesomeIcons.layerGroup),
            title: Text('グループ'),
            onTap: () {
              //setState(() => _city = 'Dallas, TX');
              Navigator.pop(context);
              dispGroupPage();
            },
          ),
          ListTile(
            leading: Icon(Icons.settings),
            title: Text('設定'),
            onTap: () {
              //setState(() => _city = 'Seattle, WA');
              Navigator.pop(context);
              dispSettingPage();
            },
          ),
          ListTile(
            leading: Icon(FontAwesomeIcons.signOutAlt),
            title: Text('サインアウト'),
            onTap: () {
              globals.storage.read(key: "loginType").then((String loginType) async {
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
                }
                await globals.storage.delete(key: "userID");
                await globals.storage.delete(key: "loginType");
                await globals.storage.delete(key: "session");
                Navigator.of(context).pushReplacementNamed('/login');
              });
            }
          )
        ],
      ),
    );
  }

  dispSettingPage() async {
    await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => SettingPage()));
  }

  dispGroupPage() async {
    await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => GroupPage()));
  }

  chageOrganizationName() async {
    var textController = TextEditingController();
    textController.text = _companyName;
    return await showDialog<int>(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return StatefulBuilder(
              builder: (BuildContext context, setState) {
                return AlertDialog(
                  title: Text('組織名編集'),
                  actions: <Widget>[
                    TextButton(
                      child: Text('キャンセル'),
                      onPressed: () => Navigator.of(context).pop(0),
                    ),
                    TextButton(
                      child: Text('変更'),
                      onPressed: () {
                        if (_companyName!=null&&_companyName.isNotEmpty) {
                          newOrgName().then((val) =>
                              Navigator.of(context).pop(val));
                        } else {

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
                            RichText(
                              text: TextSpan(
                                text: '組織名を指定してください',
                                style: TextStyle(
                                  color: Colors.cyan,
                                  fontFamily: 'Raleway',
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                            SizedBox(height: 10),
                            TextField(
                              enabled: true,
                              cursorColor: Colors.blueAccent,
                              controller: textController,
                              textCapitalization: TextCapitalization.sentences,
                              textInputAction: TextInputAction.next,
                              onChanged: (value) {
                                _companyName = value;
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
                                hintText: '組織名',
                                hintStyle: TextStyle(
                                  color: Colors.grey.withOpacity(0.6),
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
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

  Future<int> newOrgName() async {
    String session = Uri.encodeQueryComponent(await globals.storage.read(key: "session"));
    var uri = "https://room.yourcompany.com/janusmobile/change_organization.php?token=" +
        session + "&company=" + Uri.encodeQueryComponent(_companyName);
    http.Response response = await http.get(Uri.parse(uri));
    if (response.statusCode != 200) {
      await globals.showPopupDialog(context: context, title: "エラー", content: "サイトにアクセスできません", cancel: "閉じる");
      return 0;
    }
    var groups = json.decode(response.body);
    if (groups['result'] != 0) {
      await globals.showPopupDialog(context: context, title: "エラー", content: groups['result_string'], cancel: "閉じる");
      return 0;
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("組織の名所を変更しました。"),
          backgroundColor: Colors.blueAccent,
          duration: Duration(seconds: 3, milliseconds: 500),
        ),
      );
    }
    return 1;
  }
}
