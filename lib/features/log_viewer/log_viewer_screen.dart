import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/api_client.dart';
import '../../core/constants.dart';

class LogViewerScreen extends StatefulWidget {
  const LogViewerScreen({super.key});

  @override
  State<LogViewerScreen> createState() => _LogViewerScreenState();
}

class _LogViewerScreenState extends State<LogViewerScreen> {
  final _api = ApiClient();
  List<WorkDay> _workDays = [];
  Map<String, LogEntry?> _logDetails = {};
  bool _loading = true;
  String? _error;
  DateTime _selectedMonth = DateTime.now();

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
        _error = 'Gagal mengambil data';
        _loading = false;
      });
      return;
    }

    final data = _api.parseCalendar(html);
    final filtered = data.workDays.where((d) {
      final date = d.dateTime;
      return date.year == _selectedMonth.year && date.month == _selectedMonth.month;
    }).toList();

    // Load details for filled days
    final details = <String, LogEntry?>{};
    for (final day in filtered.where((d) => d.status == DayStatus.filled)) {
      final logHtml = await _api.getLogData(day.date);
      if (logHtml != null) {
        details[day.date] = _api.parseLogEntry(logHtml);
      }
    }

    setState(() {
      _workDays = filtered;
      _logDetails = details;
      _loading = false;
    });
  }

  void _changeMonth(int delta) {
    setState(() {
      _selectedMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month + delta,
      );
    });
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final monthFormat = DateFormat('MMMM yyyy', 'id_ID');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lihat Log'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: Column(
        children: [
          // Month selector
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => _changeMonth(-1),
                ),
                Text(
                  monthFormat.format(_selectedMonth),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () => _changeMonth(1),
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: _loading
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
                    : _workDays.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.event_busy, size: 64, color: Colors.grey[400]),
                                const SizedBox(height: 16),
                                Text(
                                  'Tidak ada data untuk bulan ini',
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(12),
                            itemCount: _workDays.length,
                            itemBuilder: (context, index) {
                              final day = _workDays[index];
                              final log = day.status == DayStatus.filled
                                  ? _logDetails[day.date]
                                  : null;

                              return _DayCard(
                                day: day,
                                log: log,
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}

class _DayCard extends StatelessWidget {
  final WorkDay day;
  final LogEntry? log;

  const _DayCard({required this.day, this.log});

  @override
  Widget build(BuildContext context) {
    final date = day.dateTime;
    final dayName = DateFormat('EEEE', 'id_ID').format(date);
    final dateStr = DateFormat('dd MMMM yyyy', 'id_ID').format(date);

    Color statusColor;
    IconData statusIcon;
    String statusText;

    switch (day.status) {
      case DayStatus.filled:
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        statusText = 'Terisi';
        break;
      case DayStatus.unfilled:
        statusColor = Colors.grey;
        statusIcon = Icons.circle_outlined;
        statusText = 'Belum Terisi';
        break;
      case DayStatus.holiday:
        statusColor = Colors.red[300]!;
        statusIcon = Icons.event_busy;
        statusText = 'Libur';
        break;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: statusColor.withOpacity(0.2),
          child: Icon(statusIcon, color: statusColor, size: 20),
        ),
        title: Text(dateStr),
        subtitle: Text(
          log?.namaAktivitas ?? statusText,
          style: TextStyle(
            color: statusColor,
            fontSize: 12,
          ),
        ),
        trailing: day.status == DayStatus.filled
            ? const Icon(Icons.expand_more)
            : null,
        children: day.status == DayStatus.filled && log != null
            ? [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _DetailRow(label: 'Hari', value: dayName),
                      _DetailRow(
                        label: 'Aktivitas',
                        value: log!.namaAktivitas,
                      ),
                      _DetailRow(
                        label: 'Deskripsi',
                        value: log!.deskripsi.isNotEmpty
                            ? log!.deskripsi
                            : '-',
                      ),
                      _DetailRow(
                        label: 'Indikator SKP',
                        value: SkpGroups.getIndicatorNames()[log!.indikator] ??
                            log!.indikator,
                      ),
                      _DetailRow(
                        label: 'Status',
                        value: statusText,
                        valueColor: statusColor,
                      ),
                    ],
                  ),
                ),
              ]
            : [],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _DetailRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                color: valueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Extension to fix missing method
extension on SkpGroups {
  static Map<String, String> getIndicatorNames() => SkpGroups.indicatorNames;
}
