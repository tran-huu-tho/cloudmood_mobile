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
