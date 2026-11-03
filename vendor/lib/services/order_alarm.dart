import 'package:audioplayers/audioplayers.dart';

/// Looping audible alarm for new vendor orders. Rings until [stop] is called
/// (vendor taps Accept / View / dismisses the new-order dialog).
class OrderAlarm {
  OrderAlarm._();
  static final AudioPlayer _player = AudioPlayer();
  static bool _ringing = false;

  static bool get isRinging => _ringing;

  static Future<void> start() async {
    if (_ringing) return;
    _ringing = true;
    try {
      await _player.setReleaseMode(ReleaseMode.loop);
      await _player.play(AssetSource('audio/new_order_alarm.wav'));
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
