import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';

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
    setState(() { _loading = true; _error = null; });
    try {
      final token = context.read<AuthProvider>().token;
      final res = await ApiService.get('vendor/orders/riders_schedule.php', auth: true);
      if (res['success'] == true) {
        setState(() {
          _riders = List<Map<String, dynamic>>.from(res['data']['riders']);
          _loading = false;
        });
      } else {
        setState(() { _error = res['message'] ?? 'Failed to load'; _loading = false; });
      }
    } catch (e) {
      setState(() { _error = 'Error: $e'; _loading = false; });
    }
  }

  Future<void> _saveSchedule(int riderId, int day, String start, String end, bool active) async {
    try {
      final res = await ApiService.post('vendor/orders/rider_schedule_save.php', auth: true, body: {
        'rider_id': riderId,
        'day_of_week': day,
        'start_time': start,
        'end_time': end,
        'is_active': active ? 1 : 0,
      });
      if (res['success'] != true) {
        _showSnack(res['message'] ?? 'Save failed', false);
      } else {
        _showSnack('Saved', true);
        _loadSchedules();
      }
    } catch (e) {
      _showSnack('Error: $e', false);
    }
  }

  Future<void> _deleteSchedule(int riderId, int day) async {
    try {
      final res = await ApiService.post('vendor/orders/rider_schedule_delete.php', auth: true, body: {
        'rider_id': riderId,
        'day_of_week': day,
      });
      if (res['success'] != true) {
        _showSnack(res['message'] ?? 'Delete failed', false);
      } else {
        _showSnack('Deleted', true);
        _loadSchedules();
      }
    } catch (e) {
      _showSnack('Error: $e', false);
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
                        rider: _riders[i],
                        days: _days,
                        onSave: _saveSchedule,
                        onDelete: _deleteSchedule,
                        onChanged: _loadSchedules,
                      ),
                    ),
    );
  }
}

class _RiderScheduleCard extends StatefulWidget {
  final Map<String, dynamic> rider;
  final List<String> days;
  final Function(int, int, String, String, bool) onSave;
  final Function(int, int) onDelete;
  final VoidCallback onChanged;

  const _RiderScheduleCard({
    required this.rider,
    required this.days,
    required this.onSave,
    required this.onDelete,
    required this.onChanged,
  });

  @override
  State<_RiderScheduleCard> createState() => _RiderScheduleCardState();
}

class _RiderScheduleCardState extends State<_RiderScheduleCard> {
  final Map<int, Map<String, dynamic>> _edits = {};
  final Map<int, bool> _expanded = {};

  Map<String, dynamic> _getSchedule(List<dynamic> schedules, int day) {
    try {
      return schedules.firstWhere((s) => s['day_of_week'] == day);
    } catch (_) {
      return {'start_time': '09:00', 'end_time': '22:00', 'is_active': false};
    }
  }

  @override
  Widget build(BuildContext context) {
    final rider = widget.rider;
    final schedules = List<Map<String, dynamic>>.from(rider['schedules'] ?? []);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: ExpansionTile(
        initiallyExpanded: false,
        title: Row(children: [
          CircleAvatar(child: Text(rider['name'][0])),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(rider['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
            Text('${rider['phone']} • ${rider['vehicle']}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ])),
          Chip(
            label: Text(rider['status'], style: const TextStyle(fontSize: 11)),
            backgroundColor: rider['status'] == 'active' ? Colors.green[50] : Colors.red[50],
            labelStyle: TextStyle(color: rider['status'] == 'active' ? Colors.green[800] : Colors.red[800]),
          ),
        ]),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(children: [
                  const SizedBox(width: 40),
                  const SizedBox(width: 100, child: Text('Start', style: TextStyle(fontWeight: FontWeight.bold))),
                  const SizedBox(width: 100, child: Text('End', style: TextStyle(fontWeight: FontWeight.bold))),
                  const SizedBox(width: 60, child: Text('Active', style: TextStyle(fontWeight: FontWeight.bold))),
                ]),
                ...List.generate(7, (day) {
                  final sched = _getSchedule(rider['schedules'] ?? [], day);
                  final isEditing = _edits.containsKey(day);
                  final startCtrl = TextEditingController(text: isEditing ? _edits[day]!['start'] : (sched['start_time']?.substring(0, 5) ?? '09:00'));
                  final endCtrl = TextEditingController(text: isEditing ? _edits[day]!['end'] : (sched['end_time']?.substring(0, 5) ?? '22:00'));
                  final active = isEditing ? _edits[day]!['active'] : (sched['is_active'] ?? false);

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(children: [
                      SizedBox(width: 40, child: Text(widget.days[day], style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
                      Expanded(
                        child: isEditing
                            ? Row(children: [
                                Expanded(child: TextField(controller: startCtrl, decoration: const InputDecoration(isDense: true, hintText: 'HH:MM'), keyboardType: TextInputType.datetime)),
                                const SizedBox(width: 8),
                                Expanded(child: TextField(controller: endCtrl, decoration: const InputDecoration(isDense: true, hintText: 'HH:MM'), keyboardType: TextInputType.datetime)),
                                Checkbox(value: active, onChanged: (v) => setState(() => _edits[day] = {'start': startCtrl.text, 'end': endCtrl.text, 'active': v ?? false})),
                              ])
                            : Row(children: [
                                SizedBox(width: 100, child: Text(sched['start_time']?.substring(0, 5) ?? '—', style: TextStyle(color: sched['is_active'] ? null : Colors.grey))),
                                SizedBox(width: 100, child: Text(sched['end_time']?.substring(0, 5) ?? '—', style: TextStyle(color: sched['is_active'] ? null : Colors.grey))),
                                Checkbox(value: sched['is_active'] ?? false, onChanged: null),
                              ]),
                    ]),
                  ),
                }),
                const SizedBox(height: 12),
                Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  TextButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Add Schedule'),
                    onPressed: () {
                      setState(() {
                        _edits[0] = {'start': '09:00', 'end': '22:00', 'active': true};
                      });
                    },
                  ),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
