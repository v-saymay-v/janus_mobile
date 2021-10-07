import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

enum FreqMode {
  FreqNone,
  FreqDaily,
  FreqWeekly,
  FreqMonthly
}

enum MonthlyBy {
  byMonthDay,
  byWeekDay
}

enum EndBy {
  endByDate,
  endByTimes
}

class Recurrence {
  final FreqMode freqMode;  // = FreqMode.FreqNone;
  final int dailyInterval;  // = 0;
  final int weeklyInterval; // = 0;
  final String weeklyDotw;  // = '';
  final int monthlyInterval;  // = 0;
  final MonthlyBy monthlyBy;  // = MonthlyBy.byMonthDay;
  final int monthlyDay; // = 0;
  final int monthlyWeekdayIndex;  // = 0;
  final String monthlyWeekDay;  // = '';
  final EndBy endBy;  // = 0;
  final DateTime endDate;
  final int endTimes; // = 1;

  Recurrence({
    @required this.freqMode,
    this.dailyInterval=1,
    this.weeklyInterval=1,
    this.weeklyDotw='',
    this.monthlyInterval=1,
    this.monthlyBy=MonthlyBy.byMonthDay,
    this.monthlyDay=1,
    this.monthlyWeekdayIndex=0,
    this.monthlyWeekDay='',
    this.endBy=EndBy.endByDate,
    this.endDate,
    this.endTimes=1
  });

  static FreqMode convToFreq(String freq) {
    switch (freq) {
      case 'daily':
        return FreqMode.FreqDaily;
      case 'weekly':
        return FreqMode.FreqWeekly;
      case 'monthly':
        return FreqMode.FreqMonthly;
    }
    return FreqMode.FreqNone;
  }

  Recurrence.fromMap(Map snapshot)
    : freqMode = convToFreq(snapshot['recurrence_type']),
      dailyInterval = snapshot['daily_interval'],
      weeklyInterval = snapshot['weekly_interval'],
      monthlyInterval = snapshot['monthly_interval'],
      weeklyDotw = snapshot['weekly_dotw'],
      monthlyBy = snapshot['monthly_by']=='bymonthday'?MonthlyBy.byMonthDay:MonthlyBy.byWeekDay,
      monthlyDay = snapshot['monthly_day'],
      monthlyWeekdayIndex = snapshot['monthly_weekday_index'],
      monthlyWeekDay = snapshot['monthly_week_day'],
      endBy = snapshot['end_by']=='end_datetime'?EndBy.endByDate:EndBy.endByTimes,
      endDate = snapshot['end_date']==null?DateTime.now():DateTime.parse(snapshot['end_date']),
      endTimes = snapshot['end_times'] ?? 1;

  Map<String, dynamic> addToMap(Map<String, dynamic> map) {
    Map<String, dynamic> newMap = {};
    for (final key in map.keys) {
      newMap[key] = map[key];
    }
    switch (freqMode) {
      case FreqMode.FreqNone:
        newMap['recurrence_type'] = 'norepeat';
        break;
      case FreqMode.FreqDaily:
        newMap['recurrence_type'] = 'daily';
        break;
      case FreqMode.FreqWeekly:
        newMap['recurrence_type'] = 'weekly';
        break;
      case FreqMode.FreqMonthly:
        newMap['recurrence_type'] = 'monthly';
        break;
    }
    newMap['daily_interval'] = dailyInterval.toString();
    newMap['weekly_interval'] = weeklyInterval.toString();
    newMap['weekly_dotw'] = weeklyDotw.toString();
    newMap['monthly_interval'] = monthlyInterval.toString();
    newMap['monthly_by'] = monthlyBy==MonthlyBy.byMonthDay?'bymonthday':'byday';
    newMap['monthly_day'] = monthlyDay.toString();
    newMap['monthly_weekday_index'] = monthlyWeekdayIndex.toString();
    newMap['monthly_week_day'] = monthlyWeekDay;
    newMap['end_by'] = endBy==EndBy.endByDate?'end_datetime':'end_times';
    var formatter = new DateFormat('yyyy-MM-dd HH:mm:ss', "ja_JP");
    newMap['end_date'] = formatter.format(endDate);
    /*
    newMap['end_date'] = endDate==null?'':endDate.year.toString()+'-'
        +(endDate.month<10?'0'+endDate.month.toString():endDate.month.toString())+'-'
        +(endDate.day<10?'0'+endDate.day.toString():endDate.day.toString())+' '
        +(endDate.hour<10?'0'+endDate.hour.toString():endDate.hour.toString())+':'
        +(endDate.minute<10?'0'+endDate.minute.toString():endDate.minute.toString())+':'
        +(endDate.second<10?'0'+endDate.second.toString():endDate.second.toString());
     */
    newMap['end_times'] = endTimes.toString();
    return newMap;
  }
}
