import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

/// Speelt de soundtrack: een naadloze hoofdloop waarvan het tempo meegaat
/// met de drukte, een percussielaag die opkomt bij drukte en bijna lege
/// cassettes, en een belletjes-sting wanneer een cassette leeg raakt.
///
/// Alle audiocalls zijn defensief: op platforms zonder audio-plugin
/// (flutter-tester, CI) wordt audio stil overgeslagen zodat de rest van de
/// app gewoon werkt.
class GameAudio {
  AudioPlayer? _music;
  AudioPlayer? _percussion;
  AudioPlayer? _sting;
  bool _muted = false;
  double _lastSpeed = 1.0;
  double _lastPercussion = 0.0;

  bool get muted => _muted;

  Future<void> init() async {
    try {
      final music = AudioPlayer();
      final percussion = AudioPlayer();
      final sting = AudioPlayer();
      await music.setAsset('assets/audio/loop_main.wav');
      await music.setLoopMode(LoopMode.one);
      await music.setVolume(0.5);
      await percussion.setAsset('assets/audio/loop_perc.wav');
      await percussion.setLoopMode(LoopMode.one);
      await percussion.setVolume(0.0);
      await sting.setAsset('assets/audio/sting_cassette_leeg.wav');
      await sting.setVolume(0.9);
      _music = music;
      _percussion = percussion;
      _sting = sting;
      unawaited(music.play());
      unawaited(percussion.play());
    } catch (e) {
      debugPrint('audio uitgeschakeld: $e');
      _music = null;
      _percussion = null;
      _sting = null;
    }
  }

  /// Neemt het nieuwe tempo en percussievolume over; kleine wijzigingen
  /// worden overgeslagen zodat er niet elke tick platform-calls lopen.
  void update({required double speed, required double percussionLevel}) {
    final music = _music;
    final percussion = _percussion;
    if (music == null || percussion == null) {
      return;
    }
    if ((speed - _lastSpeed).abs() > 0.01) {
      _lastSpeed = speed;
      unawaited(music.setSpeed(speed).catchError((_) {}));
      unawaited(percussion.setSpeed(speed).catchError((_) {}));
    }
    if ((percussionLevel - _lastPercussion).abs() > 0.05) {
      _lastPercussion = percussionLevel;
      if (!_muted) {
        unawaited(percussion.setVolume(percussionLevel).catchError((_) {}));
      }
    }
  }

  /// Sting bij een leeggetrokken cassette.
  void playCassetteEmpty() {
    final sting = _sting;
    if (sting == null || _muted) {
      return;
    }
    unawaited(sting.seek(Duration.zero).then((_) => sting.play()));
  }

  /// Audio-alert van de Storings-Analist (Ontwerper dd 2026-07-06) bij
  /// verhoogd storingsrisico op een cassette; hergebruikt de sting.
  void playJamRisk() => playCassetteEmpty();

  /// Zet alle audio aan of uit (volume, spelers blijven lopen zodat
  /// aanzetten direct weer klinkt).
  void setMuted(bool value) {
    _muted = value;
    unawaited(_music?.setVolume(value ? 0 : 0.5).catchError((_) {}));
    unawaited(
      _percussion?.setVolume(value ? 0 : _lastPercussion).catchError((_) {}),
    );
  }

  Future<void> dispose() async {
    await _music?.dispose();
    await _percussion?.dispose();
    await _sting?.dispose();
  }
}

final gameAudioProvider = Provider<GameAudio>((ref) {
  final audio = GameAudio();
  ref.onDispose(() => audio.dispose());
  return audio;
});
