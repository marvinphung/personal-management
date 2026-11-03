import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'calendar_models.dart';
import 'calendar_providers.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Day-only DateTime (no time component).
DateTime _dayOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

/// Returns the event-count shading color for a day cell.
Color _shadingColor(BuildContext context, int count) {
  final primary = Theme.of(context).colorScheme.primary;
  if (count == 0) return Colors.transparent;
  if (count <= 2) return primary.withValues(alpha: 0.15);
  if (count <= 5) return primary.withValues(alpha: 0.40);
  return primary.withValues(alpha: 0.70);
}

/// Vietnamese day-of-week header labels (Monday first).
const _viWeekHeaders = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];

/// Vietnamese month title.
String _monthTitle(DateTime month) {
  final f = DateFormat('MMMM yyyy', 'vi');
  return f.format(month);
}

String _eventTimeLabel(CalendarEvent event) {
  if (event.allDay) return 'Cả ngày';
  final start = event.start.toLocal();
  final end = event.end.toLocal();
  return '${_pad(start.hour)}:${_pad(start.minute)} – ${_pad(end.hour)}:${_pad(end.minute)}';
}

String _pad(int v) => v.toString().padLeft(2, '0');

// ---------------------------------------------------------------------------
// Calendar screen
// ---------------------------------------------------------------------------

class CalendarScreen extends ConsumerStatefulWidget {
  final DateTime? initialDate;
  const CalendarScreen({super.key, this.initialDate});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen>
    with WidgetsBindingObserver {
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    if (widget.initialDate != null) {
      _selectedDay = _dayOnly(widget.initialDate!);
    }
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.initialDate != null) {
        ref.read(selectedMonthCalendarProvider.notifier).state = DateTime(
          widget.initialDate!.year,
          widget.initialDate!.month,
        );
      }
      _init();
    });
  }

  @override
  void didUpdateWidget(CalendarScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialDate != null &&
        widget.initialDate != oldWidget.initialDate) {
      _selectedDay = _dayOnly(widget.initialDate!);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(selectedMonthCalendarProvider.notifier).state = DateTime(
          widget.initialDate!.year,
          widget.initialDate!.month,
        );
        _refreshMonth();
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Refresh calendar data when app regains focus.
      ref.read(calendarProvider.notifier).requestPermission();
    }
  }

  Future<void> _init() async {
    final calState = ref.read(calendarProvider);
    if (!calState.hasPermission) {
      await ref.read(calendarProvider.notifier).requestPermission();
    }
    if (mounted) await _refreshMonth();
  }

  Future<void> _refreshMonth() async {
    final month = ref.read(selectedMonthCalendarProvider);
    await ref.read(calendarProvider.notifier).loadEventsForMonth(month);
  }

  void _prevMonth() {
    final m = ref.read(selectedMonthCalendarProvider);
    ref.read(selectedMonthCalendarProvider.notifier).state = DateTime(
      m.year,
      m.month - 1,
    );
    _refreshMonth();
  }

  void _nextMonth() {
    final m = ref.read(selectedMonthCalendarProvider);
    ref.read(selectedMonthCalendarProvider.notifier).state = DateTime(
      m.year,
      m.month + 1,
    );
    _refreshMonth();
  }

  void _goToday() {
    final now = DateTime.now();
    ref.read(selectedMonthCalendarProvider.notifier).state = DateTime(
      now.year,
      now.month,
    );
    setState(() => _selectedDay = _dayOnly(now));
    _refreshMonth();
  }

  @override
  Widget build(BuildContext context) {
    final calState = ref.watch(calendarProvider);
    final month = ref.watch(selectedMonthCalendarProvider);
    final today = _dayOnly(DateTime.now());

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lịch'),
        actions: [
          IconButton(
            tooltip: 'Cài đặt lịch',
            icon: const Icon(Icons.tune_outlined),
            onPressed: () => context.push('/calendar/settings'),
          ),
        ],
      ),
      body: calState.permissionDenied && !calState.hasPermission
          ? _buildPermissionDenied()
          : !calState.hasPermission
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (calState.loading) const LinearProgressIndicator(),
                if (calState.error != null)
                  ListTile(
                    title: Text(calState.error!),
                    trailing: IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: () => ref
                          .read(calendarProvider.notifier)
                          .requestPermission(),
                    ),
                  ),
                _MonthHeader(
                  month: month,
                  onPrev: _prevMonth,
                  onNext: _nextMonth,
                  onToday: _goToday,
                ),
                _WeekdayRow(),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return Column(
                        children: [
                          SizedBox(
                            // Give grid roughly 60% of available height.
                            height: constraints.maxHeight * 0.72,
                            child: _MonthGrid(
                              month: month,
                              today: today,
                              eventsByDay: calState.eventsByDay,
                              selectedDay: _selectedDay,
                              onDayTap: (day) =>
                                  setState(() => _selectedDay = day),
                            ),
                          ),
                          const Divider(height: 1),
                          Expanded(
                            child: _DayDetailPanel(
                              selectedDay: _selectedDay ?? today,
                              events:
                                  calState.eventsByDay[_selectedDay ?? today] ??
                                  [],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildPermissionDenied() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.calendar_month_outlined, size: 64),
            const SizedBox(height: 16),
            const Text(
              'Ứng dụng cần quyền đọc lịch để hiển thị sự kiện.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () =>
                  ref.read(calendarProvider.notifier).requestPermission(),
              icon: const Icon(Icons.lock_open_outlined),
              label: const Text('Yêu cầu quyền đọc lịch'),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Month header
// ---------------------------------------------------------------------------

class _MonthHeader extends StatelessWidget {
  final DateTime month;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onToday;

  const _MonthHeader({
    required this.month,
    required this.onPrev,
    required this.onNext,
    required this.onToday,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: onPrev,
            tooltip: 'Tháng trước',
          ),
          Expanded(
            child: Text(
              _monthTitle(month),
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: onNext,
            tooltip: 'Tháng sau',
          ),
          TextButton(onPressed: onToday, child: const Text('Hôm nay')),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Weekday row (Mon–Sun, Vietnamese)
// ---------------------------------------------------------------------------

class _WeekdayRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: _viWeekHeaders
          .map(
            (h) => Expanded(
              child: Center(
                child: Text(
                  h,
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

// ---------------------------------------------------------------------------
// Month grid
// ---------------------------------------------------------------------------

class _MonthGrid extends StatelessWidget {
  final DateTime month;
  final DateTime today;
  final Map<DateTime, List<CalendarEvent>> eventsByDay;
  final DateTime? selectedDay;
  final ValueChanged<DateTime> onDayTap;

  const _MonthGrid({
    required this.month,
    required this.today,
    required this.eventsByDay,
    required this.selectedDay,
    required this.onDayTap,
  });

  @override
  Widget build(BuildContext context) {
    // First day of month.
    final firstOfMonth = DateTime(month.year, month.month, 1);
    // Monday=1, so offset: (weekday - 1) cells before day 1.
    final startOffset = (firstOfMonth.weekday - 1) % 7;
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    // Total cells: 6 rows × 7 columns
    const totalCells = 42;

    return LayoutBuilder(
      builder: (context, constraints) => GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 7,
          mainAxisExtent: constraints.maxHeight / 6,
        ),
        itemCount: totalCells,
        itemBuilder: (context, index) {
          final dayIndex = index - startOffset + 1;
          if (dayIndex < 1 || dayIndex > daysInMonth) {
            // Empty cell (outside current month).
            return const SizedBox.shrink();
          }
          final day = DateTime(month.year, month.month, dayIndex);
          final events = eventsByDay[day] ?? [];
          final isToday = day == today;
          final isSelected = day == selectedDay;
          return _DayCell(
            day: day,
            events: events,
            isToday: isToday,
            isSelected: isSelected,
            onTap: () => onDayTap(day),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Day cell
// ---------------------------------------------------------------------------

class _DayCell extends StatelessWidget {
  final DateTime day;
  final List<CalendarEvent> events;
  final bool isToday;
  final bool isSelected;
  final VoidCallback onTap;

  const _DayCell({
    required this.day,
    required this.events,
    required this.isToday,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final count = events.length;
    final shading = _shadingColor(context, count);
    final primary = Theme.of(context).colorScheme.primary;
    final onPrimary = Theme.of(context).colorScheme.onPrimary;
    final colorScheme = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final line = MediaQuery.textScalerOf(context).scale(11) + 4;
        final capacity = ((constraints.maxHeight - 30 - line) / line)
            .floor()
            .clamp(0, 2);
        final visibleEvents = events.take(capacity).toList();
        final overflow = count - visibleEvents.length;
        return GestureDetector(
          onTap: onTap,
          child: Container(
            margin: const EdgeInsets.all(1),
            decoration: BoxDecoration(
              color: shading,
              borderRadius: BorderRadius.circular(6),
              border: isSelected
                  ? Border.all(color: primary, width: 1.5)
                  : null,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Date number
                Container(
                  width: 22,
                  height: 22,
                  decoration: isToday
                      ? BoxDecoration(color: primary, shape: BoxShape.circle)
                      : null,
                  child: Center(
                    child: Text(
                      '${day.day}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isToday
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: isToday ? onPrimary : null,
                      ),
                    ),
                  ),
                ),
                // Event chips
                for (final e in visibleEvents) _EventChip(event: e),
                if (overflow > 0)
                  Text(
                    '+$overflow',
                    style: TextStyle(
                      fontSize: 9,
                      color: colorScheme.secondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _EventChip extends StatelessWidget {
  final CalendarEvent event;
  const _EventChip({required this.event});

  @override
  Widget build(BuildContext context) {
    final chipColor = event.color != 0
        ? Color(event.color | 0xFF000000)
        : Theme.of(context).colorScheme.secondary;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 1),
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
      decoration: BoxDecoration(
        color: chipColor.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        event.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 9, color: Colors.white),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Day detail panel
// ---------------------------------------------------------------------------

class _DayDetailPanel extends StatelessWidget {
  final DateTime selectedDay;
  final List<CalendarEvent> events;

  const _DayDetailPanel({required this.selectedDay, required this.events});

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('EEEE, d/M', 'vi');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            df.format(selectedDay),
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
        if (events.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Không có sự kiện',
              style: TextStyle(color: Colors.grey),
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              itemCount: events.length,
              itemBuilder: (context, i) {
                final event = events[i];
                final dotColor = event.color != 0
                    ? Color(event.color | 0xFF000000)
                    : Theme.of(context).colorScheme.secondary;
                return ListTile(
                  dense: true,
                  leading: CircleAvatar(backgroundColor: dotColor, radius: 6),
                  title: Text(event.title),
                  subtitle: Text(_eventTimeLabel(event)),
                );
              },
            ),
          ),
      ],
    );
  }
}
