import 'package:flutter/material.dart';
//import 'package:flutter_chat/chatData.dart';
//import 'package:flutter_chat/chatWidget.dart';

import 'chat/ui/chats_screen.dart';
import 'globals.dart' as globals;

class MessagePage extends StatefulWidget {
  MessagePage({Key key}) : super(key: key);
  static const String id = "welcome_screen";
  @override
  _MessagePageState createState() => new _MessagePageState();
}

class _MessagePageState extends State<MessagePage> {

  @override
  void initState() {
    globals.readLoginInfo(/*context*/).then((value) {
      if (!value) {
        Navigator.of(context).pushNamed('/login');
      }
    });
    super.initState();
    //ChatData.init("Just Chat",context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: ChatsScreen(),
    );
    /*
    return Scaffold(
        appBar: ChatWidget.getAppBar(),
        backgroundColor: Colors.white,
        body: ChatWidget.widgetWelcomeScreen(context));
     */
    /*
    return new Scaffold(
      body: Center(
        child: Text(
          "message",
          style: TextStyle(
            fontSize: Theme.of(context).textTheme.caption.fontSize,
            color: Theme.of(context).textTheme.caption.color,
          ),
        ),
      ),
    );
     */
  }
}
