import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/api_client.dart';
import '../../core/constants.dart';
import 'log_entry_screen.dart';

class ConfirmationScreen extends StatefulWidget {
  final LogEntryData entry;

  const ConfirmationScreen({super.key, required this.entry});

  @override
  State<ConfirmationScreen> createState() => _ConfirmationScreenState();
}

class _ConfirmationScreenState extends State<ConfirmationScreen> {
  final _api = ApiClient();
  bool _submitting = false;
  final Map<String, bool> _results = {};
  final Map<String, String?> _errors = {};

  @override
  void initState() {
    super.initState();
    _startSubmit();
  }

  Future<void> _startSubmit() async {
    setState(() {
      _submitting = true;
    });

    for (final date in widget.entry.dates) {
      final result = await _api.submitLog(
        tanggal: date,
        namaAktivitas: widget.entry.aktivitas,
        deskripsi: widget.entry.deskripsi,
        indikator: widget.entry.indicator,
        kuantitas: widget.entry.kuantitas,
        satuan: widget.entry.satuan,
        link: widget.entry.link,
      );

      setState(() {
        _results[date] = result.success;
        _errors[date] = result.error;
      });
    }

    setState(() {
      _submitting = false;
    });
  }

  int get _successCount => _results.values.where((v) => v).length;
  int get _failCount => _results.values.where((v) => !v).length;
  int get _total => widget.entry.dates.length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Konfirmasi & Kirim'),
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Summary Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    if (_submitting) ...[
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text(
                        'Mengirim log... ($_successCount / $_total)',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ] else ...[
                      Icon(
                        _failCount == 0
                            ? Icons.check_circle
                            : _successCount == 0
                                ? Icons.error
                                : Icons.warning,
                        size: 48,
                        color: _failCount == 0
                            ? Colors.green
                            : _successCount == 0
                                ? Colors.red
                                : Colors.orange,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _failCount == 0
                            ? 'Semua Log Berhasil!'
                            : '$_successCount berhasil, $_failCount gagal',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Entry preview
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Preview:', style: Theme.of(context).textTheme.titleSmall),
                    const Divider(),
                    _PreviewRow(label: 'Grup SKP', value: widget.entry.group),
                    _PreviewRow(
                      label: 'Indikator',
                      value: SkpGroups.getIndicatorName(widget.entry.indicator),
                    ),
                    _PreviewRow(label: 'Aktivitas', value: widget.entry.aktivitas),
                    _PreviewRow(label: 'Kuantitas', value: '${widget.entry.kuantitas} ${widget.entry.satuan}'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Progress list
            Expanded(
              child: Card(
                child: ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: widget.entry.dates.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final date = widget.entry.dates[index];
                    final success = _results[date];
                    final error = _errors[date];

                    return ListTile(
                      leading: _buildResultIcon(success),
                      title: Text(
                        DateFormat('EEEE, dd MMMM yyyy', 'id_ID').format(DateTime.parse(date)),
                      ),
                      subtitle: _submitting
                          ? const Text('Mengirim...')
                          : error != null
                              ? Text(error, style: const TextStyle(color: Colors.red, fontSize: 12))
                              : null,
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Action buttons
            Row(
              children: [
                if (_submitting) ...[
                  Expanded(
                    child: Text(
                      'Jangan tutup aplikasi...',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ] else ...[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.of(context).popUntil((route) => route.isFirst);
                      },
                      child: const Text('Selesai'),
                    ),
                  ),
                  if (_failCount > 0) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () {
                          // Retry failed dates
                          final failedDates = _results.entries
                              .where((e) => !e.value)
                              .map((e) => e.key)
                              .toList();

                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(
                              builder: (_) => ConfirmationScreen(
                                entry: LogEntryData(
                                  dates: failedDates,
                                  group: widget.entry.group,
                                  indicator: widget.entry.indicator,
                                  aktivitas: widget.entry.aktivitas,
                                  deskripsi: widget.entry.deskripsi,
                                  kuantitas: widget.entry.kuantitas,
                                  satuan: widget.entry.satuan,
                                  link: widget.entry.link,
                                ),
                              ),
                            ),
                          );
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.orange,
                        ),
                        child: const Text('Coba Lagi Gagal'),
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultIcon(bool? success) {
    if (success == null) {
      return const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    return Icon(
      success ? Icons.check_circle : Icons.cancel,
      color: success ? Colors.green : Colors.red,
    );
  }
}

class _PreviewRow extends StatelessWidget {
  final String label;
  final String value;

  const _PreviewRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              '$label:',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
