library janus_mobile.globals;

import 'dart:convert' show json;

import 'package:http/http.dart' as http;
//import 'package:dio/dio.dart' as dio;
//import 'package:html/parser.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class GroupModel {
  final int id;
  String name;
  int seq;

  GroupModel({
    @required this.id,
    @required this.name,
    @required this.seq,
  });
}

final String twitterConsumerApiKey = 'YOUR_CONSUMER_API_KEY';
final String twitterConsumerApiSecret = 'YOUR_CONSUMER_API_SECRET';
final String kAdminChanged = 'AdminChanged';
final String kJoinedSuccess = 'JoinedSuccess';

final storage = new FlutterSecureStorage();

Future<bool> readLoginInfo(/*BuildContext context*/) async {
  String loginType = await storage.read(key: "loginType");
  String userID = await storage.read(key: "userID");
  //String snsID = await storage.read(key: "snsID");
  String session = await storage.read(key: "session");
  String token = await storage.read(key: "token");
  String secret = await storage.read(key: "secret");

  if (userID == null || userID == "" ||
      loginType == null || loginType == "" ||
      session == null || session == "") {
    //Navigator.push(
    //    context,
    //    MaterialPageRoute(builder: (context) => MyLoginPage(title: loginTitle)));
    //Navigator.of(context).pushNamed('/login');
    return false;
  } else {
    final uri = 'https://room.yourcompany.com/janusmobile/check_login.php';
    var map = new Map<String, dynamic>();
    map['type'] = loginType;
    map['token'] = token!=null?token:'';
    map['secret'] = secret!=null?secret:'';
    map['session'] = session;
    http.Response response = await http.post(Uri.parse(uri), body: map);

    print(response.body);
    if (response.statusCode != 200) {
      print("Failed to connect to server");
      //Navigator.push(
      //    context,
      //    MaterialPageRoute(builder: (context) => MyLoginPage(title: loginTitle)));
      //Navigator.of(context).pushNamed('/login');
      return false;
    }
    if (response.contentLength > 0) {
      final bodyMap = json.decode(response.body);
      if (bodyMap['result'] != 0) {
        print(bodyMap['result_string']);
        //Navigator.push(
        //    context,
        //    MaterialPageRoute(builder: (context) => MyLoginPage(title: loginTitle)));
        //Navigator.of(context).pushReplacementNamed('/login');
        return false;
      }
    } else {
      return false;
    }
  }
  return true;
}

Future<int> showPopupDialog({@required BuildContext context, String title, String content, String cancel, String submit}) async {
  return await showDialog<int>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: <Widget>[
          if(cancel!=null && cancel!='') TextButton(
            child: Text(cancel),
            onPressed: () => Navigator.of(context).pop(0),
          ),
          if(submit!=null && submit!='') TextButton(
            child: Text(submit),
            onPressed: () => Navigator.of(context).pop(1),
          ),
        ],
      );
    },
  );
}

Future<Map<String, String>> getGroupMap(BuildContext context) async {
  String companyId = await storage.read(key: "companyID");
  if (companyId != null && companyId.isNotEmpty) {
    Map<String, String> groupsReturn = {};
    String sess = await storage.read(key: "session");
    String session = Uri.encodeQueryComponent(sess);
    var uri = "https://room.yourcompany.com/janusmobile/group_list.php?token=" +
        session + "&company=" + companyId;
    http.Response response = await http.get(Uri.parse(uri));
    if (response.statusCode != 200) {
      await showPopupDialog(context: context, title: "エラー", content: "サイトにアクセスできません", cancel: "閉じる");
      return null;
    }
    var groups = json.decode(response.body);
    if (groups['result'] != 0) {
      print(groups['result_string']);
      await showPopupDialog(context: context, title: "エラー", content: groups['result_string'], cancel: "閉じる");
      return null;
    }
    var mt = groups['groups'];
    for (int i = 0; i < mt.length; ++i) {
      var group = mt[i] as Map<String, dynamic>;
      var id = group['group_id'];
      var name = group['group_name'];
      if (name != null) {
        groupsReturn[id.toString()] = name;
      }
    }
    return groupsReturn;
  }
  return null;
}

Future<List<GroupModel>> getGroupList(BuildContext context) async {
  String companyId = await storage.read(key: "companyID");
  if (companyId != null && companyId.isNotEmpty) {
    List<GroupModel> groupsReturn = [];
    String sess = await storage.read(key: "session");
    String session = Uri.encodeQueryComponent(sess);
    var uri = "https://room.yourcompany.com/janusmobile/group_list.php?token=" +
        session + "&company=" + companyId;
    http.Response response = await http.get(Uri.parse(uri));
    if (response.statusCode != 200) {
      await showPopupDialog(context: context, title: "エラー", content: "サイトにアクセスできません", cancel: "閉じる");
      return null;
    }
    var groups = json.decode(response.body);
    if (groups['result'] != 0) {
      print(groups['result_string']);
      await showPopupDialog(context: context, title: "エラー", content: groups['result_string'], cancel: "閉じる");
      return null;
    }
    var mt = groups['groups'];
    for (int i = 0; i < mt.length; ++i) {
      var group = mt[i] as Map<String, dynamic>;
      var id = group['group_id'];
      var name = group['group_name'];
      var seq = group['group_seq'];
      var model = GroupModel(id: id, name: name, seq: seq);
      if (name != null) {
        groupsReturn.add(model);
      }
    }
    return groupsReturn;
  }
  return null;
}

String validateEmail(String value) {
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
