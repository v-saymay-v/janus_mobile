import 'package:flutter/material.dart';
import 'package:http/http.dart';
import 'package:http/io_client.dart';
import 'package:intl/intl.dart';
import 'package:googleapis/calendar/v3.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:janus_mobile/meeting/utils/recurrence.dart';

final _googleSignIn = GoogleSignIn(scopes: [
  'https://www.googleapis.com/auth/contacts.readonly',
  'https://www.googleapis.com/auth/calendar',
]);

/// Googleの認証をStream型式で行うHTTLクライアント
class GoogleHttpClient extends IOClient {
  Map<String, String> _headers;

  GoogleHttpClient(this._headers) : super();

  @override
  Future<IOStreamedResponse> send(BaseRequest request) =>
      super.send(request..headers.addAll(_headers));

  @override
  Future<Response> head(Object url, {Map<String, String> headers}) =>
      super.head(url, headers: headers..addAll(_headers));
}

class CalendarClient {
  static var calendar;

  Future<Event> createEvent({
    @required String title,
    @required String description,
    @required String location,
    @required List<EventAttendee> attendeeEmailList,
    @required bool shouldNotifyAttendees,
    @required bool hasConferenceSupport,
    @required DateTime startTime,
    @required DateTime endTime,
    @required Recurrence recurrence,
  }) async {
    GoogleSignInAccount googleSignInAccount = await _googleSignIn.signIn();
    // リクエストから、認証情報を取得
    var client = GoogleHttpClient(await googleSignInAccount.authHeaders);
    calendar = CalendarApi(client);

    Event event = Event();

    event.summary = title;
    event.description = description;
    event.attendees = attendeeEmailList;
    event.location = location;

    if (recurrence.freqMode != FreqMode.FreqNone) {
      String mode = "RRULE:FREQ=";
      switch (recurrence.freqMode) {
        case FreqMode.FreqDaily:
          mode += "DAILY;";
          mode += 'INTERVAL='+recurrence.dailyInterval.toString()+';';
          break;
        case FreqMode.FreqWeekly:
          mode += "WEEKLY;";
          List<String> dates = [];
          var days = recurrence.weeklyDotw.split(',');
          for (var day in days) {
            switch (day) {
              case 'mon':
                dates.add('MO');
                break;
              case 'tue':
                dates.add('TU');
                break;
              case 'wed':
                dates.add('WE');
                break;
              case 'thu':
                dates.add('TH');
                break;
              case 'fri':
                dates.add('FR');
                break;
              case 'sat':
                dates.add('SA');
                break;
              case 'sun':
                dates.add('SU');
                break;
            }
          }
          mode += 'BYDAY='+dates.join(',')+';';
          mode += 'INTERVAL='+recurrence.weeklyInterval.toString()+';';
          break;
        case FreqMode.FreqMonthly:
          mode += "MONTHLY;";
          if (recurrence.monthlyBy == MonthlyBy.byMonthDay) {
            mode += 'BYMONTHDAY='+recurrence.monthlyDay.toString()+';';
          } else {
            String day = '';
            switch (recurrence.monthlyWeekDay) {
              case 'mon':
                day = 'MO';
                break;
              case 'tue':
                day = 'TU';
                break;
              case 'wed':
                day = 'WE';
                break;
              case 'thu':
                day = 'TH';
                break;
              case 'fri':
                day = 'FR';
                break;
              case 'sat':
                day = 'SA';
                break;
              case 'sun':
                day = 'SU';
                break;
            }
            mode += 'BYDAY='+recurrence.monthlyWeekdayIndex.toString()+day+';';
          }
          mode += 'INTERVAL='+recurrence.monthlyInterval.toString()+';';
          break;
        default:
          mode += "DAILY;";
      }
      if (recurrence.endBy == EndBy.endByTimes) {
        mode += "COUNT="+recurrence.endTimes.toString();
      } else {
        var formatter1 = new DateFormat('yyyyMMdd', "ja_JP");
        var formatter2 = new DateFormat('HHmmss', "ja_JP");
        String ds = formatter1.format(startTime)+'T'+formatter2.format(startTime)+'Z';
        mode += 'UNTIL='+ds;
      }
      event.recurrence = [];
      event.recurrence.add(mode);
    }

    if (hasConferenceSupport) {
      ConferenceData conferenceData = ConferenceData();
      CreateConferenceRequest conferenceRequest = CreateConferenceRequest();
      conferenceRequest.requestId = "${startTime.millisecondsSinceEpoch}-${endTime.millisecondsSinceEpoch}";
      conferenceData.createRequest = conferenceRequest;

      event.conferenceData = conferenceData;
    }

    EventDateTime start = new EventDateTime();
    start.dateTime = startTime;
    start.timeZone = "GMT+09:00";
    event.start = start;

    EventDateTime end = new EventDateTime();
    end.timeZone = "GMT+09:00";
    end.dateTime = endTime;
    event.end = end;

    return event;
  }

  Future<Map<String, String>> insert({
    @required String title,
    @required String description,
    @required String location,
    @required List<EventAttendee> attendeeEmailList,
    @required bool shouldNotifyAttendees,
    @required bool hasConferenceSupport,
    @required DateTime startTime,
    @required DateTime endTime,
    @required Recurrence recurrence,
  }) async {
    Map<String, String> eventData;

    String calendarId = "primary";
    Event event = await createEvent(
      title: title,
      description: description,
      location: location,
      attendeeEmailList: attendeeEmailList,
      shouldNotifyAttendees: shouldNotifyAttendees,
      hasConferenceSupport: hasConferenceSupport,
      startTime: startTime,
      endTime: endTime,
      recurrence: recurrence,
    );

    try {
      await calendar.events
          .insert(event, calendarId,
              conferenceDataVersion: hasConferenceSupport ? 1 : 0, sendUpdates: shouldNotifyAttendees ? "all" : "none")
          .then((value) {
        print("Event Status: ${value.status}");
        if (value.status == "confirmed") {
          String joiningLink;
          String eventId;

          eventId = value.id;

          if (hasConferenceSupport) {
            joiningLink = "https://meet.google.com/${value.conferenceData.conferenceId}";
          }

          eventData = {'id': eventId, 'link': joiningLink};

          print('Event added to Google Calendar');
        } else {
          print("Unable to add event to Google Calendar");
        }
      });
    } catch (e) {
      print('Error creating event $e');
    }
    await _googleSignIn.signOut();

    return eventData;
  }

  Future<Map<String, String>> modify({
    @required String id,
    @required String title,
    @required String description,
    @required String location,
    @required List<EventAttendee> attendeeEmailList,
    @required bool shouldNotifyAttendees,
    @required bool hasConferenceSupport,
    @required DateTime startTime,
    @required DateTime endTime,
    @required Recurrence recurrence,
  }) async {
    Map<String, String> eventData;

    String calendarId = "primary";

    /*
    Event event = Event();
    event.summary = title;
    event.description = description;
    event.attendees = attendeeEmailList;
    event.location = location;

    EventDateTime start = new EventDateTime();
    start.dateTime = startTime;
    start.timeZone = "GMT+05:30";
    event.start = start;

    EventDateTime end = new EventDateTime();
    end.timeZone = "GMT+05:30";
    end.dateTime = endTime;
    event.end = end;
     */

    Event event = await createEvent(
      title: title,
      description: description,
      location: location,
      attendeeEmailList: attendeeEmailList,
      shouldNotifyAttendees: shouldNotifyAttendees,
      hasConferenceSupport: hasConferenceSupport,
      startTime: startTime,
      endTime: endTime,
      recurrence: recurrence,
    );

    try {
      await calendar.events
          .patch(event, calendarId, id,
              conferenceDataVersion: hasConferenceSupport ? 1 : 0, sendUpdates: shouldNotifyAttendees ? "all" : "none")
          .then((value) {
        print("Event Status: ${value.status}");
        if (value.status == "confirmed") {
          String joiningLink;
          String eventId;

          eventId = value.id;

          if (hasConferenceSupport) {
            joiningLink = "https://meet.google.com/${value.conferenceData.conferenceId}";
          }

          eventData = {'id': eventId, 'link': joiningLink};

          print('Event updated in google calendar');
        } else {
          print("Unable to update event in google calendar");
        }
      });
    } catch (e) {
      print('Error updating event $e');
    }
    await _googleSignIn.signOut();

    return eventData;
  }

  Future<void> delete(String eventId, bool shouldNotify) async {
    String calendarId = "primary";

    GoogleSignInAccount googleSignInAccount = await _googleSignIn.signIn();
    // リクエストから、認証情報を取得
    var client = GoogleHttpClient(await googleSignInAccount.authHeaders);
    calendar = CalendarApi(client);

    try {
      await calendar.events.delete(calendarId, eventId, sendUpdates: shouldNotify ? "all" : "none").then((value) {
        print('Event deleted from Google Calendar');
      });
    } catch (e) {
      print('Error deleting event: $e');
    }
    await _googleSignIn.signOut();
  }
}
