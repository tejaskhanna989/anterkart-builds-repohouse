import 'package:audioplayers/audioplayers.dart';

/// Looping audible alarm for new rider orders. Rings until [stop] is called
/// (rider taps Accept / Decline / dismisses the new-order dialog).
///
/// Uses the alarm usage type so it is audible over other sounds and keeps
/// the CPU awake while the screen is off.
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

  static Future<void> stop() async {
    _ringing = false;
    try {
      await _player.stop();
    } catch (_) {}
  }
}
