import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GameSoundService {
  static final GameSoundService _instance = GameSoundService._internal();
  factory GameSoundService() => _instance;
  GameSoundService._internal() {
    _loadSoundSetting();
  }

  bool _soundEnabled = true;
  bool _hapticEnabled = true;
  final Map<String, AudioPlayer> _players = {};

  bool get isSoundEnabled => _soundEnabled;
  bool get isHapticEnabled => _hapticEnabled;

  Future<void> _loadSoundSetting() async {
    final prefs = await SharedPreferences.getInstance();
    _soundEnabled = prefs.getBool('game_sound_enabled') ?? true;
    _hapticEnabled = prefs.getBool('game_haptic_enabled') ?? true;
  }

  Future<void> setSoundEnabled(bool enabled) async {
    _soundEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('game_sound_enabled', enabled);
  }

  Future<void> setHapticEnabled(bool enabled) async {
    _hapticEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('game_haptic_enabled', enabled);
  }

  /// Generates a synthesized 16-bit Mono PCM WAV file in memory
  Uint8List _generateWavBytes({
    required int sampleRate,
    required double durationSeconds,
    required double Function(double t) sampleGenerator,
  }) {
    final int numSamples = (sampleRate * durationSeconds).toInt();
    final int subChunk2Size = numSamples * 2; // 16-bit = 2 bytes
    final int chunkSize = 36 + subChunk2Size;

    final ByteData byteData = ByteData(44 + subChunk2Size);

    // RIFF header
    byteData.setUint8(0, 0x52); // 'R'
    byteData.setUint8(1, 0x49); // 'I'
    byteData.setUint8(2, 0x46); // 'F'
    byteData.setUint8(3, 0x46); // 'F'
    byteData.setUint32(4, chunkSize, Endian.little);
    byteData.setUint8(8, 0x57);  // 'W'
    byteData.setUint8(9, 0x41);  // 'A'
    byteData.setUint8(10, 0x56); // 'V'
    byteData.setUint8(11, 0x45); // 'E'

    // fmt subchunk
    byteData.setUint8(12, 0x66); // 'f'
    byteData.setUint8(13, 0x6D); // 'm'
    byteData.setUint8(14, 0x74); // 't'
    byteData.setUint8(15, 0x20); // ' '
    byteData.setUint32(16, 16, Endian.little); // Subchunk1Size (16 for PCM)
    byteData.setUint16(20, 1, Endian.little);  // AudioFormat (1 for PCM)
    byteData.setUint16(22, 1, Endian.little);  // NumChannels (1 mono)
    byteData.setUint32(24, sampleRate, Endian.little); // SampleRate
    byteData.setUint32(28, sampleRate * 2, Endian.little); // ByteRate
    byteData.setUint16(32, 2, Endian.little);  // BlockAlign (2 bytes)
    byteData.setUint16(34, 16, Endian.little); // BitsPerSample (16 bits)

    // data subchunk
    byteData.setUint8(36, 0x64); // 'd'
    byteData.setUint8(37, 0x61); // 'a'
    byteData.setUint8(38, 0x74); // 't'
    byteData.setUint8(39, 0x61); // 'a'
    byteData.setUint32(40, subChunk2Size, Endian.little);

    // Generate samples
    for (int i = 0; i < numSamples; i++) {
      final double t = i / sampleRate.toDouble();
      final double sample = sampleGenerator(t).clamp(-1.0, 1.0);
      final int intSample = (sample * 32767.0).round().clamp(-32768, 32767);
      byteData.setInt16(44 + (i * 2), intSample, Endian.little);
    }

    return byteData.buffer.asUint8List();
  }

  Future<void> _playBytes(String key, Uint8List wavBytes) async {
    if (!_soundEnabled) return;
    try {
      AudioPlayer? player = _players[key];
      if (player == null) {
        player = AudioPlayer();
        _players[key] = player;
      }
      final uri = Uri.dataFromBytes(wavBytes, mimeType: 'audio/wav');
      await player.setAudioSource(AudioSource.uri(uri));
      await player.play();
    } catch (e) {
      debugPrint('Sound play error: $e');
    }
  }

  // 1. Laser / Blaster Sound (Frequency sweep 800Hz -> 200Hz)
  Future<void> playLaser() async {
    if (_hapticEnabled) HapticFeedback.lightImpact();
    if (!_soundEnabled) return;
    final bytes = _generateWavBytes(
      sampleRate: 22050,
      durationSeconds: 0.12,
      sampleGenerator: (t) {
        final freq = 800.0 - (t / 0.12 * 600.0);
        final envelope = 1.0 - (t / 0.12);
        return math.sin(2 * math.pi * freq * t) * envelope * 0.7;
      },
    );
    await _playBytes('laser', bytes);
  }

  // 2. Explosion Sound (White noise with low-pass resonance & decay)
  Future<void> playExplosion() async {
    if (_hapticEnabled) HapticFeedback.heavyImpact();
    if (!_soundEnabled) return;
    final rng = math.Random();
    final bytes = _generateWavBytes(
      sampleRate: 22050,
      durationSeconds: 0.35,
      sampleGenerator: (t) {
        final noise = (rng.nextDouble() * 2.0 - 1.0);
        final envelope = math.exp(-t * 10.0);
        final rumble = math.sin(2 * math.pi * 60.0 * t);
        return (noise * 0.7 + rumble * 0.3) * envelope;
      },
    );
    await _playBytes('explosion', bytes);
  }

  // 3. Token Coin / Diamond Gem Chime (Two-tone high resonance 987Hz -> 1318Hz)
  Future<void> playCoin() async {
    if (_hapticEnabled) HapticFeedback.selectionClick();
    if (!_soundEnabled) return;
    final bytes = _generateWavBytes(
      sampleRate: 22050,
      durationSeconds: 0.22,
      sampleGenerator: (t) {
        final freq = t < 0.1 ? 987.77 : 1318.51;
        final envelope = 1.0 - (t / 0.22);
        return math.sin(2 * math.pi * freq * t) * envelope * 0.75;
      },
    );
    await _playBytes('coin', bytes);
  }

  // 4. Victory / Cashout Fanfare (Ascending major chords C5 -> E5 -> G5 -> C6)
  Future<void> playWin() async {
    if (_hapticEnabled) HapticFeedback.heavyImpact();
    if (!_soundEnabled) return;
    final notes = [523.25, 659.25, 783.99, 1046.50];
    final bytes = _generateWavBytes(
      sampleRate: 22050,
      durationSeconds: 0.5,
      sampleGenerator: (t) {
        final noteIdx = (t / 0.125).floor().clamp(0, 3);
        final freq = notes[noteIdx];
        final subT = (t % 0.125) / 0.125;
        final envelope = 1.0 - subT * 0.7;
        return (math.sin(2 * math.pi * freq * t) + 0.3 * math.sin(2 * math.pi * freq * 2 * t)) * envelope * 0.8;
      },
    );
    await _playBytes('win', bytes);
  }

  // 5. Defeat / Crash Sound (Descending dissonance)
  Future<void> playLose() async {
    if (_hapticEnabled) HapticFeedback.vibrate();
    if (!_soundEnabled) return;
    final bytes = _generateWavBytes(
      sampleRate: 22050,
      durationSeconds: 0.4,
      sampleGenerator: (t) {
        final freq = 350.0 - (t / 0.4 * 200.0);
        final envelope = math.exp(-t * 6.0);
        return (math.sin(2 * math.pi * freq * t) + 0.5 * math.sin(2 * math.pi * (freq * 1.05) * t)) * envelope * 0.75;
      },
    );
    await _playBytes('lose', bytes);
  }

  // 6. Wheel / Dice Click Tick
  Future<void> playTick() async {
    if (_hapticEnabled) HapticFeedback.selectionClick();
    if (!_soundEnabled) return;
    final bytes = _generateWavBytes(
      sampleRate: 22050,
      durationSeconds: 0.04,
      sampleGenerator: (t) {
        final freq = 1200.0;
        final envelope = 1.0 - (t / 0.04);
        return math.sin(2 * math.pi * freq * t) * envelope * 0.8;
      },
    );
    await _playBytes('tick', bytes);
  }

  // 7. Sniper High-Caliber Shot
  Future<void> playSniper() async {
    if (_hapticEnabled) HapticFeedback.heavyImpact();
    if (!_soundEnabled) return;
    final rng = math.Random();
    final bytes = _generateWavBytes(
      sampleRate: 22050,
      durationSeconds: 0.3,
      sampleGenerator: (t) {
        final crack = (rng.nextDouble() * 2.0 - 1.0);
        final sub = math.sin(2 * math.pi * 120.0 * t);
        final envelope = math.exp(-t * 14.0);
        return (crack * 0.8 + sub * 0.4) * envelope;
      },
    );
    await _playBytes('sniper', bytes);
  }

  // 8. Sword Slash / Dash
  Future<void> playSlash() async {
    if (_hapticEnabled) HapticFeedback.mediumImpact();
    if (!_soundEnabled) return;
    final bytes = _generateWavBytes(
      sampleRate: 22050,
      durationSeconds: 0.14,
      sampleGenerator: (t) {
        final freq = 600.0 + (t / 0.14 * 1200.0);
        final envelope = 1.0 - (t / 0.14);
        return math.sin(2 * math.pi * freq * t) * envelope * 0.7;
      },
    );
    await _playBytes('slash', bytes);
  }

  // 9. Magic Spell Cast (Shimmering sine modulation)
  Future<void> playMagic() async {
    if (_hapticEnabled) HapticFeedback.mediumImpact();
    if (!_soundEnabled) return;
    final bytes = _generateWavBytes(
      sampleRate: 22050,
      durationSeconds: 0.25,
      sampleGenerator: (t) {
        final carrier = math.sin(2 * math.pi * 880.0 * t);
        final modulator = math.sin(2 * math.pi * 24.0 * t);
        final envelope = 1.0 - (t / 0.25);
        return carrier * modulator * envelope * 0.8;
      },
    );
    await _playBytes('magic', bytes);
  }

  // 10. Hyperspace / Warp Jump Sound (Exponential frequency rise & sonic boom)
  Future<void> playHyperspace() async {
    if (_hapticEnabled) HapticFeedback.heavyImpact();
    if (!_soundEnabled) return;
    final rng = math.Random();
    final bytes = _generateWavBytes(
      sampleRate: 22050,
      durationSeconds: 0.7,
      sampleGenerator: (t) {
        if (t < 0.45) {
          final p = t / 0.45;
          final freq = 80.0 + (p * p * 1600.0);
          final mod = math.sin(2 * math.pi * 30.0 * t);
          final envelope = p * 0.85;
          return math.sin(2 * math.pi * freq * t) * (1.0 + 0.3 * mod) * envelope;
        } else {
          final p = (t - 0.45) / 0.25;
          final noise = (rng.nextDouble() * 2.0 - 1.0) * 0.5;
          final sub = math.sin(2 * math.pi * 65.0 * t);
          final envelope = math.exp(-p * 8.0);
          return (noise + sub * 0.7) * envelope;
        }
      },
    );
    await _playBytes('hyperspace', bytes);
  }

  // 11. Alien Tractor Beam / UFO Eerie Resonance
  Future<void> playAlienBeam() async {
    if (_hapticEnabled) HapticFeedback.selectionClick();
    if (!_soundEnabled) return;
    final bytes = _generateWavBytes(
      sampleRate: 22050,
      durationSeconds: 0.5,
      sampleGenerator: (t) {
        final carrierFreq = 440.0 + math.sin(2 * math.pi * 8.0 * t) * 120.0;
        final subFreq = 220.0 + math.cos(2 * math.pi * 16.0 * t) * 60.0;
        final envelope = math.sin(math.pi * (t / 0.5));
        return (math.sin(2 * math.pi * carrierFreq * t) * 0.6 +
                math.sin(2 * math.pi * subFreq * t) * 0.4) * envelope * 0.8;
      },
    );
    await _playBytes('alien_beam', bytes);
  }

  // 12. Shooting Star / Meteor Cosmic Whoosh
  Future<void> playShootingStar() async {
    if (_hapticEnabled) HapticFeedback.lightImpact();
    if (!_soundEnabled) return;
    final rng = math.Random();
    final bytes = _generateWavBytes(
      sampleRate: 22050,
      durationSeconds: 0.38,
      sampleGenerator: (t) {
        final p = t / 0.38;
        final chimeFreq = 1400.0 - (p * 700.0);
        final shimmer = math.sin(2 * math.pi * 40.0 * t);
        final air = (rng.nextDouble() * 2.0 - 1.0) * 0.25;
        final envelope = math.sin(math.pi * p);
        return (math.sin(2 * math.pi * chimeFreq * t) * (1.0 + 0.4 * shimmer) * 0.6 + air) * envelope * 0.75;
      },
    );
    await _playBytes('shooting_star', bytes);
  }

  // 13. Warship Super Laser Cannon Beam
  Future<void> playSuperLaser() async {
    if (_hapticEnabled) HapticFeedback.heavyImpact();
    if (!_soundEnabled) return;
    final rng = math.Random();
    final bytes = _generateWavBytes(
      sampleRate: 22050,
      durationSeconds: 0.6,
      sampleGenerator: (t) {
        if (t < 0.2) {
          // Charge-up hum
          final p = t / 0.2;
          final freq = 200.0 + (p * 1200.0);
          return math.sin(2 * math.pi * freq * t) * p * 0.6;
        } else {
          // Beam blast
          final p = (t - 0.2) / 0.4;
          final roar = (rng.nextDouble() * 2.0 - 1.0) * 0.6;
          final sub = math.sin(2 * math.pi * 90.0 * t);
          final laserSweep = math.sin(2 * math.pi * (1600.0 - p * 1200.0) * t);
          final envelope = math.exp(-p * 5.0);
          return (roar * 0.4 + sub * 0.4 + laserSweep * 0.4) * envelope * 0.9;
        }
      },
    );
    await _playBytes('super_laser', bytes);
  }

  // 14. Space Fleet Battle Salvo (Triple rapid plasma pulses)
  Future<void> playSpaceBattle() async {
    if (_hapticEnabled) HapticFeedback.mediumImpact();
    if (!_soundEnabled) return;
    final bytes = _generateWavBytes(
      sampleRate: 22050,
      durationSeconds: 0.45,
      sampleGenerator: (t) {
        final pulseTime = t % 0.15;
        final pulseP = pulseTime / 0.15;
        final freq = 900.0 - (pulseP * 650.0);
        final envelope = math.exp(-pulseP * 12.0);
        return math.sin(2 * math.pi * freq * pulseTime) * envelope * 0.8;
      },
    );
    await _playBytes('space_battle', bytes);
  }

  // 15. Limitless Level Up Fanfare (Ascending cyber arpeggio)
  Future<void> playLevelUp() async {
    if (_hapticEnabled) HapticFeedback.heavyImpact();
    if (!_soundEnabled) return;
    final notes = [440.0, 554.37, 659.25, 880.0, 1108.73, 1318.51];
    final bytes = _generateWavBytes(
      sampleRate: 22050,
      durationSeconds: 0.65,
      sampleGenerator: (t) {
        final noteIdx = (t / 0.10).floor().clamp(0, 5);
        final freq = notes[noteIdx];
        final subT = (t % 0.10) / 0.10;
        final envelope = 1.0 - subT * 0.5;
        final harmonic = 0.3 * math.sin(2 * math.pi * freq * 2.0 * t);
        return (math.sin(2 * math.pi * freq * t) + harmonic) * envelope * 0.85;
      },
    );
    await _playBytes('level_up', bytes);
  }

  // 16. Holo Deck UI Engage Chime
  Future<void> playHoloEngage() async {
    if (_hapticEnabled) HapticFeedback.selectionClick();
    if (!_soundEnabled) return;
    final bytes = _generateWavBytes(
      sampleRate: 22050,
      durationSeconds: 0.18,
      sampleGenerator: (t) {
        final p = t / 0.18;
        final freq = 1200.0 + (p * 800.0);
        final mod = math.sin(2 * math.pi * 60.0 * t);
        final envelope = 1.0 - p;
        return math.sin(2 * math.pi * freq * t) * (1.0 + 0.3 * mod) * envelope * 0.7;
      },
    );
    await _playBytes('holo_engage', bytes);
  }

  // 17. Outgoing dial tone (ringback) – classic 440 Hz + 480 Hz biresonant
  Future<void> playDialTone() async {
    if (!_soundEnabled) return;
    const int sampleRate = 22050;
    const double duration = 4.0; // 4 s loop chunk (caller loops this)
    final bytes = _generateWavBytes(
      sampleRate: sampleRate,
      durationSeconds: duration,
      sampleGenerator: (t) {
        // US ringback: 2 s on, 4 s off → simplified to 0.5 s on, 0.5 s off loop
        final cycle = (t % 1.0);
        if (cycle < 0.5) {
          // On: two-tone 440 Hz + 480 Hz
          final a = math.sin(2 * math.pi * 440.0 * t);
          final b = math.sin(2 * math.pi * 480.0 * t);
          return (a + b) * 0.35;
        }
        return 0.0; // Off
      },
    );
    await _playBytes('dial_tone', bytes);
  }

  // 18. Incoming ringtone – catchy sci-fi pulse melody
  Future<void> playRingtone() async {
    if (_hapticEnabled) HapticFeedback.vibrate();
    if (!_soundEnabled) return;
    const int sampleRate = 22050;
    const double duration = 3.0;
    final notes = [880.0, 1046.5, 880.0, 784.0, 880.0, 0.0, 880.0, 1046.5];
    final bytes = _generateWavBytes(
      sampleRate: sampleRate,
      durationSeconds: duration,
      sampleGenerator: (t) {
        final noteIdx = ((t / (duration / notes.length)).floor()).clamp(0, notes.length - 1);
        final freq = notes[noteIdx];
        if (freq == 0.0) return 0.0;
        final subT = (t % (duration / notes.length)) / (duration / notes.length);
        final envelope = (1.0 - subT * 0.6).clamp(0.0, 1.0);
        return math.sin(2 * math.pi * freq * t) * envelope * 0.75;
      },
    );
    await _playBytes('ringtone', bytes);
  }

  // 19. Call connected chime – warm ascending ding
  Future<void> playCallConnect() async {
    if (_hapticEnabled) HapticFeedback.lightImpact();
    if (!_soundEnabled) return;
    final bytes = _generateWavBytes(
      sampleRate: 22050,
      durationSeconds: 0.45,
      sampleGenerator: (t) {
        final p = t / 0.45;
        final freq = 880.0 + (p * 440.0);
        final envelope = math.exp(-t * 5.0);
        return math.sin(2 * math.pi * freq * t) * envelope * 0.9;
      },
    );
    await _playBytes('call_connect', bytes);
  }

  // 20. Call ended / disconnected – soft descending tone
  Future<void> playCallDisconnect() async {
    if (_hapticEnabled) HapticFeedback.mediumImpact();
    if (!_soundEnabled) return;
    final bytes = _generateWavBytes(
      sampleRate: 22050,
      durationSeconds: 0.55,
      sampleGenerator: (t) {
        final p = t / 0.55;
        final freq = 660.0 - (p * 260.0);
        final envelope = 1.0 - p;
        return math.sin(2 * math.pi * freq * t) * envelope * 0.75;
      },
    );
    await _playBytes('call_disconnect', bytes);
  }

  /// Stop any looping call audio (dial tone / ringtone)
  Future<void> stopCallAudio() async {
    for (final key in ['dial_tone', 'ringtone']) {
      final player = _players[key];
      if (player != null) {
        try {
          await player.stop();
        } catch (_) {}
      }
    }
  }

  void dispose() {
    for (final player in _players.values) {
      player.dispose();
    }
    _players.clear();
  }
}
