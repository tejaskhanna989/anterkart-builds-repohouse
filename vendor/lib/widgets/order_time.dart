/// Small helpers to render order timestamps (placed / updated / elapsed).
String formatClock(String raw) {
  if (raw.isEmpty) return '—';
  try {
    final dt = DateTime.parse(raw).toLocal();
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final ap = dt.hour < 12 ? 'AM' : 'PM';
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$h:$mm $ap';
  } catch (_) {
    return raw.length >= 16 ? raw.substring(11, 16) : raw;
  }
}

String elapsedSince(String raw) {
  if (raw.isEmpty) return '';
  try {
    final dt = DateTime.parse(raw).toLocal();
    final mins = DateTime.now().difference(dt).inMinutes;
    if (mins < 1) return 'just now';
    if (mins < 60) return '$mins min ago';
    final h = mins ~/ 60;
    if (h < 24) return '$h hr ${mins % 60} min ago';
    return '${h ~/ 24}d ago';
  } catch (_) {
    return '';
  }
}
