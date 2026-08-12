import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

class SoundService {
  static final SoundService instance = SoundService._internal();
  factory SoundService() => instance;
  SoundService._internal();

  final AudioPlayer _player = AudioPlayer();

  Future<void> playNotificationSound() async {
    try {
      // Ensure we don't start multiple players
      await _player.stop();
      await _player.setReleaseMode(ReleaseMode.loop);
      await _player.play(AssetSource('sounds/alarm.mp3'));
    } catch (e) {
      debugPrint('Error playing sound: $e');
    }
  }

  Future<void> stopSound() async {
    try {
      await _player.stop();
    } catch (e) {
      debugPrint('Error stopping sound: $e');
    }
  }

  void dispose() {
    _player.dispose();
  }
}
