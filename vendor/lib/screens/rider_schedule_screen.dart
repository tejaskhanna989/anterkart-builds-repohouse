import 'package:flutter/material.dart';
import '../services/api_service.dart';

typedef RiderScheduleSaveCallback = Future<bool> Function(
  int riderId,
  int day,
  String start,
  String end,
  bool active,
);

typedef RiderScheduleDeleteCallback = Future<bool> Function(
  int riderId,
  int day,
);

class RiderScheduleScreen extends StatefulWidget {
  const RiderScheduleScreen({super.key});

  @override
  State<RiderScheduleScreen> createState() => _RiderScheduleScreenState();
}

class _RiderScheduleScreenState extends State<RiderScheduleScreen> {
  List<Map<String, dynamic>> _riders = [];
  bool _loading = true;
  String? _error;

  static const List<String> _days = [
    'Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'
  ];

  @override
  void initState() {
    super.initState();
    _loadSchedules();
  }

  Future<void> _loadSchedules() async {
    if (!mounted) return;
    setState(() { _loading = true; _error = null; });
    try {
      final res = await ApiService.get('vendor/riders_schedule.php', auth: true);
      if (!mounted) return;
      if (res['success'] == true) {
        setState(() {
          _riders = List<Map<String, dynamic>>.from(res['data']['riders'] ?? []);
          _loading = false;
        });
      } else {
        setState(() { _error = res['message'] ?? 'Failed to load'; _loading = false; });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = 'Error: $e'; _loading = false; });
    }
  }

  Future<bool> _saveSchedule(int riderId, int day, String start, String end, bool active) async {
    try {
      final res = await ApiService.post('vendor/rider_schedule_save.php', auth: true, body: {
        'rider_id': riderId,
        'day_of_week': day,
        'start_time': start,
        'end_time': end,
        'is_active': active ? 1 : 0,
      });
      if (res['success'] != true) {
        _showSnack(res['message'] ?? 'Save failed', false);
        return false;
      }
      _showSnack('Saved', true);
      await _loadSchedules();
      return true;
    } catch (e) {
      _showSnack('Error: $e', false);
      return false;
    }
  }

  Future<bool> _deleteSchedule(int riderId, int day) async {
    try {
      final res = await ApiService.post('vendor/rider_schedule_delete.php', auth: true, body: {
        'rider_id': riderId,
        'day_of_week': day,
      });
      if (res['success'] != true) {
        _showSnack(res['message'] ?? 'Delete failed', false);
        return false;
      }
      _showSnack('Deleted', true);
      await _loadSchedules();
      return true;
    } catch (e) {
      _showSnack('Error: $e', false);
      return false;
    }
  }

  void _showSnack(String msg, bool ok) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg), backgroundColor: ok ? Colors.green : Colors.red));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rider Schedules')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : _riders.isEmpty
                  ? const Center(child: Text('No riders found'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _riders.length,
                      itemBuilder: (_, i) => _RiderScheduleCard(
                        key: ValueKey(_riders[i]['id']),
                        rider: _riders[i],
                        days: _days,
                        onSave: _saveSchedule,
                        onDelete: _deleteSchedule,
                      ),
                    ),
    );
  }
}

class _RiderScheduleCard extends StatefulWidget {
  final Map<String, dynamic> rider;
  final List<String> days;
  final RiderScheduleSaveCallback onSave;
  final RiderScheduleDeleteCallback onDelete;

  const _RiderScheduleCard({
    super.key,
    required this.rider,
    required this.days,
    required this.onSave,
    required this.onDelete,
  });

  @override
  State<_RiderScheduleCard> createState() => _RiderScheduleCardState();
}

class _RiderScheduleCardState extends State<_RiderScheduleCard> {
  final Map<int, _ScheduleDraft> _drafts = {};
  int? _busyDay;

  @override
  void initState() {
    super.initState();
    _rebuildDrafts();
  }

  @override
  void didUpdateWidget(covariant _RiderScheduleCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rider != widget.rider) {
      _rebuildDrafts();
    }
  }

  @override
  void dispose() {
    for (final draft in _drafts.values) {
      draft.dispose();
    }
    super.dispose();
  }

  void _rebuildDrafts() {
    for (final draft in _drafts.values) {
      draft.dispose();
    }
    _drafts.clear();

    final schedules = List<Map<String, dynamic>>.from(widget.rider['schedules'] ?? []);
    for (var day = 0; day < 7; day++) {
      Map<String, dynamic>? schedule;
      for (final row in schedules) {
        if (int.tryParse('${row['day_of_week'] ?? ''}') == day) {
          schedule = row;
          break;
        }
      }
      _drafts[day] = _ScheduleDraft(
        startController: TextEditingController(text: _clock(schedule?['start_time'], '09:00')),
        endController: TextEditingController(text: _clock(schedule?['end_time'], '22:00')),
        active: _asBool(schedule?['is_active']),
        exists: schedule != null,
      );
    }
  }

  static String _clock(dynamic value, String fallback) {
    final text = '${value ?? ''}'.trim();
    if (text.length >= 5) return text.substring(0, 5);
    return fallback;
  }

  static bool _asBool(dynamic value) {
    return value == true || value == 1 || '${value ?? ''}' == '1';
  }

  bool _validTime(String value) {
    return RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').hasMatch(value);
  }

  Future<void> _save(int day) async {
    final draft = _drafts[day];
    if (draft == null) return;
    final start = draft.startController.text.trim();
    final end = draft.endController.text.trim();
    if (!_validTime(start) || !_validTime(end)) {
      _showLocalError('Use a valid 24-hour time in HH:MM format.');
      return;
    }

    setState(() { _busyDay = day; });
    await widget.onSave(
      int.tryParse('${widget.rider['id'] ?? ''}') ?? 0,
      day,
      start,
      end,
      draft.active,
    );
    if (!mounted) return;
    setState(() { _busyDay = null; });
  }

  Future<void> _delete(int day) async {
    final riderId = int.tryParse('${widget.rider['id'] ?? ''}') ?? 0;
    if (riderId <= 0) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${widget.days[day]} schedule?'),
        content: const Text('The rider will no longer be scheduled for this weekday.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() { _busyDay = day; });
    await widget.onDelete(riderId, day);
    if (!mounted) return;
    setState(() { _busyDay = null; });
  }

  void _showLocalError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: Colors.red,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final rider = widget.rider;
    final riderName = '${rider['name'] ?? 'Rider'}';
    final initial = riderName.isNotEmpty ? riderName[0].toUpperCase() : 'R';
    final status = '${rider['status'] ?? 'unknown'}';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: ExpansionTile(
        initiallyExpanded: false,
        title: Row(children: [
          CircleAvatar(child: Text(initial)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(riderName, style: const TextStyle(fontWeight: FontWeight.bold)),
            Text('${rider['phone'] ?? ''} • ${rider['vehicle'] ?? ''}',
              style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ])),
          Chip(
            label: Text(status, style: const TextStyle(fontSize: 11)),
            backgroundColor: status == 'active' ? Colors.green[50] : Colors.red[50],
            labelStyle: TextStyle(color: status == 'active' ? Colors.green[800] : Colors.red[800]),
          ),
        ]),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              children: [
                const Row(children: [
                  SizedBox(width: 76, child: Text('Day', style: TextStyle(fontWeight: FontWeight.bold))),
                  Expanded(child: Text('Start', style: TextStyle(fontWeight: FontWeight.bold))),
                  SizedBox(width: 8),
                  Expanded(child: Text('End', style: TextStyle(fontWeight: FontWeight.bold))),
                  SizedBox(width: 58, child: Text('Active', style: TextStyle(fontWeight: FontWeight.bold))),
                ]),
                const SizedBox(height: 6),
                ...List.generate(7, (day) {
                  final draft = _drafts[day];
                  if (draft == null) return const SizedBox.shrink();
                  final busy = _busyDay == day;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(children: [
                      SizedBox(
                        width: 76,
                        child: Text(widget.days[day], style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                      ),
                      Expanded(
                        child: TextField(
                          controller: draft.startController,
                          enabled: !busy,
                          decoration: const InputDecoration(isDense: true, hintText: '09:00'),
                          keyboardType: TextInputType.time,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: draft.endController,
                          enabled: !busy,
                          decoration: const InputDecoration(isDense: true, hintText: '22:00'),
                          keyboardType: TextInputType.time,
                        ),
                      ),
                      SizedBox(
                        width: 58,
                        child: Checkbox(
                          value: draft.active,
                          onChanged: busy ? null : (value) => setState(() => draft.active = value ?? false),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Save schedule',
                        onPressed: busy ? null : () => _save(day),
                        icon: busy
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.save_outlined),
                      ),
                      IconButton(
                        tooltip: draft.exists ? 'Delete schedule' : 'No schedule to delete',
                        onPressed: busy || !draft.exists ? null : () => _delete(day),
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ]),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ScheduleDraft {
  final TextEditingController startController;
  final TextEditingController endController;
  bool active;
  bool exists;

  _ScheduleDraft({
    required this.startController,
    required this.endController,
    required this.active,
    required this.exists,
  });

  void dispose() {
    startController.dispose();
    endController.dispose();
  }
}
