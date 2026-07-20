import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../utils/time_utils.dart';

class ExpandableOpeningHours extends StatefulWidget {
  final dynamic hoursData;
  
  const ExpandableOpeningHours({
    Key? key,
    required this.hoursData,
  }) : super(key: key);

  @override
  _ExpandableOpeningHoursState createState() => _ExpandableOpeningHoursState();
}

class _ExpandableOpeningHoursState extends State<ExpandableOpeningHours> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    if (widget.hoursData == null) return const SizedBox.shrink();

    final schedule = TimeUtils.getFullWeekSchedule(widget.hoursData);
    if (schedule.isEmpty) {
      final hoursText = TimeUtils.getOpeningHoursText(widget.hoursData);
      if (hoursText.isEmpty) return const SizedBox.shrink();
      
      final isClosed = hoursText.toLowerCase().contains('đóng cửa');
      return _buildInfoRow(
        icon: Icons.access_time_rounded,
        child: Text(
          hoursText,
          style: TextStyle(
            color: isClosed ? Colors.red : AppTheme.darkText,
            fontWeight: isClosed ? FontWeight.w600 : FontWeight.normal,
            height: 1.4,
            fontSize: 13,
          ),
        ),
      );
    }

    final todaySchedule = schedule.firstWhere(
      (s) => s['isToday'] == true,
      orElse: () => schedule.first,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () {
            setState(() {
              _isExpanded = !_isExpanded;
            });
          },
          child: _buildInfoRow(
            icon: Icons.access_time_rounded,
            child: RichText(
              text: TextSpan(
                style: TextStyle(
                  color: AppTheme.darkText,
                  height: 1.4,
                  fontSize: 13,
                ),
                children: [
                  TextSpan(
                    text: '${todaySchedule['dayName']}: ${todaySchedule['time']} ',
                    style: TextStyle(
                      color: todaySchedule['time'].toLowerCase().contains('đóng cửa') ? Colors.red : AppTheme.darkText,
                      fontWeight: todaySchedule['time'].toLowerCase().contains('đóng cửa') ? FontWeight.w600 : FontWeight.normal,
                    )
                  ),
                  TextSpan(
                    text: _isExpanded ? 'Chỉ hiển thị hôm nay' : 'Hiển thị các ngày khác',
                    style: const TextStyle(color: Colors.blueAccent),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_isExpanded)
          GestureDetector(
            onTap: () {}, // Ngăn sự kiện click nổi bọt lên parent widget
            child: Padding(
              padding: const EdgeInsets.only(top: 8, left: 28),
            child: Column(
              children: schedule.map((day) {
                final isToday = day['isToday'] == true;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: isToday ? Colors.blueAccent : Colors.blueAccent.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          day['shortName'],
                          style: TextStyle(
                            color: isToday ? Colors.white : Colors.blueAccent,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${day['dayName']}: ${day['time']}',
                          style: TextStyle(
                            fontSize: 13,
                            color: day['time'].toLowerCase().contains('đóng cửa') ? Colors.red : (isToday ? Colors.black87 : Colors.black54),
                            fontWeight: (isToday || day['time'].toLowerCase().contains('đóng cửa')) ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow({required IconData icon, required Widget child}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppTheme.subtitleText, size: 18),
        const SizedBox(width: 10),
        Expanded(child: child),
      ],
    );
  }
}
