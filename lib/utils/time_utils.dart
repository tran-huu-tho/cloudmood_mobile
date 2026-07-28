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

  static bool isPlaceOpenOnDate(dynamic hoursData, DateTime targetDate) {
    if (hoursData == null) return true;

    dynamic data = hoursData;
    if (data is String) {
      if (data.isEmpty) return false;
      try {
        if (data.startsWith('{') || data.startsWith('[')) {
          data = jsonDecode(data);
        } else {
          final lower = data.toLowerCase();
          if (lower.contains('tạm đóng cửa') || lower.contains('closed')) return false;
          return true;
        }
      } catch (_) {
        final lower = data.toLowerCase();
        if (lower.contains('tạm đóng cửa') || lower.contains('closed')) return false;
        return true;
      }
    }

    if (data is Map) {
      if (data.isEmpty) return true;

      final dayNamesEn = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
      final weekdayIndex = targetDate.weekday - 1; // 0 = Mon, 6 = Sun
      final dayKey = dayNamesEn[weekdayIndex.clamp(0, 6)];

      if (data.containsKey('weekday_text') && data['weekday_text'] is List) {
        final list = data['weekday_text'] as List;
        if (weekdayIndex < list.length) {
          final text = list[weekdayIndex].toString().toLowerCase();
          if (text.contains('closed') || text.contains('tạm đóng cửa') || text.contains('đóng cửa') || text.contains('nghỉ')) {
            return false;
          }
          return true;
        }
      }

      final bool hasAnyDayKey = dayNamesEn.any((d) => data.containsKey(d));
      if (hasAnyDayKey) {
        if (!data.containsKey(dayKey)) {
          // If schedule map specifies days, but missing target dayKey -> Place is CLOSED!
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
          return true;
        } else if (hours is String) {
          final lower = hours.toLowerCase().trim();
          if (lower.isEmpty || lower.contains('closed') || lower.contains('tạm đóng cửa') || lower.contains('đóng cửa') || lower.contains('nghỉ')) {
            return false;
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
