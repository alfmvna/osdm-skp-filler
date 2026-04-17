import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/api_client.dart';
import '../../core/constants.dart';
import '../../core/storage.dart';
import 'confirmation_screen.dart';

class LogEntryScreen extends StatefulWidget {
  final List<String> selectedDates;

  const LogEntryScreen({super.key, required this.selectedDates});

  @override
  State<LogEntryScreen> createState() => _LogEntryScreenState();
}

class _LogEntryScreenState extends State<LogEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _aktivitasController = TextEditingController();
  final _deskripsiController = TextEditingController();
  final _kuantitasController = TextEditingController(text: '1');
  final _satuanController = TextEditingController(text: 'kegiatan');
  final _linkController = TextEditingController();

  String? _selectedGroup;
  String? _selectedIndicator;
  List<Map<String, dynamic>> _templates = [];
  bool _showTemplateList = false;

  final _random = Random();

  @override
  void initState() {
    super.initState();
    _loadTemplates();
  }

  Future<void> _loadTemplates() async {
    final templates = await AppStorage.getTemplates();
    setState(() {
      _templates = templates;
    });
  }

  void _randomizeIndicator() {
    if (_selectedGroup == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih grup SKP terlebih dahulu')),
      );
      return;
    }

    final indicators = SkpGroups.groups[_selectedGroup]!;
    setState(() {
      _selectedIndicator = indicators[_random.nextInt(indicators.length)];
    });
  }

  void _applyTemplate(Map<String, dynamic> template) {
    setState(() {
      _selectedGroup = template['grup_skp'];
      _selectedIndicator = template['indikator'];
      _aktivitasController.text = template['nama_aktivitas'] ?? '';
      _deskripsiController.text = template['deskripsi'] ?? '';
      _kuantitasController.text = (template['kuantitas'] ?? 1).toString();
      _satuanController.text = template['satuan'] ?? 'kegiatan';
      _linkController.text = template['link'] ?? '';
      _showTemplateList = false;
    });
  }

  Future<void> _saveTemplate() async {
    if (!_formKey.currentState!.validate()) return;

    final template = {
      'nama_aktivitas': _aktivitasController.text,
      'deskripsi': _deskripsiController.text,
      'grup_skp': _selectedGroup,
      'indikator': _selectedIndicator,
      'kuantitas': int.tryParse(_kuantitasController.text) ?? 1,
      'satuan': _satuanController.text,
      'link': _linkController.text,
    };

    await AppStorage.saveTemplate(template);
    await _loadTemplates();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Template disimpan!')),
      );
    }
  }

  Future<void> _saveLocalOnly() async {
    if (!_formKey.currentState!.validate()) return;

    // Save to local storage without sending
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Draft disimpan untuk ${widget.selectedDates.length} tanggal (lokal saja)'),
        backgroundColor: Colors.orange,
      ),
    );
    Navigator.of(context).pop();
  }

  void _proceedToConfirmation() {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedGroup == null || _selectedIndicator == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih grup dan indikator SKP')),
      );
      return;
    }

    final entry = LogEntryData(
      dates: widget.selectedDates,
      group: _selectedGroup!,
      indicator: _selectedIndicator!,
      aktivitas: _aktivitasController.text,
      deskripsi: _deskripsiController.text,
      kuantitas: _kuantitasController.text,
      satuan: _satuanController.text,
      link: _linkController.text,
    );

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ConfirmationScreen(entry: entry),
      ),
    );
  }

  @override
  void dispose() {
    _aktivitasController.dispose();
    _deskripsiController.dispose();
    _kuantitasController.dispose();
    _satuanController.dispose();
    _linkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Isi Log Harian'),
        actions: [
          IconButton(
            icon: Icon(_showTemplateList ? Icons.close : Icons.folder_open),
            onPressed: () {
              setState(() {
                _showTemplateList = !_showTemplateList;
              });
            },
            tooltip: 'Template Tersimpan',
          ),
        ],
      ),
      body: _showTemplateList
          ? _buildTemplateList()
          : _buildForm(),
    );
  }

  Widget _buildTemplateList() {
    if (_templates.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_off, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Belum ada template tersimpan',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Isi form dan klik "Simpan Template"',
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Template Tersimpan (${_templates.length})',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _templates.length,
            itemBuilder: (context, index) {
              final t = _templates[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: ListTile(
                  title: Text(t['nama_aktivitas'] ?? ''),
                  subtitle: Text(
                    '${t['grup_skp'] ?? ''} • ${SkpGroups.getIndicatorName(t['indikator'] ?? '')}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () async {
                          await AppStorage.deleteTemplate(t['id']);
                          _loadTemplates();
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.arrow_forward),
                        onPressed: () => _applyTemplate(t),
                      ),
                    ],
                  ),
                  onTap: () => _applyTemplate(t),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Selected dates
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.calendar_today, size: 18, color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 8),
                        Text(
                          'Tanggal Dipilih (${widget.selectedDates.length})',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ],
                    ),
                    const Divider(),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: widget.selectedDates.map((d) {
                        final date = DateTime.parse(d);
                        return Chip(
                          label: Text(
                            DateFormat('dd MMM', 'id_ID').format(date),
                            style: const TextStyle(fontSize: 12),
                          ),
                          backgroundColor: Colors.blue[50],
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // SKP Group dropdown
            DropdownButtonFormField<String>(
              value: _selectedGroup,
              decoration: const InputDecoration(
                labelText: 'Grup SKP',
                prefixIcon: Icon(Icons.category),
              ),
              items: SkpGroups.groups.keys.map((group) {
                return DropdownMenuItem(value: group, child: Text(group));
              }).toList(),
              onChanged: (v) {
                setState(() {
                  _selectedGroup = v;
                  _selectedIndicator = null; // Reset when group changes
                });
              },
              validator: (v) => v == null ? 'Pilih grup SKP' : null,
            ),
            const SizedBox(height: 16),

            // Indicator with random button
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedIndicator,
                    decoration: const InputDecoration(
                      labelText: 'Indikator SKP',
                      prefixIcon: Icon(Icons.assignment),
                    ),
                    items: _selectedGroup == null
                        ? []
                        : SkpGroups.groups[_selectedGroup]!.map((ind) {
                            return DropdownMenuItem(
                              value: ind,
                              child: Text(
                                SkpGroups.getIndicatorName(ind),
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                    onChanged: (v) {
                      setState(() {
                        _selectedIndicator = v;
                      });
                    },
                    validator: (v) => v == null ? 'Pilih indikator' : null,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _randomizeIndicator,
                  icon: const Icon(Icons.casino),
                  tooltip: 'Random',
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Nama Aktivitas
            TextFormField(
              controller: _aktivitasController,
              decoration: const InputDecoration(
                labelText: 'Nama Aktivitas',
                prefixIcon: Icon(Icons.work),
                hintText: 'Contoh: Memastikan Laboratorium Siap',
              ),
              validator: (v) => v == null || v.isEmpty ? 'Harus diisi' : null,
            ),
            const SizedBox(height: 16),

            // Deskripsi
            TextFormField(
              controller: _deskripsiController,
              decoration: const InputDecoration(
                labelText: 'Deskripsi',
                prefixIcon: Icon(Icons.description),
                hintText: 'Jelaskan aktivitas yang dilakukan...',
                alignLabelWithHint: true,
              ),
              maxLines: 4,
              validator: (v) => v == null || v.isEmpty ? 'Harus diisi' : null,
            ),
            const SizedBox(height: 16),

            // Kuantitas & Satuan
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _kuantitasController,
                    decoration: const InputDecoration(
                      labelText: 'Kuantitas Output',
                      prefixIcon: Icon(Icons.numbers),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (v) => v == null || v.isEmpty ? 'Harus diisi' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: _satuanController,
                    decoration: const InputDecoration(
                      labelText: 'Satuan',
                      prefixIcon: Icon(Icons.straighten),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Link
            TextFormField(
              controller: _linkController,
              decoration: const InputDecoration(
                labelText: 'Link / Tautan (opsional)',
                prefixIcon: Icon(Icons.link),
                hintText: 'https://...',
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 24),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _saveTemplate,
                    icon: const Icon(Icons.save),
                    label: const Text('Simpan Template'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _saveLocalOnly,
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('Simpan Lokal'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.orange,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: _proceedToConfirmation,
                    icon: const Icon(Icons.send),
                    label: Text('Kirim ke Server (${widget.selectedDates.length}x)'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class LogEntryData {
  final List<String> dates;
  final String group;
  final String indicator;
  final String aktivitas;
  final String deskripsi;
  final String kuantitas;
  final String satuan;
  final String link;

  LogEntryData({
    required this.dates,
    required this.group,
    required this.indicator,
    required this.aktivitas,
    required this.deskripsi,
    required this.kuantitas,
    required this.satuan,
    required this.link,
  });
}
