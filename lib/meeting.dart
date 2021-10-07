import 'dart:async';
import 'dart:convert' show json;

import 'package:janus_mobile/drawer.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_facebook_login/flutter_facebook_login.dart';
import 'package:flutter_twitter/flutter_twitter.dart';
import "package:intl/intl.dart";

import 'globals.dart' as globals;
import "drawer.dart";
//import "VideoRoom.dart";
import "video_room.dart";
import "meeting/screens/create_screen.dart";
import "meeting/screens/edit_screen.dart";
import 'package:janus_mobile/meeting/models/event_info.dart';

class MeetingPage extends StatefulWidget {
  MeetingPage({Key key, this.googleSignIn, this.twitterLogin, this.facebookSignIn}) : super(key: key);

  final GoogleSignIn googleSignIn;
  final FacebookLogin facebookSignIn;
  final TwitterLogin twitterLogin;

  @override
  _MeetingPageState createState() => new _MeetingPageState();
}

class _MeetingPageState extends State<MeetingPage> with SingleTickerProviderStateMixin {
  final _formatter = new DateFormat('MM/dd(E) HH:mm', "ja_JP");
  final List<Tab> tabs = <Tab>[
    Tab(text: '開催待ち',),
    Tab(text: "開催終了",),
  ];
  TabController _tabController;
  String _meetingType = "next";
  String _fullname;
  List<Map<String, Object>> _meetings = []; //List<Map<String, Object>>();

  @override
  void initState() {
    globals.readLoginInfo(/*context*/).then((value) {
      if (!value) {
        Navigator.of(context).pushNamed('/login');
      }
    });
    super.initState();
    _tabController = TabController(length: tabs.length, vsync: this);
    _tabController.addListener(_handleTabSelection);
    readMeetingList();
  }

  _handleTabSelection() {
    if (_tabController.indexIsChanging) {
      if (_tabController.index > 0) {
        _meetingType = 'previous';
      } else {
        _meetingType = 'next';
      }
      readMeetingList();
    }
  }

  Future readMeetingList() async {
    String sess = await globals.storage.read(key: "session");
    if (sess != null) {
      String session = Uri.encodeQueryComponent(sess);
      final uri = "https://room.yourcompany.com/janusmobile/meeting_list.php?token=" +
          session + "&type=" + _meetingType;
      http.Response response = await http.get(Uri.parse(uri));
      if (response.statusCode != 200) {
        await globals.showPopupDialog(context: context, title: "エラー", content: "サイトにアクセスできません", cancel: "閉じる");
        return false;
      }
      final meetings = json.decode(response.body);
      if (meetings['result'] != 0) {
        print(meetings['result_string']);
        await globals.showPopupDialog(context: context, title: "エラー", content: meetings['result_string'], cancel: "閉じる");
        return;
      }
      var mt = meetings['meetings'];
      setState(() {
        _meetings.clear();
        for (int i = 0; i < mt.length; ++i) {
          var meeting = mt[i] as Map<String, dynamic>;
          var minutes = meeting['duration'] as int;
          var hours = (minutes/60).floor();
          var hourstr = hours>0?hours.toString()+'時間':'';
          var minstr = (minutes%60)>0?(minutes%60).toString()+'分':'';
          var durstr = hourstr + minstr;
          meeting['durstr'] = durstr;
          _meetings.add(meeting);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return new Scaffold(
      appBar: AppBar(
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text("ミーティング"),
        actions: <Widget>[
          IconButton(
            icon: Icon(Icons.add),
            onPressed: () {
              addNewMapToList();
            },
          ),
        ],
        bottom: TabBar(
          tabs: tabs,
          controller: _tabController,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.blue,
          indicatorSize: TabBarIndicatorSize.tab,
          indicatorWeight: 2,
          indicatorPadding: EdgeInsets.symmetric(horizontal: 18.0,
              vertical: 8),
          labelColor: Colors.white,
        ),
      ),
      drawer: MyDrawer(googleSignIn: widget.googleSignIn, twitterLogin:widget.twitterLogin, facebookSignIn:widget.facebookSignIn),
      body: TabBarView(
        controller: _tabController,
        children: <Widget>[
          _firstTab(),
          _secondTab(),
        ],
      ),
    );
  }

  Widget _firstTab() {
    return RefreshIndicator(
      onRefresh: () async {
        print('Loading New Data');
        readMeetingList();
      },
      child: ListView.builder(
        itemBuilder: (BuildContext context, int index) => ExpansionTile(
          title: Text(_meetings[index]['title']),
          subtitle: Text(_formatter.format(DateTime.parse(_meetings[index]['start']))+' から'+_meetings[index]['durstr']),
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: <Widget>[
                  Text("ホスト："+_meetings[index]['host']),
                  ElevatedButton(
                    child: Text("編集"),
                    onPressed: () {
                      readMeetingDetail(_meetings[index]['meeting']);
                    },
                  ),
                  ElevatedButton(
                    child: Text("参加"),
                    onPressed: () {
                      Navigator.push(
                          context,
                          //MaterialPageRoute(builder: (context) => VideoRoom(roomno:int.parse(_meetings[index]['meeting']), displayname:_fullname)));
                          MaterialPageRoute(builder: (context) => JanusVideoRoom(myRoom:_meetings[index]['meeting'], userName:_fullname)));
                    }
                  ),
                  ElevatedButton(
                    child: Text("終了"),
                    onPressed: () {
                    },
                  ),
                ]
              )
            )
          ],
        ),
        itemCount: _meetings.length,
      )
    );
  }

  Widget _secondTab() {
    return RefreshIndicator(
      onRefresh: () async {
        print('Loading New Data');
        readMeetingList();
      },
      child: ListView.builder(
        itemBuilder: (BuildContext context, int index) => ExpansionTile(
          title: Text(_meetings[index]['title']),
          subtitle: Text(_formatter.format(DateTime.parse(_meetings[index]['start']))),
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: <Widget>[
                  Text("ホスト："+_meetings[index]['host']),
                  ElevatedButton(
                    child: Text("削除"),
                    onPressed: () {
                    },
                  ),
                ]
              )
            )
          ],
        ),
        itemCount: _meetings.length,
      )
    );
  }

  addNewMapToList() async {
    List<Map<String,dynamic>> map = await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => CreateScreen(meetingType: _meetingType)));
    //addMapToList(map);
    if (map != null) {
      setState(() {
        _meetings.clear();
        for (int i = 0; i < map.length; ++i) {
          var meeting = map[i];
          var minutes = meeting['duration'] as int;
          var hours = (minutes / 60).floor();
          var hourstr = hours > 0 ? hours.toString() + '時間' : '';
          var minstr = (minutes % 60) > 0
              ? (minutes % 60).toString() + '分'
              : '';
          var durstr = hourstr + minstr;
          meeting['durstr'] = durstr;
          _meetings.add(meeting);
        }
      });
    }
  }

  Future readMeetingDetail(String meeting) async {
    String sess = await globals.storage.read(key: "session");
    if (sess != null) {
      String session = Uri.encodeQueryComponent(sess);
      final uri = "https://room.yourcompany.com/janusmobile/meeting_detail.php?token=" +
          session + "&type=" + _meetingType + "&meeting=" + meeting;
      http.Response response = await http.get(Uri.parse(uri));
      if (response.statusCode != 200) {
        await globals.showPopupDialog(context: context, title: "エラー", content: "サイトにアクセスできません", cancel: "閉じる");
        return false;
      }
      final meetings = json.decode(response.body);
      if (meetings['result'] != 0) {
        print(meetings['result_string']);
        await globals.showPopupDialog(context: context, title: "エラー", content: meetings['result_string'], cancel: "閉じる");
        return;
      }
      var mt = meetings['meeting'];
      mt['meeting_type'] = _meetingType;
      List<Map<String, dynamic>> map = await Navigator.push(context,
          MaterialPageRoute(builder: (context) => EditScreen(event: EventInfo.fromMap(mt))));
      //addMapToList(map);
      if (map != null) {
        setState(() {
          _meetings.clear();
          for (int i = 0; i < map.length; ++i) {
            var meeting = map[i];
            var minutes = meeting['duration'] as int;
            var hours = (minutes / 60).floor();
            var hourstr = hours > 0 ? hours.toString() + '時間' : '';
            var minstr = (minutes % 60) > 0
                ? (minutes % 60).toString() + '分'
                : '';
            var durstr = hourstr + minstr;
            meeting['durstr'] = durstr;
            _meetings.add(meeting);
          }
        });
      }
    }
  }
}
