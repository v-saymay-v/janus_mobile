import 'dart:convert' show json;
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
//import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:janus_mobile/meeting/models/event_info.dart';
import 'package:janus_mobile/meeting/utils/recurrence.dart';
import '../../globals.dart' as globals;

//final CollectionReference mainCollection = FirebaseFirestore.instance.collection('event');
//final DocumentReference documentReference = mainCollection.doc('test');

class Storage {
  final BuildContext context;
  List<Map<String,dynamic>> _meetings;
  Storage({@required this.context});

  get lastMeetings => _meetings;

  Future<void> storeEventData(EventInfo eventInfo) async {
    var map = eventInfo.toJson();

    String key = await globals.storage.read(key: "session");
    //String session = Uri.encodeQueryComponent(key);
    Map<String, String> headers = {"Cookie": "room_access_key="+key};
    final uri = "https://room.yourcompany.com/janusmobile/new_schedule.php";
    http.Response response = await http.post(Uri.parse(uri), body: map, headers: headers);
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
    _meetings = [];
    for (final mt in meetings['meetings']) {
      _meetings.add(mt);
    }
    /*
    DocumentReference documentReferencer = documentReference.collection('events').doc(eventInfo.id);

    Map<String, dynamic> data = eventInfo.toJson();

    print('DATA:\n$data');

    await documentReferencer.set(data).whenComplete(() {
      print("Event added to the database, id: {${eventInfo.id}}");
    }).catchError((e) => print(e));
     */
  }

  Future<void> updateEventData(EventInfo eventInfo) async {
    var map = eventInfo.toJson();

    String key = await globals.storage.read(key: "session");
    //String session = Uri.encodeQueryComponent(key);
    Map<String, String> headers = {"Cookie": "room_access_key="+key};
    final uri = "https://room.yourcompany.com/janusmobile/new_schedule.php";
    http.Response response = await http.post(Uri.parse(uri), body: map, headers: headers);
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
    _meetings = [];
    for (final mt in meetings['meetings']) {
      _meetings.add(mt);
    }
    /*
    DocumentReference documentReferencer = documentReference.collection('events').doc(eventInfo.id);

    Map<String, dynamic> data = eventInfo.toJson();

    print('DATA:\n$data');

    await documentReferencer.update(data).whenComplete(() {
      print("Event updated in the database, id: {${eventInfo.id}}");
    }).catchError((e) => print(e));
     */
  }

  Future<void> deleteEvent({@required String id, String option, String date, String subject, String mailBody}) async {
    var map = new Map<String, dynamic>();
    map['id'] = id;
    map['command'] = 'delete';
    map['option'] = option!=null&&option.isNotEmpty?option:"all";
    map['date'] = date!=null&&date.isNotEmpty?date:'';
    if (subject != null && subject.isNotEmpty && mailBody != null && mailBody.isNotEmpty) {
      map['sendMail'] = 'true';
      map['subject'] = subject;
      map['mailBody'] = mailBody;
    } else {
      map['sendMail'] = 'false';
    }

    String key = await globals.storage.read(key: "session");
    Map<String, String> headers = {"Cookie": "room_access_key="+key};
    final uri = "https://room.yourcompany.com/janusmobile/meetingHandle.php";
    http.Response response = await http.post(Uri.parse(uri), body: map, headers: headers);
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
    /*
    DocumentReference documentReferencer = documentReference.collection('events').doc(id);

    await documentReferencer.delete().catchError((e) => print(e));

    print('Event deleted, id: $id');
     */
  }

  /*
  Stream<QuerySnapshot> retrieveEvents() {
    Stream<QuerySnapshot> myClasses = documentReference.collection('events').orderBy('start').snapshots();

    return myClasses;
  }
   */

  retrieveEvents() async* {
    String meetingType = await globals.storage.read(key: "loginType");
    String sess = await globals.storage.read(key: "session");
    String session = Uri.encodeQueryComponent(sess);
    final uri = "https://room.yourcompany.com/janusmobile/meeting_list.php?token=" +
        session + "&type=" + meetingType;
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
    var mt = meetings['meetings'];
    for (int i = 0; i < mt.length; ++i) {
      var meeting = mt[i] as Map<String, dynamic>;
      /*
      var minutes = meeting['duration'] as int;
      var hours = (minutes/60).floor();
      var hourstr = hours>0?hours.toString()+'時間':'';
      var minstr = (minutes%60)>0?(minutes%60).toString()+'分':'';
      var durstr = hourstr + minstr;
      meeting['durstr'] = durstr;
       */
      yield meeting;
    }
  }
}
