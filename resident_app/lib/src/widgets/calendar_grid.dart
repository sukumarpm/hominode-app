import 'package:flutter/material.dart';

class CalendarGrid extends StatefulWidget {
  final DateTime? selectedDate;
  final Function(DateTime) onDateSelected;
  final Set<DateTime> blockedDates;

  const CalendarGrid({
    Key? key,
    this.selectedDate,
    required this.onDateSelected,
    this.blockedDates = const {},
  }) : super(key: key);

  @override
  State<CalendarGrid> createState() => _CalendarGridState();
}

class _CalendarGridState extends State<CalendarGrid> {
  late DateTime _currentMonth;

  @override
  void initState() {
    super.initState();
    _currentMonth = DateTime.now();
  }

  void _previousMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
    });
  }

  bool _isSameDay(DateTime? a, DateTime? b) {
    if (a == null || b == null) return false;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  bool _isBlocked(DateTime date) {
    return widget.blockedDates.any((blocked) => _isSameDay(blocked, date));
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return _isSameDay(date, now);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F8FA),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          _buildMonthHeader(),
          const SizedBox(height: 16),
          _buildWeekdayLabels(),
          const SizedBox(height: 8),
          _buildDaysGrid(),
        ],
      ),
    );
  }

  Widget _buildMonthHeader() {
    final monthNames = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          onPressed: _previousMonth,
          icon: const Icon(Icons.chevron_left, size: 24),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
        ),
        Text(
          '${monthNames[_currentMonth.month - 1]} ${_currentMonth.year}',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        IconButton(
          onPressed: _nextMonth,
          icon: const Icon(Icons.chevron_right, size: 24),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
        ),
      ],
    );
  }

  Widget _buildWeekdayLabels() {
    const weekdays = ['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: weekdays.map((day) {
        return SizedBox(
          width: 40,
          child: Center(
            child: Text(
              day,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFF9B9B9B),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDaysGrid() {
    final firstDayOfMonth = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final lastDayOfMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 0);
    final firstWeekday = firstDayOfMonth.weekday % 7;
    
    final daysInMonth = lastDayOfMonth.day;
    final previousMonth = DateTime(_currentMonth.year, _currentMonth.month, 0);
    final daysInPreviousMonth = previousMonth.day;

    List<Widget> dayWidgets = [];

    // Previous month days
    for (int i = firstWeekday - 1; i >= 0; i--) {
      final day = daysInPreviousMonth - i;
      dayWidgets.add(_buildDayCell(
        day,
        isCurrentMonth: false,
      ));
    }

    // Current month days
    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(_currentMonth.year, _currentMonth.month, day);
      dayWidgets.add(_buildDayCell(
        day,
        isCurrentMonth: true,
        date: date,
      ));
    }

    // Next month days to fill grid
    final remainingCells = 42 - dayWidgets.length;
    for (int day = 1; day <= remainingCells; day++) {
      dayWidgets.add(_buildDayCell(
        day,
        isCurrentMonth: false,
      ));
    }

    return GridView.count(
      crossAxisCount: 7,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      children: dayWidgets,
    );
  }

  Widget _buildDayCell(int day, {required bool isCurrentMonth, DateTime? date}) {
    final isSelected = date != null && _isSameDay(widget.selectedDate, date);
    final isBlocked = date != null && _isBlocked(date);
    final isToday = date != null && _isToday(date);
    final isPast = date != null && date.isBefore(DateTime.now().subtract(const Duration(days: 1)));

    Color textColor;
    Color? backgroundColor;
    FontWeight fontWeight = FontWeight.w500;

    if (!isCurrentMonth) {
      textColor = const Color(0xFFD1D5DB);
      backgroundColor = null;
    } else if (isBlocked) {
      textColor = Colors.white;
      backgroundColor = const Color(0xFF0B1020);
      fontWeight = FontWeight.w600;
    } else if (isSelected) {
      textColor = Colors.black;
      backgroundColor = const Color(0xFFE5E7EB);
      fontWeight = FontWeight.w600;
    } else if (isPast) {
      textColor = const Color(0xFFD1D5DB);
      backgroundColor = null;
    } else {
      textColor = Colors.black;
      backgroundColor = null;
    }

    return GestureDetector(
      onTap: () {
        if (isCurrentMonth && date != null && !isPast && !isBlocked) {
          widget.onDateSelected(date);
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            day.toString(),
            style: TextStyle(
              fontSize: 15,
              fontWeight: fontWeight,
              color: textColor,
            ),
          ),
        ),
      ),
    );
  }
}
