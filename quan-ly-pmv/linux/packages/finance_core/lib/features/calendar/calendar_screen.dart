import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../app/theme.dart';
import 'calendar_models.dart';
import 'calendar_providers.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Day-only DateTime (no time component).
DateTime _dayOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

/// Returns the event-count shading color for a day cell per Data Contract:
/// 0: transparent
/// 1-2: 0.15 alpha
/// 3-5: 0.40 alpha
/// 6+: 0.70 alpha
Color _shadingColor(BuildContext context, int count) {
  final primary = Theme.of(context).colorScheme.primary;
  if (count == 0) return Colors.transparent;
  if (count <= 2) return primary.withValues(alpha: 0.15);
  if (count <= 5) return primary.withValues(alpha: 0.40);
  return primary.withValues(alpha: 0.70);
}

// Preserve calendar colors while keeping small labels readable on dense cells.
Color _readableForeground(Color background, Color preferred) {
  final bg = background.computeLuminance();
  final fg = preferred.computeLuminance();
  final ratio = ((bg > fg ? bg : fg) + 0.05) / ((bg > fg ? fg : bg) + 0.05);
  if (ratio >= 4.5) return preferred;
  final whiteRatio = 1.05 / (bg + 0.05);
  final blackRatio = (bg + 0.05) / 0.05;
  return whiteRatio >= blackRatio ? Colors.white : Colors.black;
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
    final colors = context.colors;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lịch'),
        actions: [
          IconButton(
            tooltip: 'Cài đặt lịch',
            icon: const Icon(Icons.tune_rounded),
            onPressed: () => context.push('/calendar/settings'),
          ),
        ],
      ),
      body: calState.permissionDenied && !calState.hasPermission
          ? _buildPermissionDenied(colors)
          : !calState.hasPermission
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (calState.loading)
                  LinearProgressIndicator(
                    minHeight: 2,
                    color: colors.primaryAccent,
                  ),
                if (calState.error != null)
                  Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: colors.expense.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 16,
                          color: colors.expense,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            calState.error!,
                            style: TextStyle(
                              fontSize: 12,
                              color: colors.expense,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.refresh, size: 18),
                          onPressed: () => ref
                              .read(calendarProvider.notifier)
                              .requestPermission(),
                        ),
                      ],
                    ),
                  ),
                _MonthHeader(
                  month: month,
                  onPrev: _prevMonth,
                  onNext: _nextMonth,
                  onToday: _goToday,
                ),
                _WeekdayRow(),
                const SizedBox(height: 4),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return Column(
                        children: [
                          SizedBox(
                            height: constraints.maxHeight * 0.68,
                            child: _MonthGrid(
                              month: month,
                              today: today,
                              eventsByDay: calState.eventsByDay,
                              selectedDay: _selectedDay,
                              onDayTap: (day) =>
                                  setState(() => _selectedDay = day),
                            ),
                          ),
                          Divider(
                            height: 1,
                            thickness: 1,
                            color: colors.borderSubtle,
                          ),
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

  Widget _buildPermissionDenied(AppThemeColors colors) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: colors.bgElevated,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.calendar_month_outlined,
                size: 32,
                color: colors.primaryAccent,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Ứng dụng cần quyền đọc lịch để hiển thị sự kiện từ Google Calendar.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () =>
                  ref.read(calendarProvider.notifier).requestPermission(),
              icon: const Icon(Icons.lock_open_outlined, size: 18),
              label: const Text('Cấp quyền đọc lịch'),
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
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.chevron_left_rounded, color: colors.textSecondary),
            onPressed: onPrev,
            tooltip: 'Tháng trước',
          ),
          Expanded(
            child: Text(
              _monthTitle(month),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.chevron_right_rounded,
              color: colors.textSecondary,
            ),
            onPressed: onNext,
            tooltip: 'Tháng sau',
          ),
          ActionChip(
            label: const Text('Hôm nay'),
            avatar: Icon(
              Icons.today_rounded,
              size: 14,
              color: colors.primaryAccent,
            ),
            onPressed: onToday,
            visualDensity: VisualDensity.compact,
            side: BorderSide(color: colors.borderSubtle),
          ),
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
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Row(
        children: _viWeekHeaders
            .map(
              (h) => Expanded(
                child: Center(
                  child: Text(
                    h,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: h == 'CN' ? colors.expense : colors.textMuted,
                    ),
                  ),
                ),
              ),
            )
            .toList(),
      ),
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
    final firstOfMonth = DateTime(month.year, month.month, 1);
    final startOffset = (firstOfMonth.weekday - 1) % 7;
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    const totalCells = 42;

    return LayoutBuilder(
      builder: (context, constraints) => GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 7,
          mainAxisExtent: constraints.maxHeight / 6,
        ),
        itemCount: totalCells,
        itemBuilder: (context, index) {
          final dayIndex = index - startOffset + 1;
          if (dayIndex < 1 || dayIndex > daysInMonth) {
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
    final cellBackground = Color.alphaBlend(
      shading,
      Theme.of(context).scaffoldBackgroundColor,
    );
    final primary = Theme.of(context).colorScheme.primary;
    final onPrimary = Theme.of(context).colorScheme.onPrimary;
    final colorScheme = Theme.of(context).colorScheme;
    final colors = context.colors;

    return LayoutBuilder(
      builder: (context, constraints) {
        final line = MediaQuery.textScalerOf(context).scale(11) + 4;
        final capacity = ((constraints.maxHeight - 28 - line) / line)
            .floor()
            .clamp(0, 2);
        final visibleEvents = events.take(capacity).toList();
        final overflow = count - visibleEvents.length;
        return GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Container(
            margin: const EdgeInsets.all(1.5),
            decoration: BoxDecoration(
              color: shading,
              borderRadius: BorderRadius.circular(8),
              border: isSelected
                  ? Border.all(color: primary, width: 2)
                  : Border.all(
                      color: colors.borderSubtle.withValues(alpha: 0.5),
                    ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Date number with Today indicator
                Container(
                  width: 24,
                  height: 24,
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
                            : (count > 0 ? FontWeight.w600 : FontWeight.normal),
                        color: isToday
                            ? onPrimary
                            : _readableForeground(
                                cellBackground,
                                day.weekday == DateTime.sunday
                                    ? colors.expense
                                    : colors.textPrimary,
                              ),
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
                      color: _readableForeground(
                        cellBackground,
                        colorScheme.secondary,
                      ),
                      fontWeight: FontWeight.w700,
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
        : Theme.of(context).colorScheme.primary;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 0.5),
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 0.5),
      decoration: BoxDecoration(
        color: chipColor,
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        event.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 9,
          color: _readableForeground(chipColor, Colors.white),
          fontWeight: FontWeight.w500,
        ),
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
    final colors = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                df.format(selectedDay),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
              ),
              if (events.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: colors.primaryAccent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${events.length} sự kiện',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: colors.primaryAccent,
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (events.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                Icon(
                  Icons.event_busy_outlined,
                  size: 16,
                  color: colors.textMuted,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Không có sự kiện nào trong ngày này.',
                    style: TextStyle(color: colors.textMuted, fontSize: 13),
                  ),
                ),
              ],
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              itemCount: events.length,
              itemBuilder: (context, i) {
                final event = events[i];
                final dotColor = event.color != 0
                    ? Color(event.color | 0xFF000000)
                    : colors.primaryAccent;
                return Card(
                  margin: const EdgeInsets.only(bottom: 6),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 2,
                    ),
                    dense: true,
                    leading: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: dotColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    title: Text(
                      event.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    subtitle: Text(
                      _eventTimeLabel(event),
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.textSecondary,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}
