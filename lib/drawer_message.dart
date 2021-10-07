import 'dart:convert' show json;
import 'dart:convert' show utf8;

import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

import 'chat/models/chat.dart';
import 'chat/models/chat_user.dart';
import 'chat/ui/chat_viewmodel.dart';
import 'chat/ui/chat_screen.dart';
import 'globals.dart' as globals;

class MessageDrawer extends StatefulWidget {
  MessageDrawer({Key key, this.model, this.addChatMessage}) : super(key: key);

  final ChatViewModel model;
  final Function (ChatWithMembers chat) addChatMessage;

  @override
  MessageDrawerState createState() => new MessageDrawerState();
}

class MessageDrawerState extends State<MessageDrawer> {
  List<Widget> children = [
    DrawerHeader(
      child: Text(
        'メンバー追加',
        style: TextStyle(
          fontSize: 24,
          color: Colors.white,
        ),
      ),
      decoration: BoxDecoration(
        color: Colors.blue,
      ),
    ),
  ];

  @override
  void initState() {
    getUsers();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        children: children,
      ),
    );
  }

  getUsers() async {
    String type = await globals.storage.read(key: "loginType");
    String token = await globals.storage.read(key: "token");
    String snsid = await globals.storage.read(key: "snsID");
    String photo = await globals.storage.read(key: "photo");
    String myName = await globals.storage.read(key: "fullname");

    List<Widget> children = [
      DrawerHeader(
        child: Text(
          'メンバー追加',
          style: TextStyle(
            fontSize: 24,
            color: Colors.white,
          ),
        ),
        decoration: BoxDecoration(
          color: Colors.blue,
        ),
      ),
    ];
  }

  Future<ChatUser>addNewUser(Map<String, dynamic> user) async {
    var userid = user['userid'].toString();
    var groupid = user["groupid"].toString();
    var name = user["name"];
    String unread = user["unread"];
    var url = user["url"];
    var chatUser = ChatUser(
        id: userid != "" ? "user_" + userid : "group_" + groupid,
        user: userid,
        group: groupid,
        username: name,
        avatarURL: url,
        lastPost: null,
        unRead: int.parse(unread));
    await widget.model.sqlite3.insert(
      'bt_user',
      chatUser.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    widget.model.chatUsers.add(chatUser);
    return chatUser;
  }
}
