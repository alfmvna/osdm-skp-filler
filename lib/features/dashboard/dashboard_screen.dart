import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../../core/api_client.dart';
import '../auth/auth_cubit.dart';
import '../date_select/date_select_screen.dart';
import '../log_viewer/log_viewer_screen.dart';
import 'dashboard_cubit.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => DashboardCubit()..loadCalendar(),
      child: const _DashboardView(),
    );
  }
}

class _DashboardView extends StatefulWidget {
  const _DashboardView();

  @override
  State<_DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<_DashboardView> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  CalendarFormat _calendarFormat = CalendarFormat.month;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('OSDM SKP Filler'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              context.read<DashboardCubit>().loadCalendar();
            },
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'logout') {
                context.read<AuthCubit>().logout();
                Navigator.of(context).pop();
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, size: 20),
                    SizedBox(width: 8),
                    Text('Logout'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: BlocBuilder<DashboardCubit, DashboardState>(
        builder: (context, state) {
          if (state is DashboardLoading || state is DashboardInitial) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is DashboardError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                  const SizedBox(height: 16),
                  Text(state.message),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => context.read<DashboardCubit>().loadCalendar(),
                    child: const Text('Coba Lagi'),
                  ),
                ],
              ),
            );
          }

          final loaded = state as DashboardLoaded;
          final data = loaded.calendarData;
          // Filter data by selected month
          final monthWorkDays = data.workDaysInMonth(loaded.selectedMonth.year, loaded.selectedMonth.month);
          final monthFilled = monthWorkDays.where((d) => d.status == DayStatus.filled).toList();
          final monthUnfilled = monthWorkDays.where((d) => d.status == DayStatus.unfilled).toList();
          final monthHolidays = monthWorkDays.where((d) => d.status == DayStatus.holiday).toList();
          // Indonesian month names
          const indonesianMonths = [
            'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
            'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
          ];
          final monthName = indonesianMonths[loaded.selectedMonth.month - 1];
          final monthFormat = '$monthName ${loaded.selectedMonth.year}';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Summary Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.calendar_month, color: Theme.of(context).colorScheme.primary),
                            const SizedBox(width: 8),
                            Text(
                              'Log Harian - $monthFormat',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ],
                        ),
                        const Divider(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _StatChip(
                              label: 'Terisi',
                              value: '${monthFilled.length}',
                              color: Colors.green,
                              icon: Icons.check_circle,
                            ),
                            _StatChip(
                              label: 'Belum Terisi',
                              value: '${monthUnfilled.length}',
                              color: Colors.grey,
                              icon: Icons.circle_outlined,
                            ),
                            _StatChip(
                              label: 'Libur',
                              value: '${monthHolidays.length}',
                              color: Colors.red[300]!,
                              icon: Icons.event_busy,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Calendar
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: TableCalendar(
                      firstDay: DateTime(2024, 1, 1),
                      lastDay: DateTime(2026, 12, 31),
                      focusedDay: _focusedDay,
                      selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                      calendarFormat: _calendarFormat,
                      locale: 'id_ID',
                      headerStyle: const HeaderStyle(
                        formatButtonVisible: false,
                        titleCentered: true,
                      ),
                      calendarStyle: CalendarStyle(
                        todayDecoration: BoxDecoration(
                          color: Colors.blue[200],
                          shape: BoxShape.circle,
                        ),
                        selectedDecoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                        markerDecoration: const BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                      ),
                      calendarBuilders: CalendarBuilders(
                        defaultBuilder: (context, day, focusedDay) {
                          final dateStr = DateFormat('yyyy-MM-dd').format(day);
                          final workDay = monthWorkDays.where(
                            (d) => d.date == dateStr,
                          ).firstOrNull;

                          Color? bgColor;
                          Color textColor = Colors.black87;

                          if (workDay != null) {
                            switch (workDay.status) {
                              case DayStatus.filled:
                                bgColor = Colors.green[50];
                                textColor = Colors.green[800]!;
                                break;
                              case DayStatus.unfilled:
                                bgColor = Colors.grey[100];
                                textColor = Colors.grey[800]!;
                                break;
                              case DayStatus.holiday:
                                bgColor = Colors.red[50];
                                textColor = Colors.red[800]!;
                                break;
                            }
                          }

                          return Container(
                            margin: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: bgColor,
                              shape: BoxShape.circle,
                              border: workDay != null
                                  ? Border.all(color: bgColor!, width: 2)
                                  : null,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '${day.day}',
                              style: TextStyle(color: textColor),
                            ),
                          );
                        },
                      ),
                      onDaySelected: (selectedDay, focusedDay) {
                        setState(() {
                          _selectedDay = selectedDay;
                          _focusedDay = focusedDay;
                        });
                        // Show log details for selected date
                        _showLogDetails(context, selectedDay, monthWorkDays);
                      },
                      onFormatChanged: (format) {
                        setState(() {
                          _calendarFormat = format;
                        });
                      },
                      onPageChanged: (focusedDay) {
                        _focusedDay = focusedDay;
                        context.read<DashboardCubit>().changeMonth(focusedDay);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Legend
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _LegendItem(color: Colors.green[50]!, text: 'Terisi', border: Colors.green),
                        _LegendItem(color: Colors.grey[100]!, text: 'Belum Terisi', border: Colors.grey),
                        _LegendItem(color: Colors.red[50]!, text: 'Libur', border: Colors.red[300]!),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const DateSelectScreen(),
                            ),
                          ).then((_) {
                            // Refresh on return
                            context.read<DashboardCubit>().loadCalendar();
                          });
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Isi Log Baru'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const LogViewerScreen(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.list_alt),
                        label: const Text('Lihat Log'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Unfilled days list
                if (monthUnfilled.isNotEmpty) ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.warning_amber, color: Colors.orange[700], size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'Tanggal Belum Terisi - $monthFormat',
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                            ],
                          ),
                          const Divider(),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: monthUnfilled.map((d) {
                              final date = d.dateTime;
                              return Chip(
                                avatar: const Icon(Icons.circle_outlined, size: 16),
                                label: Text(
                                  DateFormat('dd MMM', 'id_ID').format(date),
                                  style: const TextStyle(fontSize: 12),
                                ),
                                backgroundColor: Colors.grey[100],
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  void _showLogDetails(BuildContext context, DateTime date, List<WorkDay> monthWorkDays) {
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    final workDay = monthWorkDays.where((d) => d.date == dateStr).firstOrNull;

    if (workDay == null) {
      // No log entry for this date
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Tidak ada log untuk ${DateFormat('dd MMM yyyy', 'id_ID').format(date)}'),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    // Show simple dialog with log details
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(DateFormat('dd MMMM yyyy', 'id_ID').format(date)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DetailRow('Status', _getStatusText(workDay.status)),
            const SizedBox(height: 8),
            _DetailRow('Aktivitas', workDay.title),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  String _getStatusText(DayStatus status) {
    switch (status) {
      case DayStatus.filled:
        return 'Terisi ✓';
      case DayStatus.unfilled:
        return 'Belum Terisi';
      case DayStatus.holiday:
        return 'Libur';
    }
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String text;
  final Color border;

  const _LegendItem({
    required this.color,
    required this.text,
    required this.border,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: border, width: 2),
          ),
        ),
        const SizedBox(width: 6),
        Text(text, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            '$label:',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
        ),
        Expanded(child: Text(value)),
      ],
    );
  }
}
