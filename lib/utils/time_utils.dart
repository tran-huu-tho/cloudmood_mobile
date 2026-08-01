import 'package:flutter/material.dart';
import 'dart:convert';

class TimeUtils {
  static String getOpeningHoursText(dynamic hoursData) {
    if (hoursData == null) return 'Đang cập nhật';
    
    dynamic data = hoursData;
    if (data is String) {
      if (data.isEmpty) return 'Tạm đóng cửa';
      try {
        if (data.startsWith('{') || data.startsWith('[')) {
          data = jsonDecode(data);
        } else {
          return data;
        }
      } catch (_) {
        return data;
      }
    }
    
    if (data is Map) {
      if (data.isEmpty) return 'Đang cập nhật';
      
      if (data.containsKey('weekday_text') && 
          data['weekday_text'] is List && 
          (data['weekday_text'] as List).isNotEmpty) {
        return (data['weekday_text'] as List).first.toString();
      }
      
      final now = DateTime.now();
      final dayNamesEn = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
      final dayNamesVi = ['Thứ 2', 'Thứ 3', 'Thứ 4', 'Thứ 5', 'Thứ 6', 'Thứ 7', 'Chủ nhật'];
      
      final todayIndex = now.weekday - 1; 
      final todayKey = dayNamesEn[todayIndex];
      final todayVi = dayNamesVi[todayIndex];
      
      if (data.containsKey(todayKey)) {
        final hours = data[todayKey];
        if (hours is List && hours.length >= 2) {
          return '$todayVi: ${hours[0]} - ${hours[1]}';
        } else if (hours is String && hours.isNotEmpty) {
          return '$todayVi: $hours';
        }
      }
      return 'Tạm đóng cửa';
    }
    
    return data.toString();
  }

  static double? _parseTimeToDouble(String timeStr) {
    timeStr = timeStr.toLowerCase().trim();
    if (timeStr.isEmpty) return null;
    
    bool isPM = false;
    if (timeStr.contains('pm')) {
      isPM = true;
      timeStr = timeStr.replaceAll('pm', '').trim();
    } else if (timeStr.contains('am')) {
      timeStr = timeStr.replaceAll('am', '').trim();
    }
    
    timeStr = timeStr.replaceAll('h', ':');
    final parts = timeStr.split(':');
    if (parts.isEmpty) return null;
    
    int hour = int.tryParse(parts[0].replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    int minute = 0;
    if (parts.length > 1) {
      minute = int.tryParse(parts[1].replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    }
    
    if (isPM && hour < 12) {
      hour += 12;
    } else if (!isPM && hour == 12) {
      hour = 0;
    }
    
    return hour + (minute / 60.0);
  }

  static List<double>? _parseTimeRangeFromString(String text) {
    final String lower = text.toLowerCase();
    if (lower.contains('mở cửa cả ngày') ||
        lower.contains('24/7') ||
        lower.contains('24 giờ') ||
        lower.contains('24h') ||
        lower.contains('open 24 hours')) {
      return [0.0, 24.0];
    }
    
    final timeRegex = RegExp(r'\b\d{1,2}[:h]\d{2}(?:\s*(?:am|pm))?|\b\d{1,2}\s*(?:am|pm)\b');
    final matches = timeRegex.allMatches(lower).toList();
    
    if (matches.length >= 2) {
      final start = _parseTimeToDouble(matches[0].group(0)!);
      final end = _parseTimeToDouble(matches[1].group(0)!);
      if (start != null && end != null) {
        return [start, end];
      }
    }
    
    final simpleRegex = RegExp(r'\b(\d{1,2})(?:\s*(am|pm))?\s*[-–đĐ]\s*(\d{1,2})(?:\s*(am|pm))?\b');
    final simpleMatch = simpleRegex.firstMatch(lower);
    if (simpleMatch != null) {
      String startStr = simpleMatch.group(1)!;
      if (simpleMatch.group(2) != null) {
        startStr += simpleMatch.group(2)!;
      }
      String endStr = simpleMatch.group(3)!;
      if (simpleMatch.group(4) != null) {
        endStr += simpleMatch.group(4)!;
      }
      final start = _parseTimeToDouble(startStr);
      final end = _parseTimeToDouble(endStr);
      if (start != null && end != null) {
        return [start, end];
      }
    }
    
    return null;
  }

  static bool _isTimeInRange(double start, double end, double time) {
    if (start == end) return start == 0.0 ? false : true;
    if (start < end) {
      return time >= start && time <= end;
    } else {
      return time >= start || time <= end;
    }
  }

  static bool isPlaceOpenOnDate(dynamic hoursData, DateTime targetDate) {
    if (hoursData == null) return true;

    dynamic data = hoursData;
    if (data is String) {
      if (data.isEmpty) return false;
      try {
        if (data.startsWith('{') || data.startsWith('[')) {
          data = jsonDecode(data);
        }
      } catch (_) {}
    }

    final DateTime now = DateTime.now();
    int checkHour = now.hour;
    int checkMin = now.minute;
    final bool isToday = (targetDate.year == now.year &&
        targetDate.month == now.month &&
        targetDate.day == now.day);
        
    if (!isToday) {
      if (targetDate.hour != 0 || targetDate.minute != 0) {
        checkHour = targetDate.hour;
        checkMin = targetDate.minute;
      } else {
        checkHour = 12;
        checkMin = 0;
      }
    }
    
    final double checkTimeDouble = checkHour + (checkMin / 60.0);

    if (data is String) {
      final String lower = data.toLowerCase();
      
      final hasDays = lower.contains('thứ') ||
          lower.contains('t2') ||
          lower.contains('t3') ||
          lower.contains('t4') ||
          lower.contains('t5') ||
          lower.contains('t6') ||
          lower.contains('t7') ||
          lower.contains('chủ nhật') ||
          lower.contains('cn') ||
          lower.contains('monday') ||
          lower.contains('tuesday') ||
          lower.contains('wednesday') ||
          lower.contains('thursday') ||
          lower.contains('friday') ||
          lower.contains('saturday') ||
          lower.contains('sunday') ||
          lower.contains('mon') ||
          lower.contains('tue') ||
          lower.contains('wed') ||
          lower.contains('thu') ||
          lower.contains('fri') ||
          lower.contains('sat') ||
          lower.contains('sun');

      if (!hasDays) {
        if (lower.contains('tạm đóng cửa') ||
            lower.contains('đóng cửa') ||
            lower.contains('closed') ||
            lower.contains('nghỉ')) {
          return false;
        }
        final range = _parseTimeRangeFromString(lower);
        if (range != null) {
          return _isTimeInRange(range[0], range[1], checkTimeDouble);
        }
        return true;
      }

      final weekday = targetDate.weekday; // 1 = Monday, 7 = Sunday
      List<String> dayKeywords = [];
      if (weekday == 1) {
        dayKeywords = ['thứ hai', 't2', 'monday', 'mon'];
      } else if (weekday == 2) {
        dayKeywords = ['thứ ba', 't3', 'tuesday', 'tue'];
      } else if (weekday == 3) {
        dayKeywords = ['thứ tư', 't4', 'wednesday', 'wed'];
      } else if (weekday == 4) {
        dayKeywords = ['thứ năm', 't5', 'thursday', 'thu'];
      } else if (weekday == 5) {
        dayKeywords = ['thứ sáu', 't6', 'friday', 'fri'];
      } else if (weekday == 6) {
        dayKeywords = ['thứ bảy', 't7', 'saturday', 'sat'];
      } else if (weekday == 7) {
        dayKeywords = ['chủ nhật', 'cn', 'sunday', 'sun'];
      }

      int foundIdx = -1;
      String matchedKeyword = '';
      for (final kw in dayKeywords) {
        final idx = lower.indexOf(kw);
        if (idx != -1) {
          foundIdx = idx;
          matchedKeyword = kw;
          break;
        }
      }

      if (foundIdx != -1) {
        int endIdx = lower.length;
        final allOtherKeywords = [
          'thứ hai', 't2', 'monday', 'mon',
          'thứ ba', 't3', 'tuesday', 'tue',
          'thứ tư', 't4', 'wednesday', 'wed',
          'thứ năm', 't5', 'thursday', 'thu',
          'thứ sáu', 't6', 'friday', 'fri',
          'thứ bảy', 't7', 'saturday', 'sat',
          'chủ nhật', 'cn', 'sunday', 'sun'
        ];
        
        for (final kw in allOtherKeywords) {
          if (kw == matchedKeyword) continue;
          final idx = lower.indexOf(kw, foundIdx + matchedKeyword.length);
          if (idx != -1 && idx < endIdx) {
            endIdx = idx;
          }
        }
        
        final daySegment = lower.substring(foundIdx, endIdx);
        if (daySegment.contains('closed') ||
            daySegment.contains('đóng cửa') ||
            daySegment.contains('nghỉ') ||
            daySegment.contains('tạm đóng cửa') ||
            daySegment.contains('off')) {
          return false;
        }
        final range = _parseTimeRangeFromString(daySegment);
        if (range != null) {
          return _isTimeInRange(range[0], range[1], checkTimeDouble);
        }
        return true;
      }
    }

    if (data is Map) {
      if (data.isEmpty) return true;

      if (data.containsKey('open') || data.containsKey('close')) {
        final openVal = data['open']?.toString().toLowerCase() ?? '';
        final closeVal = data['close']?.toString().toLowerCase() ?? '';
        if (openVal.contains('closed') ||
            openVal.contains('đóng cửa') ||
            openVal.contains('nghỉ') ||
            openVal.contains('tạm đóng cửa') ||
            closeVal.contains('closed') ||
            closeVal.contains('đóng cửa') ||
            closeVal.contains('nghỉ') ||
            closeVal.contains('tạm đóng cửa')) {
          return false;
        }
        if (openVal == '00:00' && closeVal == '00:00') {
          return false;
        }
        final start = _parseTimeToDouble(openVal);
        final end = _parseTimeToDouble(closeVal);
        if (start != null && end != null) {
          return _isTimeInRange(start, end, checkTimeDouble);
        }
        return true;
      }

      final dayNamesEn = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
      final weekdayIndex = targetDate.weekday - 1;
      final dayKey = dayNamesEn[weekdayIndex.clamp(0, 6)];

      if (data.containsKey('weekday_text') && data['weekday_text'] is List) {
        final list = data['weekday_text'] as List;
        if (weekdayIndex < list.length) {
          final text = list[weekdayIndex].toString().toLowerCase();
          if (text.contains('closed') || text.contains('tạm đóng cửa') || text.contains('đóng cửa') || text.contains('nghỉ')) {
            return false;
          }
          final range = _parseTimeRangeFromString(text);
          if (range != null) {
            return _isTimeInRange(range[0], range[1], checkTimeDouble);
          }
          return true;
        }
      }

      final bool hasAnyDayKey = dayNamesEn.any((d) => data.containsKey(d));
      if (hasAnyDayKey) {
        if (!data.containsKey(dayKey)) {
          return false;
        }
        final hours = data[dayKey];
        if (hours == null) return false;
        if (hours is List) {
          if (hours.isEmpty) return false;
          final str = hours.join(' ').toLowerCase().trim();
          if (str.isEmpty || str.contains('closed') || str.contains('tạm đóng cửa') || str.contains('đóng cửa') || str.contains('nghỉ')) {
            return false;
          }
          if (hours.length >= 2) {
            final start = _parseTimeToDouble(hours[0]?.toString() ?? '');
            final end = _parseTimeToDouble(hours[1]?.toString() ?? '');
            if (start != null && end != null) {
              return _isTimeInRange(start, end, checkTimeDouble);
            }
          }
          return true;
        } else if (hours is String) {
          final lower = hours.toLowerCase().trim();
          if (lower.isEmpty || lower.contains('closed') || lower.contains('tạm đóng cửa') || lower.contains('đóng cửa') || lower.contains('nghỉ')) {
            return false;
          }
          final range = _parseTimeRangeFromString(lower);
          if (range != null) {
            return _isTimeInRange(range[0], range[1], checkTimeDouble);
          }
          return true;
        }
      }
    }

    return true;
  }

  static List<Map<String, dynamic>> getFullWeekSchedule(dynamic hoursData) {
    if (hoursData == null) return [];
    
    dynamic data = hoursData;
    if (data is String) {
      try {
        if (data.startsWith('{') || data.startsWith('[')) {
          data = jsonDecode(data);
        } else {
          return [];
        }
      } catch (_) {
        return [];
      }
    }
    
    if (data is Map) {
      if (data.isEmpty) {
        final now = DateTime.now();
        final todayIndex = now.weekday - 1;
        final dayNamesVi = ['Thứ hai', 'Thứ ba', 'Thứ tư', 'Thứ năm', 'Thứ sáu', 'Thứ bảy', 'Chủ nhật'];
        final shortNamesVi = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
        return List.generate(7, (i) => {
          'dayName': dayNamesVi[i],
          'shortName': shortNamesVi[i],
          'time': 'Đang cập nhật',
          'isToday': i == todayIndex,
        });
      }
      
      final now = DateTime.now();
      final todayIndex = now.weekday - 1; 

      final dayNamesEn = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
      final dayNamesVi = ['Thứ hai', 'Thứ ba', 'Thứ tư', 'Thứ năm', 'Thứ sáu', 'Thứ bảy', 'Chủ nhật'];
      final shortNamesVi = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];

      // Google places format: weekday_text
      if (data.containsKey('weekday_text') && data['weekday_text'] is List) {
        final list = data['weekday_text'] as List;
        if (list.length == 7) {
           return List.generate(7, (index) {
             // Assuming weekday_text starts from Monday
             final text = list[index].toString();
             final parts = text.split(RegExp(r':\s+'));
             final timeStr = parts.length > 1 ? parts.sublist(1).join(': ') : text;
             return {
               'dayName': dayNamesVi[index],
               'shortName': shortNamesVi[index],
               'time': timeStr.toLowerCase().contains('closed') ? 'Tạm đóng cửa' : timeStr,
               'isToday': index == todayIndex,
             };
           });
        }
      }

      // Our format: Map with monday, tuesday keys
      List<Map<String, dynamic>> schedule = [];
      for (int i = 0; i < 7; i++) {
        final key = dayNamesEn[i];
        String timeStr = 'Tạm đóng cửa';
        if (data.containsKey(key)) {
          final hours = data[key];
          if (hours is List && hours.length >= 2) {
            timeStr = '${hours[0]} - ${hours[1]}';
          } else if (hours is String && hours.isNotEmpty) {
            timeStr = hours;
          }
        }
        schedule.add({
          'dayName': dayNamesVi[i],
          'shortName': shortNamesVi[i],
          'time': timeStr,
          'isToday': i == todayIndex,
        });
      }
      return schedule;
    }
    
    return [];
  }
}
