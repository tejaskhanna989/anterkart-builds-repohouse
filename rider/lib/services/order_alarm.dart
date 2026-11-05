import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';

/// Looping audible alarm for new rider orders. Rings until [stop] is called
/// (rider taps Accept / Decline / dismisses the new-order dialog).
class OrderAlarm {
  OrderAlarm._();
  static final FlutterRingtonePlayer _player = FlutterRingtonePlayer();
  static bool _ringing = false;

  static bool get isRinging => _ringing;

  static Future<void> start() async {
    if (_ringing) return;
    _ringing = true;
    try {
      await _player.setReleaseMode(ReleaseMode.loop);
      await _player.playFromAsset('assets/audio/new_order_alarm.wav');
    } catch (_) {
      _ringing = false;
    }
  }

  static Future<void> stop() async {
    _ringing = false;
    try {
      await _player.stop();
    } catch (_) {}
  }
}