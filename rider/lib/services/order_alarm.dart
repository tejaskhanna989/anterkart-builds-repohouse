import 'package:audioplayers/audioplayers.dart';

/// Looping audible alarm for new rider orders. Rings until [stop] is called
/// (rider taps Accept / Decline / dismisses the new-order dialog).
///
/// Uses the alarm usage type so it is audible over other sounds and keeps
/// the CPU awake while the screen is off. The native alert ([AlertService])
/// forces the alarm stream to maximum; [stop] fades the sound out quickly so an
/// accepted offer is silenced instantly without an abrupt click.
class OrderAlarm {
  OrderAlarm._();

  static const String asset = 'audio/new_order_alarm.wav';

  static final AudioPlayer _player = AudioPlayer();
  static bool _ringing = false;

  static bool get isRinging => _ringing;

  static Future<void> start() async {
    if (_ringing) return;
    _ringing = true;
    try {
      await _player.setAudioContext(const AudioContext(
        android: AudioContextAndroid(
          stayAwake: true,
          contentType: AndroidContentType.sonification,
          usageType: AndroidUsageType.alarm,
          audioFocus: AndroidAudioFocus.gain,
        ),
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.playback,
          options: [AVAudioSessionOptions.duckOthers],
        ),
      ));
      await _player.setReleaseMode(ReleaseMode.loop);
      await _player.setVolume(1.0);
      await _player.play(AssetSource(asset));
    } catch (_) {
      // Missing asset / no audio device: never leave the alarm "ringing".
      _ringing = false;
    }
  }

  /// Stop the alarm. When [fade] is true the volume is ramped down over a few
  /// frames first, so tapping Accept silences the alarm instantly but cleanly.
  static Future<void> stop({bool fade = true}) async {
    final wasRinging = _ringing;
    _ringing = false;
    if (wasRinging && fade) {
      try {
        for (var i = 9; i >= 0; i--) {
          await _player.setVolume(i / 10);
          await Future<void>.delayed(const Duration(milliseconds: 18));
        }
      } catch (_) {}
    }
    try {
      await _player.stop();
    } catch (_) {}
    try {
      await _player.setVolume(1.0);
    } catch (_) {}
  }
}
