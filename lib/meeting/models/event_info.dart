import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:janus_mobile/meeting/utils/recurrence.dart';

class EventInfo {
  final String id;
  String googleId;
  final String name;
  final String description;
  final String location;
  final String meetingType;
  String link;
  final List<Map<String, dynamic>> attendeeInfo;
  //final List<dynamic> attendeeIds;
  //final List<dynamic> attendeeEmails;
  final bool shouldNotifyAttendees;
  final bool hasConfereningSupport;
  final int startTimeInEpoch;
  final int endTimeInEpoch;
  final Recurrence recurrence;
  final bool usePersonalMeetingId;
  final bool useMeetingPass;
  final String meetingPass;
  final bool videoHostOn;
  final bool videoAttendeeOn;
  final bool muteUponEntry;
  final bool autoRecordLocal;

  EventInfo({
    this.id,
    this.googleId,
    @required this.name,
    @required this.description,
    @required this.location,
    @required this.meetingType,
    this.link,
    //@required this.attendeeIds,
    //@required this.attendeeEmails,
    @required this.attendeeInfo,
    @required this.shouldNotifyAttendees,
    @required this.hasConfereningSupport,
    @required this.startTimeInEpoch,
    @required this.endTimeInEpoch,
    @required this.recurrence,
    this.usePersonalMeetingId=false,
    this.useMeetingPass=true,
    this.meetingPass,
    this.videoHostOn=true,
    this.videoAttendeeOn=true,
    this.muteUponEntry=false,
    this.autoRecordLocal=false,
  });

  set setGoogleId(value) => googleId=value;
  set setLink(value) => link=value;

  static int startTime(Map snapshot) {
    DateTime dtm = DateTime.parse(snapshot['date_time']);
    String ampm = snapshot['ampm'];
    //if (ampm == 'PM') {
    //  dtm = dtm.add(Duration(hours: 12));
    //}
    return dtm.millisecondsSinceEpoch;
  }

  static int endTime(Map snapshot) {
    int stm = startTime(snapshot);
    int duration = snapshot['duration'];
    return stm+duration*60*1000;
  }

  static List<Map<String,dynamic>>convUsers(List<dynamic> before) {
    List<Map<String,dynamic>> users = [];
    for (var u in before) {
      Map<String,dynamic> user = {};
      user['userid'] = u['userid'];
      user['username'] = u['username'];
      user['email'] = u['email'];
      user['isguest'] = u['isguest'];
      users.add(user);
    }
    return users;
  }

  EventInfo.fromMap(Map snapshot):
    id = snapshot['meeting_no'] ?? '',
    googleId = snapshot['google_id'] ?? '',
    name = snapshot['title'] ?? '',
    description = snapshot['memo'],
    location = snapshot['loc'] ?? '',
    meetingType = snapshot['meeting_type'] ?? 'previous',
    link = snapshot['link'] ?? '',
    //attendeeIds = snapshot['room_users'] ?? [],
    //attendeeEmails = snapshot['room_mails'] ?? [],
    attendeeInfo = snapshot['attendees']!=null?convUsers(snapshot['attendees']):[],
    shouldNotifyAttendees = snapshot['should_notify'] ?? true,
    hasConfereningSupport = snapshot['has_conferencing'] ?? false,
    startTimeInEpoch = startTime(snapshot),
    endTimeInEpoch = endTime(snapshot),
    recurrence = Recurrence.fromMap(snapshot),
    usePersonalMeetingId = snapshot['schedule_with_pmi']=='on',
    useMeetingPass = snapshot['which_pass']=='meeting',
    meetingPass = snapshot['meeting_pass'],
    videoHostOn = snapshot['video_host']>0,
    videoAttendeeOn = snapshot['video_participants']>0,
    muteUponEntry = snapshot['mute_upon_entry']>0,
    autoRecordLocal = snapshot['autorec_local']>0;

  Map<String, dynamic> toJson() {
    List<dynamic> ids = [];
    for (var attendee in attendeeInfo) {
      ids.add(attendee['userid']);
    }
    Map<String, dynamic> map = {
      //'id': id,
      'meeting_no': id ?? '',
      'google_id': googleId ?? '',
      //'name': name,
      'title': name,
      //'desc': description,
      'memo': description,
      'loc': location ?? '',
      'meeting_type': meetingType ?? 'previous',
      'link': link ?? '',
      //'emails': attendeeEmails,
      //'room_users[]': attendeeIds.toString(),
      //'room_mails[]': attendeeEmails.toString(),
      'attendees': attendeeInfo.toString(),
      'room_users[]': ids.toString(),
      'should_notify': shouldNotifyAttendees?'1':'0',
      'has_conferencing': hasConfereningSupport?'1':'0',
      //'start': startTimeInEpoch,
      //'end': endTimeInEpoch,
      'schedule_with_pmi': usePersonalMeetingId?'on':'off',
      'which_pass': useMeetingPass?'meeting':'login',
      'meeting_pass': meetingPass,
      'video_host': videoHostOn?'1':'0',
      'video_participants': videoAttendeeOn?'1':'0',
      'mute_upon_entry': muteUponEntry?'1':'0',
      'autorec_local': autoRecordLocal?'1':'0',
      'from_mobile': '1',
    };
    var start = DateTime.fromMillisecondsSinceEpoch(startTimeInEpoch);
    map['ampm'] = start.hour>=12?'PM':'AM';
    map['duration'] = ((endTimeInEpoch-startTimeInEpoch)/1000/60).toString();
    if (map['ampm'] == 'PM') {
      start = start.subtract(Duration(hours: 12));
    }
    var formatter = new DateFormat('yyyy-MM-dd HH:mm:ss', "ja_JP");
    map['date_time'] = formatter.format(start);
    /*
        start.year.toString()+'-'
      +(start.month<10?'0'+start.month.toString():start.month.toString())+'-'
      +(start.day<10?'0'+start.day.toString():start.day.toString())+' '
      +(start.hour<10?'0'+start.hour.toString():start.hour.toString())+':'
      +(start.minute<10?'0'+start.minute.toString():start.minute.toString())+':'
      +(start.second<10?'0'+start.second.toString():start.second.toString()); //'1971-01-01 00:00:00';
     */
    return recurrence.addToMap(map);
  }
}
