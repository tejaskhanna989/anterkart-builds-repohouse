import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/order_provider.dart';

/// Order chat with the delivery rider. Polls every 5s, sends instantly.
class ChatScreen extends StatefulWidget {
  final int orderId;
  final String title;
  final String myRole;
  const ChatScreen({super.key, required this.orderId, this.title = 'Chat', this.myRole = 'customer'});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final List<Map<String, dynamic>> _msgs = [];
  final TextEditingController _ctrl = TextEditingController();
  final ScrollController _scroll = ScrollController();
  Timer? _poll;
  bool _sending = false;


  @override
  void initState() {
    super.initState();
    _load(full: true);
    _poll = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) _load();
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  String get _myRole => widget.myRole;

  Future<void> _load({bool full = false}) async {
    final prov = context.read<OrderProvider>();
    final after = full || _msgs.isEmpty ? 0 : int.tryParse('${_msgs.last['id']}') ?? 0;
    final fresh = await prov.loadChat(widget.orderId, afterId: after);
    if (!mounted || fresh.isEmpty) return;
    setState(() {
      if (full) {
        _msgs
          ..clear()
          ..addAll(fresh);
      } else {
        final known = _msgs.map((m) => m['id']).toSet();
        for (final m in fresh) {
          if (!known.contains(m['id'])) _msgs.add(m);
        }
      }
    });
    _scrollToEnd();
  }

  void _scrollToEnd() {
    Future.delayed(const Duration(milliseconds: 150), () {
      if (!mounted || !_scroll.hasClients) return;
      try {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      } catch (_) {}
    });
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    final ok = await context.read<OrderProvider>().sendChat(widget.orderId, text);
    if (!mounted) return;
    setState(() => _sending = false);
    if (ok) {
      _ctrl.clear();
      _load();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Send failed'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Column(children: [
        Expanded(
          child: _msgs.isEmpty
              ? const Center(child: Text('No messages yet. Say hello!', style: TextStyle(color: Colors.grey)))
              : ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.all(12),
                  itemCount: _msgs.length,
                  itemBuilder: (_, i) {
                    final m = _msgs[i];
                    final mine = '${m['sender_role']}' == _myRole;
                    return Align(
                      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                        decoration: BoxDecoration(
                          color: mine ? const Color(0xFF2563EB) : Colors.grey[200],
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text('${m['message']}', style: TextStyle(color: mine ? Colors.white : Colors.black87, fontSize: 14)),
                      ),
                    );
                  },
                ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _send(),
                  decoration: const InputDecoration(hintText: 'Type a message…', border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(24)))),
                ),
              ),
              const SizedBox(width: 8),
              CircleAvatar(
                backgroundColor: const Color(0xFF2563EB),
                child: IconButton(
                  icon: _sending
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.send, color: Colors.white),
                  onPressed: _send,
                ),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}
