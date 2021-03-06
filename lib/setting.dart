import 'dart:convert' show json;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_email_sender/flutter_email_sender.dart';
import 'package:dart_notification_center/dart_notification_center.dart';

import 'globals.dart' as globals;

class SettingPage extends StatefulWidget {
  SettingPage({Key key}) : super(key: key);

  @override
  _SettingPageState createState() => new _SettingPageState();
}

class _SettingPageState extends State<SettingPage> with SingleTickerProviderStateMixin {

  Map<String, String> _groups;
  String _companyID;
  String _companyName;
  String _groupID;
  String _groupName;
  String _isAdmin;
  String _adminID;
  String _adminName;
  String _adminMail;

  @override
  void initState() {
    super.initState();
    _groups = {};
    setState(() {
      globals.storage.read(key: "companyID").then((value) => _companyID = value);
      globals.storage.read(key: "companyName").then((value) => _companyName = value);
      globals.storage.read(key: "groupID").then((value) => _groupID = value);
      globals.storage.read(key: "groupName").then((value) => _groupName = value);
      globals.storage.read(key: "isAdmin").then((value) => _isAdmin = value);
    });
    getGroupList();
    getAdminUser();
    DartNotificationCenter.subscribe(
      channel: globals.kAdminChanged,
      observer: 1,
      onNotification: (result) {
        setState(() {
          globals.storage.read(key: "isAdmin").then((value) => _isAdmin = value);
          getAdminUser();
        });
      },
    );
  }

  Future getGroupList() async {
    Map<String, String> groups = await globals.getGroupMap(context);
    setState(() {
      _groups = groups;
    });
  }

  Future getAdminUser() async {
    String companyId = await globals.storage.read(key: "companyID");
    String sess = await globals.storage.read(key: "session");
    final type = await globals.storage.read(key: "loginType");
    final photo = await globals.storage.read(key: "photo");
    String session = Uri.encodeQueryComponent(sess);
    var uri = "https://room.yourcompany.com/janusmobile/get_admin_user.php?token=" +
        session + "&company=" + companyId;
    http.Response response = await http.get(Uri.parse(uri));
    if (response.statusCode != 200) {
      await globals.showPopupDialog(context: context, title: "?????????", content: "???????????????????????????????????????", cancel: "?????????");
      return false;
    }
    var groups = json.decode(response.body);
    if (groups['result'] != 0) {
      print(groups['result_string']);
      await globals.showPopupDialog(context: context, title: "?????????", content: groups['result_string'], cancel: "?????????");
      return;
    }
    _adminID = groups['user_id'].toString();
    _adminName = groups['user_name'];
    _adminMail = groups['email'];
  }

  @override
  Widget build(BuildContext context) {
    globals.readLoginInfo(/*context*/).then((value) {
      if (!value) {
        Navigator.of(context).pushNamed('/login');
      }
    });
    return new Scaffold(
      appBar: AppBar(
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text("??????"),
      ),
      body: Stack(
        children: [
          Container(
            color: Colors.white,
            child: SingleChildScrollView(
              physics: BouncingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.only(left: 16.0, right: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        RichText(
                          text: TextSpan(
                            text: '??????',
                            style: TextStyle(
                              color: Colors.cyan,
                              fontFamily: 'Raleway',
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                        Spacer(),
                        Text(_companyName!=null&&_companyName.isNotEmpty?_companyName:'(?????????)',
                          style: TextStyle(
                            color: Colors.cyan,
                            fontFamily: 'Raleway',
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Visibility(
                          visible: _companyName==null||_companyName.isEmpty,
                          child: IconButton(
                            icon: Icon(Icons.change_circle),
                            onPressed: () {
                              // ??????????????????????????????????????????????????????????????????????????????????????????????????????????????????
                              createOrJoinOrganization();
                            },
                            //color: Colors.red,
                          ),
                        ),
                        Visibility(
                          visible: _companyName!=null&&_companyName.isNotEmpty,
                          child: SizedBox(width: 32),
                        ),
                      ],
                    ),
                    SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        RichText(
                          text: TextSpan(
                            text: '????????????',
                            style: TextStyle(
                              color: Colors.cyan,
                              fontFamily: 'Raleway',
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                        Spacer(),
                        Visibility(
                          visible: _groupName==null||_groupName.isEmpty,
                          child: Text('(?????????)',
                            style: TextStyle(
                              color: Colors.cyan,
                              fontFamily: 'Raleway',
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        Visibility(
                          visible: _groupName!=null&&_groupName.isNotEmpty,
                          child: DropdownButton<String>(
                            value: _groupName,
                            icon: const Icon(Icons.arrow_downward, color: Colors.cyan,),
                            iconSize: 24,
                            elevation: 16,
                            style: const TextStyle(color: Colors.cyan),
                            underline: Container(
                              height: 2,
                              color: Colors.deepPurpleAccent,
                            ),
                            onChanged: (String newValue) {
                              for (var id in _groups.keys) {
                                if (_groups[id] == newValue) {
                                  _groupID = id;
                                  break;
                                }
                              }
                              changeGroup().then((val) {
                                if (val > 0) {
                                  setState(() {
                                    _groupName = newValue;
                                  });
                                }
                              });
                            },
                            items: _groups.values.map<DropdownMenuItem<String>>((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(value),
                              );
                            }).toList(),
                          ),
                        ),
                        SizedBox(width: 32),
                      ],
                    ),
                    SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        RichText(
                          text: TextSpan(
                            text: '?????????',
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
                          value: _isAdmin!=null&&_isAdmin=='1',
                          onChanged: (bool e) {
                            if (e) {
                              // ??????????????????????????????????????????
                              makeMeNewAdmin();
                            } else {
                              // ???????????????????????????????????????????????????????????????????????????????????????
                              handOverAdmin();
                            }
                          }
                        ),
                      ]
                    ),
                  ]
                )
              )
            )
          )
        ]
      )
      /*
      Center(
        child: Text(
          "Setting",
          style: TextStyle(
            fontSize: Theme.of(context).textTheme.caption.fontSize,
            color: Theme.of(context).textTheme.caption.color,
          ),
        ),
      ),
       */
    );
  }

  @override
  dispose() {
    super.dispose();
    DartNotificationCenter.unsubscribe(observer: 1, channel: globals.kAdminChanged);
  }

  Future<int>changeGroup() async {
    String session = Uri.encodeQueryComponent(await globals.storage.read(key: "session"));
    var uri = "https://room.yourcompany.com/janusmobile/change_group.php?token=" + session +
        "&group=" + _groupID;
    http.Response response = await http.get(Uri.parse(uri));
    if (response.statusCode != 200) {
      showSnackBar(true, "???????????????????????????????????????");
      return 0;
    }
    var groups = json.decode(response.body);
    if (groups['result'] != 0) {
      showSnackBar(true, groups['result_string']);
      return 0;
    }
    return 1;
  }

  createOrJoinOrganization() async {
    bool bCreate = true;
    final List<Tab> tabs = <Tab>[
      Tab(text: '????????????',),
      Tab(text: "????????????",),
    ];
    TabController _tabController;
    _tabController = TabController(length: tabs.length, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        if (_tabController.index > 0) {
          bCreate = true;
        } else {
          bCreate = false;
        }
      }
    });
    return await showDialog<int>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, setState) {
            return AlertDialog(
              title: Text('???????????????'),
              actions: <Widget>[
                TextButton(
                  child: Text('???????????????'),
                  onPressed: () => Navigator.of(context).pop(0),
                ),
                TextButton(
                  child: Text('??????'),
                  onPressed: () {
                    if (bCreate) {
                      createOrganization().then((val) => Navigator.of(context).pop(val));
                    } else {
                      joinOrganization().then((val) => Navigator.of(context).pop(val));
                    }
                  },
                ),
              ],
              content: Container(
                width: double.maxFinite,
                height: double.maxFinite,
                child: SingleChildScrollView(
                  physics: BouncingScrollPhysics(),
                  child: Padding(
                    padding: const EdgeInsets.only(left: 16.0, right: 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TabBarView(
                          controller: _tabController,
                          children: <Widget>[
                            _firstTab(),
                            _secondTab(),
                          ],
                        ),                      ],
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

  Widget _firstTab() {
    bool isEditingMail = false;
    var textController = TextEditingController();
    return RefreshIndicator(
      onRefresh: () async {
        print('Loading New Data');
      },
      child: Column(
        children: [
          RichText(
            text: TextSpan(
              text: '?????????????????????????????????????????????????????????',
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
              isEditingMail = true;
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
              hintText: '?????????',
              hintStyle: TextStyle(
                color: Colors.grey.withOpacity(0.6),
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ]
      ),
    );
  }

  Future<int> createOrganization() async {
    String host = "";
    String type = await globals.storage.read(key: "loginType");
    String session = Uri.encodeQueryComponent(await globals.storage.read(key: "session"));
    var uri = "https://room.yourcompany.com/janusmobile/create_organization.php?token=" + session +
        "&company=" + Uri.encodeQueryComponent(_companyName) + "&host=" + host;
    http.Response response = await http.get(Uri.parse(uri));
    if (response.statusCode != 200) {
      showSnackBar(true, "???????????????????????????????????????");
      return 0;
    }
    var groups = json.decode(response.body);
    if (groups['result'] != 0) {
      showSnackBar(true, groups['result_string']);
      return 0;
    }
    if (mounted) {
      showSnackBar(true, "???????????????????????????????????????????????????????????????");
    }
    return 1;
  }

  Widget _secondTab() {
    bool isEditingMail = false;
    var textController = TextEditingController();
    return RefreshIndicator(
      onRefresh: () async {
        print('Loading New Data');
      },
      child: Column(
        children: [
          RichText(
            text: TextSpan(
              text: '??????????????????????????????????????????????????????????????????????????????????????????????????????',
              style: TextStyle(
                color: Colors.cyan,
                fontFamily: 'Raleway',
                fontSize: 20,
                fontWeight: FontWeight.bold,
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
              isEditingMail = true;
              _adminMail = value;
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
              hintText: '?????????????????????????????????',
              hintStyle: TextStyle(
                color: Colors.grey.withOpacity(0.6),
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
              errorText: isEditingMail ? globals.validateEmail(_adminMail) : null,
              errorStyle: TextStyle(
                fontSize: 12,
                color: Colors.redAccent,
              ),
            ),
          ),
        ]
      ),
    );
  }

  Future<int> joinOrganization() async {
    String name = await globals.storage.read(key: "fullName");
    String session = Uri.encodeQueryComponent(await globals.storage.read(key: "session"));
    String body = "<!DOCTYPE html>\n"+
        '<html lang="jp-JP">\n'+
        "<head><title>??????????????????</title></head>\n"+
        "<body>\n"+
        "<b>janusmobile3 ????????????</b><br />\n"+
        "<br />\n"+
        name + " ???????????????????????????????????????????????????????????????<br />\n"+
        "??????????????????????????????<br />\n"+
        "<br />\n"+
        '<a href="https://room.yourcompany.com/janusmobile/join_organization.php?session='+session+'&mail='+Uri.encodeQueryComponent(_adminMail)+'&allow=yes">??????</a>\n'+
        '<a href="https://room.yourcompany.com/janusmobile/join_organization.php?session='+session+'&mail='+Uri.encodeQueryComponent(_adminMail)+'&allow=no">??????</a><br />\n'+
        "</body>\n"+
        "</html>\n";
    final Email email = Email(
      body: body,
      subject: "BizAcces3??????????????????",
      recipients: [_adminMail],
      isHTML: true,
    );

    int returnVal = 0;
    String platformResponse;

    try {
      await FlutterEmailSender.send(email);
      platformResponse = '??????????????????????????????';
      returnVal = 1;
    } catch (error) {
      platformResponse = error.toString();
    }

    if (mounted) {
      showSnackBar(returnVal==0, platformResponse);
    }
    return returnVal;
  }

  makeMeNewAdmin() async {
    bool isEditingMail = false;
    var textController = TextEditingController();
    return await showDialog<int>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, setState) {
            return AlertDialog(
              title: Text('???????????????'),
              actions: <Widget>[
                TextButton(
                  child: Text('???????????????'),
                  onPressed: () => Navigator.of(context).pop(0),
                ),
                TextButton(
                  child: Text('??????'),
                  onPressed: () {
                    sendMailToAdmin().then((val) => Navigator.of(context).pop(val));
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
                              text: '??????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????',
                              style: TextStyle(
                                color: Colors.cyan,
                                fontFamily: 'Raleway',
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                          Visibility(
                            visible: _adminMail==null||_adminMail.isEmpty,
                            child: SizedBox(height: 10),
                          ),
                          Visibility(
                            visible: _adminMail==null||_adminMail.isEmpty,
                            child: TextField(
                              enabled: true,
                              cursorColor: Colors.blueAccent,
                              controller: textController,
                              textCapitalization: TextCapitalization.sentences,
                              textInputAction: TextInputAction.next,
                              onChanged: (value) {
                                setState(() {
                                  isEditingMail = true;
                                  _adminMail = value;
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
                                hintText: '?????????????????????????????????',
                                hintStyle: TextStyle(
                                  color: Colors.grey.withOpacity(0.6),
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                                errorText: isEditingMail ? globals.validateEmail(_adminMail) : null,
                                errorStyle: TextStyle(
                                  fontSize: 12,
                                  color: Colors.redAccent,
                                ),
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

  Future<int> sendMailToAdmin() async {
    String name = await globals.storage.read(key: "fullName");
    String sess = await globals.storage.read(key: "session");
    String session = Uri.encodeQueryComponent(sess);
    String body = "<!DOCTYPE html>\n"+
      '<html lang="jp-JP">\n'+
      "<head><title>????????????????????????</title></head>\n"+
      "<body>\n"+
      "<b>"+ _adminName + " ???</b><br />\n"+
      "<br />\n"+
      name + " ????????????janusmobile3???????????????????????????????????????????????????<br />\n"+
      "??????????????????????????????<br />\n"+
      "<br />\n"+
      '<a href="https://room.yourcompany.com/janusmobile/make_me_new_admin.php?session='+session+'&allow=yes">??????</a>\n'+
      '<a href="https://room.yourcompany.com/janusmobile/make_me_new_admin.php?session='+session+'&allow=no">??????</a><br />\n'+
      "</body>\n"+
      "</html>\n";
    final Email email = Email(
      body: body,
      subject: "BizAcces3???????????????????????????",
      recipients: ['"?????????" <'+_adminMail+'>'],
      isHTML: true,
    );

    int returnVal = 0;
    String platformResponse;

    try {
      await FlutterEmailSender.send(email);
      platformResponse = '??????????????????????????????';
      returnVal = 1;
    } catch (error) {
      platformResponse = error.toString();
    }

    if (mounted) {
      showSnackBar(returnVal==0, platformResponse);
    }
    return returnVal;
  }

  /*
  String _validateEmail(String value) {
    if (value != null) {
      value = value.trim();

      if (value.isEmpty) {
        return 'Can\'t add an empty email';
      } else {
        final regex = RegExp(
            r"^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,253}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,253}[a-zA-Z0-9])?)*$");
        final matches = regex.allMatches(value);
        for (Match match in matches) {
          if (match.start == 0 && match.end == value.length) {
            return null;
          }
        }
      }
    } else {
      return 'Can\'t add an empty email';
    }
    return 'Invalid email';
  }
   */

  handOverAdmin() async {
    bool isEditingMail = false;
    var textController = TextEditingController();
    String mail = "";
    return await showDialog<int>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, setState) {
            return AlertDialog(
              title: Text('???????????????'),
              actions: <Widget>[
                TextButton(
                  child: Text('???????????????'),
                  onPressed: () => Navigator.of(context).pop(0),
                ),
                TextButton(
                  child: Text('??????'),
                  onPressed: () {
                    sendMailToMember(mail).then((val) => Navigator.of(context).pop(val));
                  },
                ),
              ],
              content: Container(
                width: double.maxFinite,
                height: double.maxFinite,
                child: SingleChildScrollView(
                  physics: BouncingScrollPhysics(),
                  child: Padding(
                    padding: const EdgeInsets.only(left: 16.0, right: 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RichText(
                          text: TextSpan(
                            text: '??????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????',
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
                            setState(() {
                              isEditingMail = true;
                              mail = value;
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
                            hintText: '?????????????????????????????????',
                            hintStyle: TextStyle(
                              color: Colors.grey.withOpacity(0.6),
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                            errorText: isEditingMail ? globals.validateEmail(mail) : null,
                            errorStyle: TextStyle(
                              fontSize: 12,
                              color: Colors.redAccent,
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

  Future<int> sendMailToMember(String mail) async {
    String name = await globals.storage.read(key: "fullName");
    String sess = await globals.storage.read(key: "session");
    String session = Uri.encodeQueryComponent(sess);
    String body = "<!DOCTYPE html>\n"+
        '<html lang="jp-JP">\n'+
        "<head><title>????????????????????????</title></head>\n"+
        "<body>\n"+
        "<b>"+ name + " ???</b><br />\n"+
        "<br />\n"+
        _adminName + " ????????????janusmobile3????????????????????????????????????????????????<br />\n"+
        "???????????????????????????????????????<br />\n"+
        "<br />\n"+
        '<a href="https://room.yourcompany.com/janusmobile/hand_over_admin.php?session='+session+'&mail='+Uri.encodeQueryComponent(mail)+'&allow=yes">??????</a>\n'+
        '<a href="https://room.yourcompany.com/janusmobile/hand_over_admin.php?session='+session+'&mail='+Uri.encodeQueryComponent(mail)+'&allow=no">??????</a><br />\n'+
        "</body>\n"+
        "</html>\n";
    final Email email = Email(
      body: body,
      subject: "BizAcces3???????????????????????????",
      recipients: [mail],
      isHTML: true,
    );

    int returnVal = 0;
    String platformResponse;

    try {
      await FlutterEmailSender.send(email);
      platformResponse = '??????????????????????????????';
      returnVal = 1;
    } catch (error) {
      platformResponse = error.toString();
    }

    if (mounted) {
      showSnackBar(returnVal==0, platformResponse);
    }
    return returnVal;
  }

  showSnackBar(bool bError, String mess) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mess),
        backgroundColor: bError?Colors.redAccent:Colors.blueAccent,
        duration: Duration(seconds: 3, milliseconds: 500),
      ),
    );
  }
}
