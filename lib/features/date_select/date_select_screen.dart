import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../../core/api_client.dart';
import '../log_entry/log_entry_screen.dart';

class DateSelectScreen extends StatefulWidget {
  const DateSelectScreen({super.key});

  @override
  State<DateSelectScreen> createState() => _DateSelectScreenState();
}

class _DateSelectScreenState extends State<DateSelectScreen> {
  final ApiClient _api = ApiClient();
  CalendarData? _calendarData;
  Set<String> _selectedDates = {};
  bool _loading = true;
  String? _error;
  DateTime _focusedDay = DateTime.now();
  CalendarFormat _calendarFormat = CalendarFormat.month;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final html = await _api.getCalendarPage();
    if (html == null) {
      setState(() {
        _error = 'Gagal mengambil data kalender';
        _loading = false;
      });
      return;
    }

    final data = _api.parseCalendar(html);
    setState(() {
      _calendarData = data;
      _loading = false;
    });
  }

  List<WorkDay> get _currentMonthWorkDays {
    if (_calendarData == null) return [];
    return _calendarData!.workDaysInMonth(_focusedDay.year, _focusedDay.month);
  }

  WorkDay? _getWorkDay(String dateStr) {
    return _currentMonthWorkDays.where((d) => d.date == dateStr).firstOrNull;
  }

  bool _isSelectable(DateTime day) {
    // Can't select future dates
    if (day.isAfter(DateTime.now())) return false;

    final dateStr = DateFormat('yyyy-MM-dd').format(day);
    final workDay = _getWorkDay(dateStr);

    // Can't select holidays or already filled
    if (workDay == null) return false;
    if (workDay.status == DayStatus.holiday) return false;
    if (workDay.status == DayStatus.filled) return false;

    // Only weekdays
    if (day.weekday == DateTime.saturday || day.weekday == DateTime.sunday) {
      return false;
    }

    return true;
  }

  void _toggleDate(DateTime day) {
    final dateStr = DateFormat('yyyy-MM-dd').format(day);
    setState(() {
      if (_selectedDates.contains(dateStr)) {
        _selectedDates.remove(dateStr);
      } else {
        _selectedDates.add(dateStr);
      }
    });
  }

  void _proceed() {
    if (_selectedDates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih minimal 1 tanggal')),
      );
      return;
    }

    final sortedDates = _selectedDates.toList()..sort();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LogEntryScreen(selectedDates: sortedDates),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pilih Tanggal'),
        actions: [
          TextButton.icon(
            onPressed: _selectedDates.isNotEmpty
                ? () {
                    setState(() {
                      _selectedDates.clear();
                    });
                  }
                : null,
            icon: const Icon(Icons.clear_all),
            label: const Text('Clear'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                      const SizedBox(height: 16),
                      Text(_error!),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadData,
                        child: const Text('Coba Lagi'),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // Calendar
                    Card(
                      margin: const EdgeInsets.all(12),
                      child: TableCalendar(
                        firstDay: DateTime(2024, 1, 1),
                        lastDay: DateTime(2026, 12, 31),
                        focusedDay: _focusedDay,
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
                        ),
                        calendarBuilders: CalendarBuilders(
                          defaultBuilder: (context, day, focusedDay) {
                            final dateStr = DateFormat('yyyy-MM-dd').format(day);
                            final isSelected = _selectedDates.contains(dateStr);
                            final workDay = _getWorkDay(dateStr);

                            Color? bgColor;
                            Color textColor = Colors.black87;

                            if (day.weekday == DateTime.saturday ||
                                day.weekday == DateTime.sunday) {
                              return Container(
                                margin: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade200,
                                  shape: BoxShape.circle,
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  '${day.day}',
                                  style: TextStyle(color: Colors.grey.shade500),
                                ),
                              );
                            }

                            if (workDay != null) {
                              switch (workDay.status) {
                                case DayStatus.filled:
                                  bgColor = Colors.green.shade100;
                                  textColor = Colors.green.shade800;
                                  break;
                                case DayStatus.unfilled:
                                  bgColor = _isSelectable(day)
                                      ? (isSelected ? Colors.blue.shade100 : Colors.orange.shade50)
                                      : Colors.grey.shade200;
                                  textColor = _isSelectable(day)
                                      ? Colors.black87
                                      : Colors.grey.shade500;
                                  break;
                                case DayStatus.holiday:
                                  bgColor = Colors.red.shade50;
                                  textColor = Colors.red.shade800;
                                  break;
                              }
                            } else {
                              bgColor = Colors.grey.shade200;
                              textColor = Colors.grey.shade500;
                            }

                            return GestureDetector(
                              onTap: _isSelectable(day) ? () => _toggleDate(day) : null,
                              child: Container(
                                margin: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: bgColor,
                                  shape: BoxShape.circle,
                                  border: isSelected
                                      ? Border.all(
                                          color: Theme.of(context).colorScheme.primary,
                                          width: 3,
                                        )
                                      : null,
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  '${day.day}',
                                  style: TextStyle(
                                    color: textColor,
                                    fontWeight: isSelected ? FontWeight.bold : null,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                        onDaySelected: (selectedDay, focusedDay) {
                          if (_isSelectable(selectedDay)) {
                            _toggleDate(selectedDay);
                            _focusedDay = focusedDay;
                          }
                        },
                        onFormatChanged: (format) {
                          setState(() {
                            _calendarFormat = format;
                          });
                        },
                        onPageChanged: (focusedDay) {
                          _focusedDay = focusedDay;
                        },
                      ),
                    ),

                    // Legend
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _LegendDot(color: Colors.orange.shade50, border: Colors.orange, label: 'Belum Terisi'),
                          const SizedBox(width: 16),
                          _LegendDot(color: Colors.green.shade100, border: Colors.green, label: 'Sudah Terisi'),
                          const SizedBox(width: 16),
                          _LegendDot(color: Colors.red.shade50, border: Colors.red, label: 'Libur'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Selected dates list
                    Expanded(
                      child: _selectedDates.isEmpty
                          ? Center(
                              child: Text(
                                'Klik tanggal untuk memilih',
                                style: TextStyle(color: Colors.grey.shade600),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(12),
                              itemCount: _selectedDates.length,
                              itemBuilder: (context, index) {
                                final dateStr = _selectedDates.toList()[index];
                                final date = DateTime.parse(dateStr);
                                return Card(
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: Theme.of(context).colorScheme.primary,
                                      child: Text(
                                        '${date.day}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    title: Text(
                                      DateFormat('EEEE, dd MMMM yyyy', 'id_ID').format(date),
                                    ),
                                    trailing: IconButton(
                                      icon: const Icon(Icons.remove_circle_outline),
                                      color: Colors.red,
                                      onPressed: () {
                                        setState(() {
                                          _selectedDates.remove(dateStr);
                                        });
                                      },
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),

                    // Proceed button
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: FilledButton.icon(
                        onPressed: _selectedDates.isNotEmpty ? _proceed : null,
                        icon: const Icon(Icons.arrow_forward),
                        label: Text(
                          'Lanjut (${_selectedDates.length} tanggal)',
                        ),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(50),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final Color border;
  final String label;

  const _LegendDot({
    required this.color,
    required this.border,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: border, width: 2),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }
}
