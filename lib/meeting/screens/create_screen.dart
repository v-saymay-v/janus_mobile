import 'dart:convert' show json;

import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:random_string/random_string.dart';
import 'package:googleapis/calendar/v3.dart' as calendar;
import 'package:intl/intl.dart';

import 'package:janus_mobile/meeting/models/event_info.dart';
import 'package:janus_mobile/meeting/resources/color.dart';
import 'package:janus_mobile/meeting/utils/calendar_client.dart';
import 'package:janus_mobile/meeting/utils/storage.dart';
import 'package:janus_mobile/meeting/utils/recurrence.dart';
import 'package:janus_mobile/globals.dart' as globals;

class CreateScreen extends StatefulWidget {
  final String meetingType;
  CreateScreen({@required this.meetingType});
  @override
  _CreateScreenState createState() => _CreateScreenState();
}

class _CreateScreenState extends State<CreateScreen> {
  Storage storage;
  CalendarClient calendarClient = CalendarClient();

  TextEditingController textControllerDate;
  TextEditingController textControllerEndDate;
  TextEditingController textControllerStartTime;
  TextEditingController textControllerEndTime;
  TextEditingController textControllerTitle;
  TextEditingController textControllerDesc;
  TextEditingController textControllerLocation;
  TextEditingController textControllerAttendee;
  TextEditingController textControllerPassword;

  FocusNode textFocusNodeTitle;
  FocusNode textFocusNodeDesc;
  FocusNode textFocusNodeLocation;
  FocusNode textFocusNodeAttendee;

  static List<String> dayNames = ['月曜日', '火曜日', '水曜日', '木曜日', '金曜日', '土曜日', '日曜日'];
  static List<String> engNames = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];

  DateTime selectedDate = DateTime.now();
  DateTime selectedTermDate = DateTime.now();
  TimeOfDay selectedStartTime = TimeOfDay.now();
  TimeOfDay selectedEndTime = TimeOfDay.now();

  String currentTitle;
  String currentDesc;
  String currentLocation;
  String currentEmail;
  String meetingType;
  String errorString = '';
  String dropdownValue = '毎日';
  String endCondition = '期限';
  String monthlyBy = '毎月';
  String monthlyWeekDay = dayNames[DateTime.now().weekday-1];
  String meetingId = '自動的';
  String needMeetingPass = '必要';
  String meetingPassword;

  int endTimes = 1;
  int dailyInterval = 1;
  int weeklyInterval = 1;
  int monthlyInterval = 1;
  int monthlyDay = DateTime.now().day;
  int monthlyWeekIndex = _getWeekIndex();

  bool flagMonday = DateTime.now().weekday==1;
  bool flagTuesday = DateTime.now().weekday==2;
  bool flagWednesday = DateTime.now().weekday==3;
  bool flagThursday = DateTime.now().weekday==4;
  bool flagFriday = DateTime.now().weekday==5;
  bool flagSaturday = DateTime.now().weekday==6;
  bool flagSunday = DateTime.now().weekday==7;
  bool videoHostOn = true;
  bool videoAttendeeOn = true;
  bool notMuteUponEntry = false;
  bool autoRecordLocal = false;
  bool isRepeat = false;
  bool addToGoogleCalendar = false;

  // List<String> attendeeEmails = [];
  List<calendar.EventAttendee> attendeeEmails = [];

  bool isEditingDate = false;
  bool isEditingStartTime = false;
  bool isEditingEndTime = false;
  bool isEditingBatch = false;
  bool isEditingTitle = false;
  bool isEditingEmail = false;
  bool isEditingLink = false;
  bool isErrorTime = false;
  bool shouldNofityAttendees = false;
  //bool hasConferenceSupport = false;
  bool isDataStorageInProgress = false;

  static int _getWeekIndex() {
    int weekday = DateTime.now().weekday;
    int today = DateTime.now().day;
    int year = DateTime.now().year;
    int month = DateTime.now().month;
    var current = DateTime(year, month, 1);
    var week = 1;
    while (current.day != today) {
      if (current.weekday == weekday) {
        ++week;
      }
      current = current.add(Duration(days: 1));
    }
    return week;
  }

  _selectDate(BuildContext context) async {
    final DateTime picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2050),
    );
    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = picked;
        textControllerDate.text = DateFormat.yMMMMd().format(selectedDate);
      });
    }
  }

  _selectEndDate(BuildContext context) async {
    final DateTime picked = await showDatePicker(
      context: context,
      initialDate: selectedTermDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2050),
    );
    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedTermDate = picked;
        textControllerEndDate.text = DateFormat.yMMMMd().format(selectedTermDate);
      });
    }
  }

  _selectStartTime(BuildContext context) async {
    if (textControllerStartTime.text.isEmpty)
      selectedStartTime = TimeOfDay.now();
    final TimeOfDay picked = await showTimePicker(
      context: context,
      initialTime: selectedStartTime,
    );
    if (picked != null && picked != selectedStartTime) {
      setState(() {
        selectedStartTime = picked;
        textControllerStartTime.text = selectedStartTime.format(context);
      });
    } else if (picked != null) {
      setState(() {
        textControllerStartTime.text = selectedStartTime.format(context);
      });
    }
  }

  _selectEndTime(BuildContext context) async {
    if (textControllerEndTime.text.isEmpty) {
      var now = DateTime.now();
      selectedEndTime = TimeOfDay.fromDateTime(now.add(const Duration(hours: 1)));
    }
    final TimeOfDay picked = await showTimePicker(
      context: context,
      initialTime: selectedEndTime,
    );
    if (picked != null && picked != selectedEndTime) {
      setState(() {
        selectedEndTime = picked;
        textControllerEndTime.text = selectedEndTime.format(context);
      });
    } else if (picked != null) {
      setState(() {
        textControllerEndTime.text = selectedEndTime.format(context);
      });
    }
  }

  String _validateTitle(String value) {
    if (value != null) {
      value = value?.trim();
      if (value.isEmpty) {
        return 'Title can\'t be empty';
      }
    } else {
      return 'Title can\'t be empty';
    }
    return null;
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

  _addMeToAttendee() async {
    var id = await globals.storage.read(key: "userID");
    var email = await globals.storage.read(key: "email");
    var name = await globals.storage.read(key: "fullName");
    var attendee = calendar.EventAttendee();
    attendee.id = id;
    attendee.email = email;
    attendee.displayName = name;
    setState(() {
      attendeeEmails.add(attendee);
    });
  }

  @override
  void initState() {
    meetingType = widget.meetingType;
    storage = Storage(context: context);
    textControllerDate = TextEditingController();
    textControllerEndDate = TextEditingController();
    textControllerStartTime = TextEditingController();
    textControllerEndTime = TextEditingController();
    textControllerTitle = TextEditingController();
    textControllerDesc = TextEditingController();
    textControllerLocation = TextEditingController();
    textControllerAttendee = TextEditingController();
    textControllerPassword = TextEditingController();

    textFocusNodeTitle = FocusNode();
    textFocusNodeDesc = FocusNode();
    textFocusNodeLocation = FocusNode();
    textFocusNodeAttendee = FocusNode();

    _addMeToAttendee();
    setState(() {
      meetingPassword = randomAlpha(8);
      textControllerPassword.text = meetingPassword;
    });

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    Color getColor(Set<MaterialState> states) {
      const Set<MaterialState> interactiveStates = <MaterialState>{
        MaterialState.pressed,
        MaterialState.hovered,
        MaterialState.focused,
      };
      if (states.any(interactiveStates.contains)) {
        return Colors.blue;
      }
      return Colors.red;
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        iconTheme: IconThemeData(
          color: Colors.grey, //change your color here
        ),
        title: Text(
          'ミーティング追加',
          style: TextStyle(
            color: CustomColor.dark_blue,
            fontSize: 22,
          ),
        ),
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
                    Text(
                      '新しいミーティングを追加します',
                      style: TextStyle(
                        color: Colors.black87,
                        fontFamily: 'Raleway',
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    /*
                    SizedBox(height: 10),
                    Text(
                      'You will have access to modify or remove the event afterwards.',
                      style: TextStyle(
                        color: Colors.grey,
                        fontFamily: 'Raleway',
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                     */
                    SizedBox(height: 10),
                    RichText(
                      text: TextSpan(
                        text: 'トピック',
                        style: TextStyle(
                          color: CustomColor.dark_cyan,
                          fontFamily: 'Raleway',
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                        children: <TextSpan>[
                          TextSpan(
                            text: '*',
                            style: TextStyle(
                              color: Colors.red,
                              fontSize: 28,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 10),
                    TextField(
                      enabled: true,
                      cursorColor: CustomColor.sea_blue,
                      focusNode: textFocusNodeTitle,
                      controller: textControllerTitle,
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.next,
                      keyboardType: TextInputType.text,
                      onChanged: (value) {
                        setState(() {
                          isEditingTitle = true;
                          currentTitle = value;
                        });
                      },
                      onSubmitted: (value) {
                        textFocusNodeTitle.unfocus();
                        FocusScope.of(context).requestFocus(textFocusNodeDesc);
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
                          borderSide: BorderSide(color: CustomColor.sea_blue, width: 1),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(10.0)),
                          borderSide: BorderSide(color: CustomColor.dark_blue, width: 2),
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
                        hintText: '例: 営業部ビデオ会議',
                        hintStyle: TextStyle(
                          color: Colors.grey.withOpacity(0.6),
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                        errorText: isEditingTitle ? _validateTitle(currentTitle) : null,
                        errorStyle: TextStyle(
                          fontSize: 12,
                          color: Colors.redAccent,
                        ),
                      ),
                    ),
                    SizedBox(height: 10),
                    RichText(
                      text: TextSpan(
                        text: '説明（任意）',
                        style: TextStyle(
                          color: CustomColor.dark_cyan,
                          fontFamily: 'Raleway',
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                        children: <TextSpan>[
                          TextSpan(
                            text: ' ',
                            style: TextStyle(
                              color: Colors.red,
                              fontSize: 28,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 10),
                    TextField(
                      enabled: true,
                      maxLines: null,
                      cursorColor: CustomColor.sea_blue,
                      focusNode: textFocusNodeDesc,
                      controller: textControllerDesc,
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.next,
                      keyboardType: TextInputType.text,
                      onChanged: (value) {
                        setState(() {
                          currentDesc = value;
                        });
                      },
                      onSubmitted: (value) {
                        textFocusNodeDesc.unfocus();
                        FocusScope.of(context).requestFocus(textFocusNodeLocation);
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
                          borderSide: BorderSide(color: CustomColor.sea_blue, width: 1),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(10.0)),
                          borderSide: BorderSide(color: CustomColor.dark_blue, width: 2),
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
                        hintText: '例: 追加の情報があれば、書いてください',
                        hintStyle: TextStyle(
                          color: Colors.grey.withOpacity(0.6),
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Googleカレンダーに登録',
                          style: TextStyle(
                            color: CustomColor.dark_cyan,
                            fontFamily: 'Raleway',
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Switch(
                          value: addToGoogleCalendar,
                          onChanged: (value) {
                            setState(() {
                              addToGoogleCalendar = value;
                            });
                          },
                          activeColor: CustomColor.sea_blue,
                        ),
                      ],
                    ),
                    Visibility(
                      visible: addToGoogleCalendar,
                      child: SizedBox(height: 10),
                    ),
                    Visibility(
                      visible: addToGoogleCalendar,
                      child: RichText(
                        text: TextSpan(
                          text: '場所',
                          style: TextStyle(
                            color: CustomColor.dark_cyan,
                            fontFamily: 'Raleway',
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                          children: <TextSpan>[
                            TextSpan(
                              text: ' ',
                              style: TextStyle(
                                color: Colors.red,
                                fontSize: 28,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Visibility(
                      visible: addToGoogleCalendar,
                      child: SizedBox(height: 10),
                    ),
                    Visibility(
                      visible: addToGoogleCalendar,
                      child: TextField(
                        enabled: true,
                        cursorColor: CustomColor.sea_blue,
                        focusNode: textFocusNodeLocation,
                        controller: textControllerLocation,
                        textCapitalization: TextCapitalization.words,
                        textInputAction: TextInputAction.next,
                        keyboardType: TextInputType.text,
                        onChanged: (value) {
                          setState(() {
                            currentLocation = value;
                          });
                        },
                        onSubmitted: (value) {
                          textFocusNodeLocation.unfocus();
                          FocusScope.of(context).requestFocus(textFocusNodeAttendee);
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
                            borderSide: BorderSide(color: CustomColor.sea_blue, width: 1),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(10.0)),
                            borderSide: BorderSide(color: CustomColor.dark_blue, width: 2),
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
                          hintText: 'Place of the event',
                          hintStyle: TextStyle(
                            color: Colors.grey.withOpacity(0.6),
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 16.0),
                    RichText(
                      text: TextSpan(
                        text: '日付',
                        style: TextStyle(
                          color: CustomColor.dark_cyan,
                          fontFamily: 'Raleway',
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                        children: <TextSpan>[
                          TextSpan(
                            text: '*',
                            style: TextStyle(
                              color: Colors.red,
                              fontSize: 28,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 10),
                    TextField(
                      cursorColor: CustomColor.sea_blue,
                      controller: textControllerDate,
                      textCapitalization: TextCapitalization.characters,
                      keyboardType: TextInputType.datetime,
                      onTap: () => _selectDate(context),
                      readOnly: true,
                      style: TextStyle(
                        color: Colors.black87,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                      decoration: new InputDecoration(
                        disabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(10.0)),
                          borderSide: BorderSide(color: CustomColor.sea_blue, width: 1),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(10.0)),
                          borderSide: BorderSide(color: CustomColor.sea_blue, width: 1),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(10.0)),
                          borderSide: BorderSide(color: CustomColor.dark_blue, width: 2),
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
                        hintText: 'eg: September 10, 2020',
                        hintStyle: TextStyle(
                          color: Colors.grey.withOpacity(0.6),
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                        errorText: isEditingDate && textControllerDate.text != null
                            ? textControllerDate.text.isNotEmpty
                                ? null
                                : '日付の入力は必須です'
                            : null,
                        errorStyle: TextStyle(
                          fontSize: 12,
                          color: Colors.redAccent,
                        ),
                      ),
                    ),
                    SizedBox(height: 10),
                    RichText(
                      text: TextSpan(
                        text: '開始時刻',
                        style: TextStyle(
                          color: CustomColor.dark_cyan,
                          fontFamily: 'Raleway',
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                        children: <TextSpan>[
                          TextSpan(
                            text: '*',
                            style: TextStyle(
                              color: Colors.red,
                              fontSize: 28,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 10),
                    TextField(
                      cursorColor: CustomColor.sea_blue,
                      controller: textControllerStartTime,
                      keyboardType: TextInputType.datetime,
                      onTap: () => _selectStartTime(context),
                      readOnly: true,
                      style: TextStyle(
                        color: Colors.black87,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                      decoration: new InputDecoration(
                        disabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(10.0)),
                          borderSide: BorderSide(color: CustomColor.sea_blue, width: 1),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(10.0)),
                          borderSide: BorderSide(color: CustomColor.sea_blue, width: 1),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(10.0)),
                          borderSide: BorderSide(color: CustomColor.dark_blue, width: 2),
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
                        hintText: 'eg: 09:30 AM',
                        hintStyle: TextStyle(
                          color: Colors.grey.withOpacity(0.6),
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                        errorText: isEditingStartTime && textControllerStartTime.text != null
                            ? textControllerStartTime.text.isNotEmpty
                                ? null
                                : '開始時刻の入力は必須です'
                            : null,
                        errorStyle: TextStyle(
                          fontSize: 12,
                          color: Colors.redAccent,
                        ),
                      ),
                    ),
                    SizedBox(height: 10),
                    RichText(
                      text: TextSpan(
                        text: '終了時刻',
                        style: TextStyle(
                          color: CustomColor.dark_cyan,
                          fontFamily: 'Raleway',
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                        children: <TextSpan>[
                          TextSpan(
                            text: '*',
                            style: TextStyle(
                              color: Colors.red,
                              fontSize: 28,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 10),
                    TextField(
                      cursorColor: CustomColor.sea_blue,
                      controller: textControllerEndTime,
                      keyboardType: TextInputType.datetime,
                      onTap: () => _selectEndTime(context),
                      readOnly: true,
                      style: TextStyle(
                        color: Colors.black87,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                      decoration: new InputDecoration(
                        disabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(10.0)),
                          borderSide: BorderSide(color: CustomColor.sea_blue, width: 1),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(10.0)),
                          borderSide: BorderSide(color: CustomColor.sea_blue, width: 1),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(10.0)),
                          borderSide: BorderSide(color: CustomColor.dark_blue, width: 2),
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
                        hintText: 'eg: 11:30 AM',
                        hintStyle: TextStyle(
                          color: Colors.grey.withOpacity(0.6),
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                        errorText: isEditingEndTime && textControllerEndTime.text != null
                            ? textControllerEndTime.text.isNotEmpty
                                ? null
                                : '終了時刻の入力は必須です'
                            : null,
                        errorStyle: TextStyle(
                          fontSize: 12,
                          color: Colors.redAccent,
                        ),
                      ),
                    ),
                    SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '定期ミーティング',
                          style: TextStyle(
                            color: CustomColor.dark_cyan,
                            fontFamily: 'Raleway',
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Switch(
                          value: isRepeat,
                          onChanged: (value) {
                            setState(() {
                              isRepeat = value;
                            });
                          },
                          activeColor: CustomColor.sea_blue,
                        ),
                      ],
                    ),
                    Visibility(
                      visible: isRepeat,
                      child: SizedBox(height: 10),
                    ),
                    Visibility(
                      visible: isRepeat,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          RichText(
                            text: TextSpan(
                              text: '実施間隔',
                              style: TextStyle(
                                color: CustomColor.dark_cyan,
                                fontFamily: 'Raleway',
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                              ),
                              children: <TextSpan>[
                                TextSpan(
                                  text: ' ',
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontSize: 28,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          DropdownButton<String>(
                            value: dropdownValue,
                            icon: const Icon(Icons.arrow_downward, color: CustomColor.dark_cyan,),
                            iconSize: 24,
                            elevation: 16,
                            style: const TextStyle(color: CustomColor.dark_cyan),
                            underline: Container(
                              height: 2,
                              color: Colors.deepPurpleAccent,
                            ),
                            onChanged: (String newValue) {
                              setState(() {
                                dropdownValue = newValue;
                              });
                            },
                            items: <String>['毎日', '週ごと', '毎月']
                                .map<DropdownMenuItem<String>>((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(value),
                              );
                            }).toList(),
                          ),
                        ]
                      ),
                    ),
                    Visibility(
                      visible: isRepeat&&dropdownValue=='毎日',
                      child: SizedBox(height: 10),
                    ),
                    Visibility(
                      visible: isRepeat&&dropdownValue=='毎日',
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              RichText(
                                text: TextSpan(
                                  text: '次の頻度でリピート',
                                  style: TextStyle(
                                    color: CustomColor.dark_cyan,
                                    fontFamily: 'Raleway',
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ),
                              DropdownButton<int>(
                                value: dailyInterval,
                                icon: const Icon(Icons.arrow_downward, color: CustomColor.dark_cyan,),
                                iconSize: 24,
                                elevation: 16,
                                style: const TextStyle(color: CustomColor.dark_cyan),
                                underline: Container(
                                  height: 2,
                                  color: Colors.deepPurpleAccent,
                                ),
                                onChanged: (int newValue) {
                                  setState(() {
                                    dailyInterval = newValue;
                                  });
                                },
                                items: <int>[1, 2, 3, 4, 5, 6, 7]
                                    .map<DropdownMenuItem<int>>((int value) {
                                  return DropdownMenuItem<int>(
                                    value: value,
                                    child: Text(value.toString()),
                                  );
                                }).toList(),
                              ),
                              RichText(
                                text: TextSpan(
                                  text: '日',
                                  style: TextStyle(
                                    color: CustomColor.dark_cyan,
                                    fontFamily: 'Raleway',
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ),
                            ]
                          ),
                        ]
                      ),
                    ),
                    Visibility(
                      visible: isRepeat&&dropdownValue=='週ごと',
                      child: SizedBox(height: 10),
                    ),
                    Visibility(
                      visible: isRepeat&&dropdownValue=='週ごと',
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              RichText(
                                text: TextSpan(
                                  text: '次の頻度でリピート',
                                  style: TextStyle(
                                    color: CustomColor.dark_cyan,
                                    fontFamily: 'Raleway',
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ),
                              DropdownButton<int>(
                                value: weeklyInterval,
                                icon: const Icon(Icons.arrow_downward, color: CustomColor.dark_cyan,),
                                iconSize: 24,
                                elevation: 16,
                                style: const TextStyle(color: CustomColor.dark_cyan),
                                underline: Container(
                                  height: 2,
                                  color: Colors.deepPurpleAccent,
                                ),
                                onChanged: (int newValue) {
                                  setState(() {
                                    weeklyInterval = newValue;
                                  });
                                },
                                items: <int>[1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]
                                    .map<DropdownMenuItem<int>>((int value) {
                                  return DropdownMenuItem<int>(
                                    value: value,
                                    child: Text(value.toString()),
                                  );
                                }).toList(),
                              ),
                              RichText(
                                text: TextSpan(
                                  text: '週間',
                                  style: TextStyle(
                                    color: CustomColor.dark_cyan,
                                    fontFamily: 'Raleway',
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ),
                            ]
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              RichText(
                                text: TextSpan(
                                  text: '実施日',
                                  style: TextStyle(
                                    color: CustomColor.dark_cyan,
                                    fontFamily: 'Raleway',
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ),
                              Spacer(),
                              RichText(
                                text: TextSpan(
                                  text: '月曜',
                                  style: TextStyle(
                                    color: CustomColor.dark_cyan,
                                    fontFamily: 'Raleway',
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ),
                              Switch(
                                value: flagMonday,
                                onChanged: (value) {
                                  setState(() {
                                    flagMonday = value;
                                  });
                                },
                                activeColor: CustomColor.sea_blue,
                              ),
                            ]
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Spacer(),
                              RichText(
                                text: TextSpan(
                                  text: '火曜',
                                  style: TextStyle(
                                    color: CustomColor.dark_cyan,
                                    fontFamily: 'Raleway',
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ),
                              Switch(
                                activeColor: CustomColor.dark_cyan,
                                value: flagTuesday,
                                onChanged: (bool e) {
                                  setState(() {
                                    flagTuesday = e;
                                  });
                                }
                              ),
                            ]
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Spacer(),
                              RichText(
                                text: TextSpan(
                                  text: '水曜',
                                  style: TextStyle(
                                    color: CustomColor.dark_cyan,
                                    fontFamily: 'Raleway',
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ),
                              Switch(
                                activeColor: CustomColor.dark_cyan,
                                value: flagWednesday,
                                onChanged: (bool e) {
                                  setState(() {
                                    flagWednesday = e;
                                  });
                                }
                              ),
                            ]
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Spacer(),
                              RichText(
                                text: TextSpan(
                                  text: '木曜',
                                  style: TextStyle(
                                    color: CustomColor.dark_cyan,
                                    fontFamily: 'Raleway',
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ),
                              Switch(
                                activeColor: CustomColor.dark_cyan,
                                value: flagThursday,
                                onChanged: (bool e) {
                                  setState(() {
                                    flagThursday = e;
                                  });
                                }
                              ),
                            ]
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Spacer(),
                              RichText(
                                text: TextSpan(
                                  text: '金曜',
                                  style: TextStyle(
                                    color: CustomColor.dark_cyan,
                                    fontFamily: 'Raleway',
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ),
                              Switch(
                                activeColor: CustomColor.dark_cyan,
                                value: flagFriday,
                                onChanged: (bool e) {
                                  setState(() {
                                    flagFriday = e;
                                  });
                                }
                              ),
                            ]
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Spacer(),
                              RichText(
                                text: TextSpan(
                                  text: '土曜',
                                  style: TextStyle(
                                    color: CustomColor.dark_cyan,
                                    fontFamily: 'Raleway',
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ),
                              Switch(
                                activeColor: CustomColor.dark_cyan,
                                value: flagSaturday,
                                onChanged: (bool e) {
                                  setState(() {
                                    flagSaturday = e;
                                  });
                                }
                              ),
                            ]
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Spacer(),
                              RichText(
                                text: TextSpan(
                                  text: '日曜',
                                  style: TextStyle(
                                    color: CustomColor.dark_cyan,
                                    fontFamily: 'Raleway',
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ),
                              Switch(
                                activeColor: CustomColor.dark_cyan,
                                value: flagSunday,
                                onChanged: (bool e) {
                                  setState(() {
                                    flagSunday = e;
                                  });
                                }
                              ),
                            ]
                          )
                        ]
                      )
                    ),
                    Visibility(
                      visible: isRepeat&&dropdownValue=='毎月',
                      child: SizedBox(height: 10),
                    ),
                    Visibility(
                      visible: isRepeat&&dropdownValue=='毎月',
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              RichText(
                                text: TextSpan(
                                  text: '次の頻度でリピート',
                                  style: TextStyle(
                                    color: CustomColor.dark_cyan,
                                    fontFamily: 'Raleway',
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ),
                              Spacer(),
                              DropdownButton<int>(
                                value: monthlyInterval,
                                icon: const Icon(Icons.arrow_downward, color: CustomColor.dark_cyan,),
                                iconSize: 24,
                                elevation: 16,
                                style: const TextStyle(color: CustomColor.dark_cyan),
                                underline: Container(
                                  height: 2,
                                  color: Colors.deepPurpleAccent,
                                ),
                                onChanged: (int newValue) {
                                  setState(() {
                                    monthlyInterval = newValue;
                                  });
                                },
                                items: <int>[1, 2, 3, 4, 5, 6]
                                    .map<DropdownMenuItem<int>>((int value) {
                                  return DropdownMenuItem<int>(
                                    value: value,
                                    child: Text(value.toString()),
                                  );
                                }).toList(),
                              ),
                              RichText(
                                text: TextSpan(
                                  text: ' ヶ月',
                                  style: TextStyle(
                                    color: CustomColor.dark_cyan,
                                    fontFamily: 'Raleway',
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ),
                            ]
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              RichText(
                                text: TextSpan(
                                  text: '実施日',
                                  style: TextStyle(
                                    color: CustomColor.dark_cyan,
                                    fontFamily: 'Raleway',
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ),
                              Spacer(),
                              Radio(
                                activeColor: CustomColor.dark_cyan,
                                value: '毎月',
                                groupValue: monthlyBy,
                                onChanged: (payment) => setState(() { monthlyBy = payment; } ),
                              ),
                              RichText(
                                text: TextSpan(
                                  text: '毎月 ',
                                  style: TextStyle(
                                    color: CustomColor.dark_cyan,
                                    fontFamily: 'Raleway',
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ),
                              DropdownButton<int>(
                                value: monthlyDay,
                                icon: const Icon(Icons.arrow_downward, color: CustomColor.dark_cyan,),
                                iconSize: 24,
                                elevation: 16,
                                style: const TextStyle(color: CustomColor.dark_cyan),
                                underline: Container(
                                  height: 2,
                                  color: Colors.deepPurpleAccent,
                                ),
                                onChanged: (int newValue) {
                                  setState(() {
                                    monthlyDay = newValue;
                                  });
                                },
                                items: <int>[
                                  1, 2, 3, 4, 5, 6, 7, 8, 9, 10,
                                  11, 12, 13, 14, 15, 16, 17, 18, 19, 20,
                                  21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31,
                                ].map<DropdownMenuItem<int>>((int value) {
                                  return DropdownMenuItem<int>(
                                    value: value,
                                    child: Text(value.toString()),
                                  );
                                }).toList(),
                              ),
                              RichText(
                                text: TextSpan(
                                  text: ' 日',
                                  style: TextStyle(
                                    color: CustomColor.dark_cyan,
                                    fontFamily: 'Raleway',
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ),
                              SizedBox(width: 20),
                            ]
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Spacer(),
                              Radio(
                                activeColor: CustomColor.dark_cyan,
                                value: '隔週',
                                groupValue: monthlyBy,
                                onChanged: (payment) => setState(() { monthlyBy = payment; } ),
                              ),
                              RichText(
                                text: TextSpan(
                                  text: '第 ',
                                  style: TextStyle(
                                    color: CustomColor.dark_cyan,
                                    fontFamily: 'Raleway',
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ),
                              DropdownButton<int>(
                                value: monthlyWeekIndex,
                                icon: const Icon(Icons.arrow_downward, color: CustomColor.dark_cyan,),
                                iconSize: 24,
                                elevation: 16,
                                style: const TextStyle(color: CustomColor.dark_cyan),
                                underline: Container(
                                  height: 2,
                                  color: Colors.deepPurpleAccent,
                                ),
                                onChanged: (int newValue) {
                                  setState(() {
                                    monthlyWeekIndex = newValue;
                                  });
                                },
                                items: <int>[1, 2, 3, 4, 5,].map<DropdownMenuItem<int>>((int value) {
                                  return DropdownMenuItem<int>(
                                    value: value,
                                    child: Text(value.toString()),
                                  );
                                }).toList(),
                              ),
                              SizedBox(width: 10),
                              DropdownButton<String>(
                                value: monthlyWeekDay,
                                icon: const Icon(Icons.arrow_downward, color: CustomColor.dark_cyan,),
                                iconSize: 24,
                                elevation: 16,
                                style: const TextStyle(color: CustomColor.dark_cyan),
                                underline: Container(
                                  height: 2,
                                  color: Colors.deepPurpleAccent,
                                ),
                                onChanged: (String newValue) {
                                  setState(() {
                                    monthlyWeekDay = newValue;
                                  });
                                },
                                items: dayNames.map<DropdownMenuItem<String>>((String value) {
                                  return DropdownMenuItem<String>(
                                    value: value,
                                    child: Text(value),
                                  );
                                }).toList(),
                              ),
                            ]
                          )
                        ]
                      )
                    ),
                    Visibility(
                      visible: isRepeat,
                      child: SizedBox(height: 10),
                    ),
                    Visibility(
                      visible: isRepeat,
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              RichText(
                                text: TextSpan(
                                  text: '終了日',
                                  style: TextStyle(
                                    color: CustomColor.dark_cyan,
                                    fontFamily: 'Raleway',
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1,
                                  ),
                                  children: <TextSpan>[
                                    TextSpan(
                                      text: ' ',
                                      style: TextStyle(
                                        color: Colors.red,
                                        fontSize: 28,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Radio(
                                activeColor: CustomColor.dark_cyan,
                                value: '期限',
                                groupValue: endCondition,
                                onChanged: (payment) => setState(() { endCondition = payment; } ),
                              ),
                              RichText(
                                text: TextSpan(
                                  text: '期限',
                                  style: TextStyle(
                                    color: CustomColor.dark_cyan,
                                    fontFamily: 'Raleway',
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1,
                                  ),
                                  children: <TextSpan>[
                                    TextSpan(
                                      text: ' ',
                                      style: TextStyle(
                                        color: Colors.red,
                                        fontSize: 28,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(child: TextField(
                                cursorColor: CustomColor.sea_blue,
                                controller: textControllerEndDate,
                                textCapitalization: TextCapitalization.characters,
                                keyboardType: TextInputType.datetime,
                                onTap: () => _selectEndDate(context),
                                readOnly: true,
                                style: TextStyle(
                                  color: Colors.black87,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                                decoration: new InputDecoration(
                                  disabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.all(Radius.circular(10.0)),
                                    borderSide: BorderSide(color: CustomColor.sea_blue, width: 1),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.all(Radius.circular(10.0)),
                                    borderSide: BorderSide(color: CustomColor.sea_blue, width: 1),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.all(Radius.circular(10.0)),
                                    borderSide: BorderSide(color: CustomColor.dark_blue, width: 2),
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
                                  hintText: 'eg: September 10, 2020',
                                  hintStyle: TextStyle(
                                    color: Colors.grey.withOpacity(0.6),
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                  errorText: isEditingDate && textControllerEndDate.text != null
                                      ? textControllerEndDate.text.isNotEmpty
                                      ? null
                                      : 'Date can\'t be empty'
                                      : null,
                                  errorStyle: TextStyle(
                                    fontSize: 12,
                                    color: Colors.redAccent,
                                  ),
                                ),
                              )),
                            ]
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              RichText(
                                text: TextSpan(
                                  text: '　　　',
                                  style: TextStyle(
                                    color: CustomColor.dark_cyan,
                                    fontFamily: 'Raleway',
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1,
                                  ),
                                  children: <TextSpan>[
                                    TextSpan(
                                      text: ' ',
                                      style: TextStyle(
                                        color: Colors.red,
                                        fontSize: 28,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Radio(
                                activeColor: CustomColor.dark_cyan,
                                value: '合計',
                                groupValue: endCondition,
                                onChanged: (payment) => setState(() { endCondition = payment; } ),
                              ),
                              RichText(
                                text: TextSpan(
                                  text: '合計　',
                                  style: TextStyle(
                                    color: CustomColor.dark_cyan,
                                    fontFamily: 'Raleway',
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ),
                              DropdownButton<int>(
                                value: endTimes,
                                icon: const Icon(Icons.arrow_downward, color: CustomColor.dark_cyan,),
                                iconSize: 24,
                                elevation: 16,
                                style: const TextStyle(color: CustomColor.dark_cyan),
                                underline: Container(
                                  height: 2,
                                  color: Colors.deepPurpleAccent,
                                ),
                                onChanged: (int newValue) {
                                  setState(() {
                                    endTimes = newValue;
                                  });
                                },
                                items: <int>[1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20]
                                    .map<DropdownMenuItem<int>>((int value) {
                                  return DropdownMenuItem<int>(
                                    value: value,
                                    child: Text(value.toString()),
                                  );
                                }).toList(),
                              ),
                              RichText(
                                text: TextSpan(
                                  text: '　回実施',
                                  style: TextStyle(
                                    color: CustomColor.dark_cyan,
                                    fontFamily: 'Raleway',
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ),
                              Spacer(),
                            ]
                          )
                        ]
                      )
                    ),
                    SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        RichText(
                          text: TextSpan(
                            text: '参加者',
                            style: TextStyle(
                              color: CustomColor.dark_cyan,
                              fontFamily: 'Raleway',
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                            children: <TextSpan>[
                              TextSpan(
                                text: ' ',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontSize: 28,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.add,
                            color: CustomColor.sea_blue,
                            size: 35,
                          ),
                          onPressed: () => addToAttendee(),
                        ),
                      ]
                    ),
                    SizedBox(height: 10),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: PageScrollPhysics(),
                      itemCount: attendeeEmails.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                attendeeEmails[index].displayName+
                                '('+attendeeEmails[index].email+')',
                                style: TextStyle(
                                  color: CustomColor.neon_green,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              ),
                              IconButton(
                                icon: Icon(Icons.close),
                                onPressed: () {
                                  setState(() {
                                    attendeeEmails.removeAt(index);
                                  });
                                },
                                color: Colors.red,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextField(
                            enabled: true,
                            cursorColor: CustomColor.sea_blue,
                            focusNode: textFocusNodeAttendee,
                            controller: textControllerAttendee,
                            textCapitalization: TextCapitalization.none,
                            textInputAction: TextInputAction.done,
                            keyboardType: TextInputType.emailAddress,
                            onChanged: (value) {
                              setState(() {
                                currentEmail = value;
                              });
                            },
                            onSubmitted: (value) {
                              textFocusNodeAttendee.unfocus();
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
                                borderSide: BorderSide(color: CustomColor.sea_blue, width: 1),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.all(Radius.circular(10.0)),
                                borderSide: BorderSide(color: CustomColor.dark_blue, width: 2),
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
                              hintText: 'ゲストのメールアドレス',
                              hintStyle: TextStyle(
                                color: Colors.grey.withOpacity(0.6),
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                              errorText: isEditingEmail ? globals.validateEmail(currentEmail) : null,
                              errorStyle: TextStyle(
                                fontSize: 12,
                                color: Colors.redAccent,
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.check_circle,
                            color: CustomColor.sea_blue,
                            size: 35,
                          ),
                          onPressed: () {
                            if (_members.isEmpty) {
                              readMemberList();
                            }
                            setState(() {
                              isEditingEmail = true;
                            });
                            if (globals.validateEmail(currentEmail) == null) {
                              setGuestInfo(currentEmail);
                              setState(() {
                                textControllerAttendee.text = '';
                                currentEmail = null;
                                isEditingEmail = false;
                              });
                              /*
                              for (final member in _members) {
                                if (member['email'] == currentEmail) {
                                  setState(() {
                                    textFocusNodeAttendee.unfocus();
                                    calendar.EventAttendee eventAttendee = calendar.EventAttendee();
                                    eventAttendee.id = member['userid'].toString();
                                    eventAttendee.email = currentEmail;
                                    eventAttendee.displayName = member['username'];

                                    attendeeEmails.add(eventAttendee);


                                    textControllerAttendee.text = '';
                                    currentEmail = null;
                                    isEditingEmail = false;
                                  });
                                  break;
                                }
                              }
                               */
                            }
                          },
                        ),
                      ],
                    ),
                    Visibility(
                      visible: attendeeEmails.isNotEmpty,
                      child: Column(
                        children: [
                          SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Notify attendees',
                                style: TextStyle(
                                  color: CustomColor.dark_cyan,
                                  fontFamily: 'Raleway',
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              Switch(
                                value: shouldNofityAttendees,
                                onChanged: (value) {
                                  setState(() {
                                    shouldNofityAttendees = value;
                                  });
                                },
                                activeColor: CustomColor.sea_blue,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'ミーティングID',
                          style: TextStyle(
                            color: CustomColor.dark_cyan,
                            fontFamily: 'Raleway',
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ]
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        SizedBox(width: 20,),
                        Radio(
                          activeColor: CustomColor.dark_cyan,
                          value: '自動的',
                          groupValue: meetingId,
                          onChanged: (payment) => setState(() { meetingId = payment; } ),
                        ),
                        RichText(
                          text: TextSpan(
                            text: 'ミーティングIDを自動的に生成',
                            style: TextStyle(
                              color: CustomColor.dark_cyan,
                              fontFamily: 'Raleway',
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                        Spacer(),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        SizedBox(width: 20,),
                        Radio(
                          activeColor: CustomColor.dark_cyan,
                          value: '個人的',
                          groupValue: meetingId,
                          onChanged: (payment) => setState(() { meetingId = payment; } ),
                        ),
                        RichText(
                          text: TextSpan(
                            text: '個人ミーティングIDを使用',
                            style: TextStyle(
                              color: CustomColor.dark_cyan,
                              fontFamily: 'Raleway',
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                        Spacer(),
                      ],
                    ),
                    SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'パスワード',
                          style: TextStyle(
                            color: CustomColor.dark_cyan,
                            fontFamily: 'Raleway',
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ]
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        SizedBox(width: 20,),
                        Radio(
                          activeColor: CustomColor.dark_cyan,
                          value: '必要',
                          groupValue: needMeetingPass,
                          onChanged: (payment) => setState(() { needMeetingPass = payment; } ),
                        ),
                        RichText(
                          text: TextSpan(
                            text: 'パスワード必要',
                            style: TextStyle(
                              color: CustomColor.dark_cyan,
                              fontFamily: 'Raleway',
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                        Expanded(child: TextField(
                          enabled: true,
                          cursorColor: CustomColor.sea_blue,
                          controller: textControllerPassword,
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.next,
                          keyboardType: TextInputType.text,
                          onChanged: (value) {
                            setState(() {
                              meetingPassword = value;
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
                              borderSide: BorderSide(color: CustomColor.sea_blue, width: 1),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.all(Radius.circular(10.0)),
                              borderSide: BorderSide(color: CustomColor.dark_blue, width: 2),
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
                            hintText: 'パスワード',
                            hintStyle: TextStyle(
                              color: Colors.grey.withOpacity(0.6),
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        )),
                      ],
                    ),
                    SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        SizedBox(width: 20,),
                        Radio(
                          activeColor: CustomColor.dark_cyan,
                          value: '自動',
                          groupValue: needMeetingPass,
                          onChanged: (payment) => setState(() { needMeetingPass = payment; } ),
                        ),
                        RichText(
                          text: TextSpan(
                            text: 'パスワードを自動的に入力',
                            style: TextStyle(
                              color: CustomColor.dark_cyan,
                              fontFamily: 'Raleway',
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                        Spacer(),
                      ],
                    ),
                    SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'ビデオON',
                          style: TextStyle(
                            color: CustomColor.dark_cyan,
                            fontFamily: 'Raleway',
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ]
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        SizedBox(width: 20,),
                        RichText(
                          text: TextSpan(
                            text: 'ホスト',
                            style: TextStyle(
                              color: CustomColor.dark_cyan,
                              fontFamily: 'Raleway',
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                        Spacer(),
                        Switch(
                          value: videoHostOn,
                          onChanged: (value) {
                            setState(() {
                              videoHostOn = value;
                            });
                          },
                          activeColor: CustomColor.sea_blue,
                        ),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        SizedBox(width: 20,),
                        RichText(
                          text: TextSpan(
                            text: '参加者',
                            style: TextStyle(
                              color: CustomColor.dark_cyan,
                              fontFamily: 'Raleway',
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                        Spacer(),
                        Switch(
                          value: videoAttendeeOn,
                          onChanged: (value) {
                            setState(() {
                              videoAttendeeOn = value;
                            });
                          },
                          activeColor: CustomColor.sea_blue,
                        ),
                      ],
                    ),
                    SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'ミーティングオプション',
                          style: TextStyle(
                            color: CustomColor.dark_cyan,
                            fontFamily: 'Raleway',
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ]
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        SizedBox(width: 20,),
                        RichText(
                          text: TextSpan(
                            text: '入室時に参加者をミュート',
                            style: TextStyle(
                              color: CustomColor.dark_cyan,
                              fontFamily: 'Raleway',
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                        Spacer(),
                        Switch(
                          value: notMuteUponEntry,
                          onChanged: (value) {
                            setState(() {
                              notMuteUponEntry = value;
                            });
                          },
                          activeColor: CustomColor.sea_blue,
                        ),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        SizedBox(width: 20,),
                        RichText(
                          text: TextSpan(
                            text: 'ミーティングを自動録画',
                            style: TextStyle(
                              color: CustomColor.dark_cyan,
                              fontFamily: 'Raleway',
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                        Spacer(),
                        Switch(
                          value: autoRecordLocal,
                          onChanged: (value) {
                            setState(() {
                              autoRecordLocal = value;
                            });
                          },
                          activeColor: CustomColor.sea_blue,
                        ),
                      ],
                    ),
                    SizedBox(height: 20),
                    Container(
                      width: double.maxFinite,
                      child: ElevatedButton(
                        style: ButtonStyle(
                          elevation: MaterialStateProperty.resolveWith<double>((Set<MaterialState> states) => 0.0),
                          foregroundColor: MaterialStateProperty.resolveWith<Color>((Set<MaterialState> states) => CustomColor.sea_blue),
                          shape: MaterialStateProperty.resolveWith<OutlinedBorder>((Set<MaterialState> states) => RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          )),
                        ),
                        //focusElevation: 0,
                        //highlightElevation: 0,
                        onPressed: isDataStorageInProgress
                          ? null
                          : () async {
                            setState(() {
                              isErrorTime = false;
                              isDataStorageInProgress = true;
                            });

                            textFocusNodeTitle.unfocus();
                            textFocusNodeDesc.unfocus();
                            textFocusNodeLocation.unfocus();
                            textFocusNodeAttendee.unfocus();

                            if (selectedDate != null &&
                                selectedStartTime != null &&
                                selectedEndTime != null &&
                                currentTitle != null) {
                              int startTimeInEpoch = DateTime(
                                selectedDate.year,
                                selectedDate.month,
                                selectedDate.day,
                                selectedStartTime.hour,
                                selectedStartTime.minute,
                              ).millisecondsSinceEpoch;

                              int endTimeInEpoch = DateTime(
                                selectedDate.year,
                                selectedDate.month,
                                selectedDate.day,
                                selectedEndTime.hour,
                                selectedEndTime.minute,
                              ).millisecondsSinceEpoch;

                              if (startTimeInEpoch > endTimeInEpoch) {
                                endTimeInEpoch += 24*60*60*1000;
                              }

                              print('DIFFERENCE: ${endTimeInEpoch - startTimeInEpoch}');
                              print('Start Time: ${DateTime.fromMillisecondsSinceEpoch(startTimeInEpoch)}');
                              print('End Time: ${DateTime.fromMillisecondsSinceEpoch(endTimeInEpoch)}');

                              if (endTimeInEpoch - startTimeInEpoch > 0) {
                                if (_validateTitle(currentTitle) == null) {
                                  FreqMode mode = FreqMode.FreqNone;
                                  switch (dropdownValue) {
                                    case '毎日':
                                      mode = FreqMode.FreqDaily;
                                      break;
                                    case '週ごと':
                                      mode = FreqMode.FreqWeekly;
                                      break;
                                    case '毎月':
                                      mode = FreqMode.FreqMonthly;
                                      break;
                                  }
                                  List<String> dotw = [];
                                  if (flagMonday) dotw.add('mon');
                                  if (flagTuesday) dotw.add('tue');
                                  if (flagWednesday) dotw.add('wed');
                                  if (flagThursday) dotw.add('thu');
                                  if (flagFriday) dotw.add('fri');
                                  if (flagSaturday) dotw.add('sat');
                                  if (flagSunday) dotw.add('sun');
                                  String weekDay = '';
                                  int idx = dayNames.indexOf(monthlyWeekDay);
                                  if (idx >= 0) {
                                    weekDay = engNames[idx];
                                  }
                                  Recurrence recurrence = Recurrence(
                                    freqMode: mode,
                                    dailyInterval: dailyInterval,
                                    weeklyInterval: weeklyInterval,
                                    weeklyDotw: dotw.join(','),
                                    monthlyInterval: monthlyInterval,
                                    monthlyBy: monthlyBy=='毎月'?MonthlyBy.byMonthDay:MonthlyBy.byWeekDay,
                                    monthlyDay: monthlyDay,
                                    monthlyWeekdayIndex: monthlyWeekIndex,
                                    monthlyWeekDay: weekDay,
                                    endBy: endCondition=='期限'?EndBy.endByDate:EndBy.endByTimes,
                                    endDate: selectedTermDate!=null?selectedTermDate:DateTime.now(),
                                    endTimes: endTimes
                                  );

                                  List<Map<String,dynamic>> users = [];
                                  for (int i = 0; i < attendeeEmails.length; i++) {
                                    Map<String,dynamic> user = {};
                                    if (attendeeEmails[i].id == "guest") {
                                      var userid = await addGuest(attendeeEmails[i].email, attendeeEmails[i].comment, attendeeEmails[i].displayName);
                                      if (userid != null) {
                                        user['userid'] = userid;
                                      }
                                    } else {
                                      user['userid'] = attendeeEmails[i].id;
                                    }
                                    user['username'] = attendeeEmails[i].displayName;
                                    user['email'] = attendeeEmails[i].email;
                                    users.add(user);
                                  }

                                  EventInfo eventInfo = EventInfo(
                                    //googleId: eventId,
                                    name: currentTitle,
                                    description: currentDesc ?? '',
                                    location: currentLocation,
                                    meetingType: meetingType,
                                    //link: eventLink,
                                    attendeeInfo: users,
                                    shouldNotifyAttendees: shouldNofityAttendees,
                                    hasConfereningSupport: false,
                                    //hasConferenceSupport,
                                    startTimeInEpoch: startTimeInEpoch,
                                    endTimeInEpoch: endTimeInEpoch,
                                    recurrence: recurrence,
                                    usePersonalMeetingId: meetingId=='個人的',
                                    useMeetingPass: needMeetingPass=='必要',
                                    meetingPass: meetingPassword,
                                    videoHostOn: videoHostOn,
                                    videoAttendeeOn: videoAttendeeOn,
                                    muteUponEntry: !notMuteUponEntry,
                                    autoRecordLocal: autoRecordLocal,
                                  );

                                  if (addToGoogleCalendar) {
                                    await calendarClient.insert(
                                      title: currentTitle,
                                      description: currentDesc ?? '',
                                      location: currentLocation,
                                      attendeeEmailList: attendeeEmails,
                                      shouldNotifyAttendees: shouldNofityAttendees,
                                      hasConferenceSupport: false,
                                      //hasConferenceSupport,
                                      startTime: DateTime
                                        .fromMillisecondsSinceEpoch(
                                          startTimeInEpoch),
                                      endTime: DateTime
                                        .fromMillisecondsSinceEpoch(
                                          endTimeInEpoch),
                                      recurrence: recurrence,
                                    ).then((eventData) async {
                                      eventInfo.setGoogleId = eventData['id'];
                                      eventInfo.setLink = eventData['link'];
                                      await storage
                                        .storeEventData(eventInfo)
                                        .whenComplete(() => Navigator.of(context).pop(storage.lastMeetings))
                                        .catchError((e) => print(e),);
                                    }).catchError(
                                      (e) => print(e),
                                    );
                                  } else {
                                    await storage
                                      .storeEventData(eventInfo)
                                      .whenComplete(() => Navigator.of(context).pop(storage.lastMeetings))
                                      .catchError((e) => print(e),);
                                  }
                                  setState(() {
                                    isDataStorageInProgress = false;
                                  });
                                } else {
                                  setState(() {
                                    isEditingTitle = true;
                                    isEditingLink = true;
                                  });
                                }
                              } else {
                                setState(() {
                                  isErrorTime = true;
                                  errorString = 'Invalid time! Please use a proper start and end time';
                                });
                              }
                            } else {
                              setState(() {
                                isEditingDate = true;
                                isEditingStartTime = true;
                                isEditingEndTime = true;
                                isEditingBatch = true;
                                isEditingTitle = true;
                                isEditingLink = true;
                              });
                            }
                            setState(() {
                              isDataStorageInProgress = false;
                            });
                          },
                        child: Padding(
                          padding: EdgeInsets.only(top: 15.0, bottom: 15.0),
                          child: isDataStorageInProgress
                              ? SizedBox(
                                  height: 28,
                                  width: 28,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: new AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : Text(
                                  'ADD',
                                  style: TextStyle(
                                    fontFamily: 'Raleway',
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                        ),
                      ),
                    ),
                    Visibility(
                      visible: isErrorTime,
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            errorString,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.redAccent,
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<String>addGuest(String email, String org, String name) async {
    String session = await globals.storage.read(key: "session");

    final uri = 'https://room.yourcompany.com/janusmobile/addguest.php';
    var map = new Map<String, dynamic>();
    map['organization'] = org;
    map['name'] = name;
    map['email'] = email;
    map['token'] = session;
    http.Response response = await http.post(Uri.parse(uri), body: map);

    print(response.body);
    if (response.statusCode != 200) {
      await globals.showPopupDialog(context: context, title: "エラー", content: "サイトにアクセスできません", cancel: "閉じる");
      return null;
    }
    final addresult = json.decode(response.body);
    if (addresult['result'] != 0) {
      await globals.showPopupDialog(context: context, title: "エラー", content: addresult['result_string'], cancel: "閉じる");
      return null;
    }
    var userid = addresult['userid'];
    return userid.toString();
  }

  List<Map<String, dynamic>> _members = [];

  addToAttendee() async {
    if (await selectAttendee() > 0) {
      setState(() {
        for (final member in _members) {
          if (member['selected']) {
            var attendee = calendar.EventAttendee();
            attendee.id = member['userid'];
            attendee.displayName = member['username'];
            attendee.email = member['email'];
            attendee.additionalGuests = 0;
            attendeeEmails.add(attendee);
          }
        }
      });
    }
  }

  selectAttendee() async {
    if (_members.isEmpty) {
      await readMemberList();
    }
    return await showDialog<int>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, setState) {
            return AlertDialog(
              title: Text('参加者選択'),
              actions: <Widget>[
                TextButton(
                  child: Text('キャンセル'),
                  onPressed: () => Navigator.of(context).pop(0),
                ),
                TextButton(
                  child: Text('選択'),
                  onPressed: () => Navigator.of(context).pop(1),
                ),
              ],
              content: Container(
                width: double.maxFinite,
                height: double.maxFinite,
                child: ListView(
                  children: List.generate(_members.length, (index) {
                    return ListTile(
                      onTap: () {
                        setState(() {
                          //if (selectingMode) {
                          _members[index]['selected'] =
                          !_members[index]['selected'];
                          //log(paints[index].selected.toString());
                          //}
                        });
                      },
                      selected: _members[index]['selected'],
                      leading: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {},
                        child: Container(
                          width: 48,
                          height: 48,
                          padding: EdgeInsets.symmetric(
                              vertical: 4.0),
                          alignment: Alignment.center,
                          child: CircleAvatar(
                            foregroundImage: NetworkImage(
                                _members[index]['photo'], headers: {
                              'Cookie': _members[index]['cookie']
                            }),
                          ),
                        ),
                      ),
                      title: Text(_members[index]['username']),
                      subtitle: Text(_members[index]['groupname']),
                      trailing: ((_members[index]['selected'])
                          ? Icon(Icons.check_box)
                          : Icon(Icons.check_box_outline_blank))
                    );
                  }),
                )
              )
            );
          }
        );
      }
    );
  }

  setGuestInfo(String email) async {
    String organization = "";
    String guestName = "";
    TextEditingController orgController = TextEditingController(text: organization);
    TextEditingController nameController = TextEditingController(text: guestName);
    return await showDialog<int>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, setState) {
            return AlertDialog(
              title: Text('ゲストを招待'),
              actions: <Widget>[
                TextButton(
                  child: Text('キャンセル'),
                  onPressed: () => Navigator.of(context).pop(0),
                ),
                TextButton(
                  child: Text('追加'),
                  onPressed: () {
                    calendar.EventAttendee eventAttendee = calendar.EventAttendee();
                    eventAttendee.id = 'guest';
                    eventAttendee.email = email;
                    eventAttendee.displayName = guestName;
                    eventAttendee.comment = organization;
                    eventAttendee.additionalGuests = 1;
                    setState(() {
                      attendeeEmails.add(eventAttendee);
                    });
                    Navigator.of(context).pop(1);
                  }
                ),
              ],
              content: Container(
              width: double.maxFinite,
              //height: double.maxFinite,
              child: Column(
                children: [
                  Text('招待するゲストの所属先とお名前を指定してください',
                    style: TextStyle(
                      color: Colors.black87,
                      fontFamily: 'Raleway',
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  SizedBox(height: 20),
                  TextField(
                    enabled: true,
                    cursorColor: CustomColor.sea_blue,
                    controller: orgController,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      keyboardType: TextInputType.name,
                      onChanged: (value) {
                        organization = value;
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
                          borderSide: BorderSide(color: CustomColor.sea_blue, width: 1),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(10.0)),
                          borderSide: BorderSide(color: CustomColor.dark_blue, width: 2),
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
                        hintText: '所属先名',
                        hintStyle: TextStyle(
                          color: Colors.grey.withOpacity(0.6),
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    SizedBox(height: 10),
                    TextField(
                      enabled: true,
                      cursorColor: CustomColor.sea_blue,
                      controller: nameController,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      keyboardType: TextInputType.name,
                      onChanged: (value) {
                        guestName = value;
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
                          borderSide: BorderSide(color: CustomColor.sea_blue, width: 1),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(10.0)),
                          borderSide: BorderSide(color: CustomColor.dark_blue, width: 2),
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
                        hintText: 'お名前',
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
            );
          }
        );
      }
    );
  }

  Future readMemberList() async {
    String token = await globals.storage.read(key: "token");
    String loginType = await globals.storage.read(key: "loginType");
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
          meeting['selected'] = false;
          _members.add(meeting);
        }
      });
    }
  }
}
