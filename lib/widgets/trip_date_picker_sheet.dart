import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class TripDatePickerSheet extends StatefulWidget {
  final DateTime initialStartDate;
  final int initialDays;
  final Function(DateTime startDate, int days) onSave;

  const TripDatePickerSheet({
    super.key,
    required this.initialStartDate,
    required this.initialDays,
    required this.onSave,
  });

  @override
  State<TripDatePickerSheet> createState() => _TripDatePickerSheetState();
}

class _TripDatePickerSheetState extends State<TripDatePickerSheet> {
  DateTimeRange? _selectedDateRange;
  DateTime? _lastTappedDate;

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    final start = DateTime(
      widget.initialStartDate.year,
      widget.initialStartDate.month,
      widget.initialStartDate.day,
    );
    final daysCount = widget.initialDays > 0 ? widget.initialDays : 1;
    final end = start.add(Duration(days: daysCount - 1));

    _selectedDateRange = DateTimeRange(start: start, end: end);
    _lastTappedDate = start;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  int get _calculatedDays {
    if (_selectedDateRange == null) return 1;
    return _selectedDateRange!.end.difference(_selectedDateRange!.start).inDays + 1;
  }

  void _onDateCellTapped(DateTime cellDate) {
    final tappedDate = DateTime(cellDate.year, cellDate.month, cellDate.day);
    setState(() {
      if (_selectedDateRange == null || _lastTappedDate == null) {
        _selectedDateRange = DateTimeRange(start: tappedDate, end: tappedDate);
        _lastTappedDate = tappedDate;
      } else {
        final anchor = _lastTappedDate!;
        DateTime newStart;
        DateTime newEnd;

        if (tappedDate.isBefore(anchor)) {
          newStart = tappedDate;
          newEnd = anchor;
        } else {
          newStart = anchor;
          newEnd = tappedDate;
        }

        // Enforce 30 days maximum trip duration
        int diffDays = newEnd.difference(newStart).inDays + 1;
        if (diffDays > 30) {
          if (tappedDate.isBefore(anchor)) {
            newStart = anchor.subtract(const Duration(days: 29));
          } else {
            newEnd = anchor.add(const Duration(days: 29));
          }
          if (mounted) {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('CloudMood hỗ trợ tạo chuyến đi tối đa 30 ngày.'),
                backgroundColor: AppTheme.amber,
                duration: Duration(seconds: 2),
              ),
            );
          }
        }

        _selectedDateRange = DateTimeRange(start: newStart, end: newEnd);
        _lastTappedDate = tappedDate;
      }
    });
  }

  String _formatMonthYear(DateTime date) {
    return 'Tháng ${date.month}, ${date.year}';
  }

  String _formatDateShort(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _getDurationSubtitle(int days) {
    if (days <= 1) return 'Thời gian: 1 ngày';
    return 'Tổng thời gian: $days ngày ${days - 1} đêm';
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final daysCount = _calculatedDays;
    final startDate = _selectedDateRange?.start ?? today;
    final endDate = _selectedDateRange?.end ?? today;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),

          // Header Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 24),
                  onPressed: () => Navigator.pop(context),
                ),
                Text(
                  'Thời gian chuyến đi',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.darkText,
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    widget.onSave(startDate, daysCount);
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: const Text(
                    'Lưu',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Date Range Info Banner Card
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.calendar_month_rounded,
                      color: Color(0xFF2563EB),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_formatDateShort(startDate)} – ${_formatDateShort(endDate)}',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E40AF),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _getDurationSubtitle(daysCount),
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Days of Week Header Bar
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
            color: Colors.grey[50],
            child: const Row(
              children: [
                Expanded(child: Center(child: Text('CN', style: _weekdayStyle))),
                Expanded(child: Center(child: Text('T2', style: _weekdayStyle))),
                Expanded(child: Center(child: Text('T3', style: _weekdayStyle))),
                Expanded(child: Center(child: Text('T4', style: _weekdayStyle))),
                Expanded(child: Center(child: Text('T5', style: _weekdayStyle))),
                Expanded(child: Center(child: Text('T6', style: _weekdayStyle))),
                Expanded(child: Center(child: Text('T7', style: _weekdayStyle))),
              ],
            ),
          ),

          // Scrollable Months List
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              itemCount: 18, // Show next 18 months
              itemBuilder: (context, monthIndex) {
                final monthDate = DateTime(today.year, today.month + monthIndex, 1);
                return _buildMonthSection(monthDate, today);
              },
            ),
          ),
        ],
      ),
    );
  }

  static const TextStyle _weekdayStyle = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.bold,
    color: Colors.grey,
  );

  Widget _buildMonthSection(DateTime monthDate, DateTime today) {
    final daysInMonth = DateTime(monthDate.year, monthDate.month + 1, 0).day;
    final firstWeekday = DateTime(monthDate.year, monthDate.month, 1).weekday % 7;

    final List<Widget> dayCells = [];

    // Empty lead cells
    for (int i = 0; i < firstWeekday; i++) {
      dayCells.add(const SizedBox.shrink());
    }

    for (int day = 1; day <= daysInMonth; day++) {
      final cellDate = DateTime(monthDate.year, monthDate.month, day);
      final isBeforeToday = cellDate.isBefore(today);

      bool isStart = _selectedDateRange != null &&
          DateUtils.isSameDay(_selectedDateRange!.start, cellDate);
      bool isEnd = _selectedDateRange != null &&
          DateUtils.isSameDay(_selectedDateRange!.end, cellDate);
      bool isInRange = _selectedDateRange != null &&
          cellDate.isAfter(_selectedDateRange!.start) &&
          cellDate.isBefore(_selectedDateRange!.end);

      dayCells.add(
        GestureDetector(
          onTap: isBeforeToday ? null : () => _onDateCellTapped(cellDate),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              gradient: (isStart || isEnd)
                  ? const LinearGradient(
                      colors: [Color(0xFF1A56DB), Color(0xFF0EA5E9)],
                    )
                  : null,
              color: (isStart || isEnd)
                  ? null
                  : (isInRange
                      ? AppTheme.primary.withValues(alpha: 0.15)
                      : Colors.transparent),
              borderRadius: BorderRadius.circular((isStart || isEnd) ? 30 : 8),
              boxShadow: (isStart || isEnd)
                  ? [
                      BoxShadow(
                        color: AppTheme.primary.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: Text(
                '$day',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: (isStart || isEnd)
                      ? FontWeight.bold
                      : (isInRange ? FontWeight.w700 : FontWeight.w500),
                  color: isBeforeToday
                      ? Colors.grey[300]
                      : (isStart || isEnd)
                          ? Colors.white
                          : (isInRange ? const Color(0xFF0F172A) : AppTheme.darkText),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Text(
            _formatMonthYear(monthDate),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.darkText,
            ),
          ),
        ),
        GridView.count(
          crossAxisCount: 7,
          mainAxisSpacing: 6,
          crossAxisSpacing: 6,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: dayCells,
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}
