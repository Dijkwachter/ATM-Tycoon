import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

/// Speelt de lo-fi ambient-soundtrack (Ontwerper dd 2026-07-06,
/// vernieuwd audiosysteem): een rustige hoofdloop op constant tempo
/// (1,00x, geen tempo-veranderingen meer) met twee complementaire lagen
/// in exact hetzelfde tempo, dezelfde toonsoort en hetzelfde
/// arrangement, die via volumefading naadloos in- en uitmengen:
///
/// - de percussielaag (shakers) fadet in met de netwerkactiviteit;
/// - de pads-laag (warme melodielijn) fadet in wanneer er voertuigen
///   (CIT of monteurs) onderweg zijn.
///
/// Alerts zijn subtiel: een zacht lo-fi bliepje bij een lege cassette en
/// een mechanisch dubbelklikje van de Storings-Analist, beide binnen het
/// frequentiebereik van de muziek.
///
/// Alle audiocalls zijn defensief: op platforms zonder audio-plugin
/// (flutter-tester, CI) wordt audio stil overgeslagen zodat de rest van
/// de app gewoon werkt.
class GameAudio {
  AudioPlayer? _music;
  AudioPlayer? _percussion;
  AudioPlayer? _pads;
  AudioPlayer? _blip;
  AudioPlayer? _click;
  bool _muted = false;

  /// Doelvolumes van de fade-lagen en de daadwerkelijk toegepaste
  /// volumes; [update] beweegt per tick een stap naar het doel toe.
  double _percussionTarget = 0.0;
  double _padsTarget = 0.0;
  double _percussionVolume = 0.0;
  double _padsVolume = 0.0;

  /// Fractie van de resterende afstand die per update overbrugd wordt:
  /// een fade duurt zo enkele seconden (subtiel, geen sprongen).
  static const double _fadeStep = 0.22;

  static const double _musicVolume = 0.5;

  bool get muted => _muted;

  Future<void> init() async {
    try {
      final music = AudioPlayer();
      final percussion = AudioPlayer();
      final pads = AudioPlayer();
      final blip = AudioPlayer();
      final click = AudioPlayer();
      await music.setAsset('assets/audio/loop_main.wav');
      await music.setLoopMode(LoopMode.one);
      await music.setVolume(_musicVolume);
      await percussion.setAsset('assets/audio/loop_perc.wav');
      await percussion.setLoopMode(LoopMode.one);
      await percussion.setVolume(0.0);
      await pads.setAsset('assets/audio/loop_synth_pads.wav');
      await pads.setLoopMode(LoopMode.one);
      await pads.setVolume(0.0);
      await blip.setAsset('assets/audio/sting_cassette_leeg.wav');
      await blip.setVolume(0.8);
      await click.setAsset('assets/audio/sting_alert.wav');
      await click.setVolume(0.8);
      _music = music;
      _percussion = percussion;
      _pads = pads;
      _blip = blip;
      _click = click;
      unawaited(music.play());
      unawaited(percussion.play());
      unawaited(pads.play());
    } catch (e) {
      debugPrint('audio uitgeschakeld: $e');
      _music = null;
      _percussion = null;
      _pads = null;
      _blip = null;
      _click = null;
    }
  }

  /// Neemt de nieuwe doelvolumes van de lagen over en fadet er per
  /// aanroep (een keer per tick) een stap naartoe. Het tempo blijft
  /// altijd 1,00x; kleine volumewijzigingen worden overgeslagen zodat er
  /// niet elke tick platform-calls lopen.
  void update({required double percussionLevel, required double padsLevel}) {
    _percussionTarget = percussionLevel.clamp(0.0, 1.0);
    _padsTarget = padsLevel.clamp(0.0, 1.0);
    final percussion = _percussion;
    final pads = _pads;
    if (percussion == null || pads == null) {
      return;
    }
    _percussionVolume = _approach(_percussionVolume, _percussionTarget);
    _padsVolume = _approach(_padsVolume, _padsTarget);
    if (!_muted) {
      unawaited(percussion.setVolume(_percussionVolume).catchError((_) {}));
      unawaited(pads.setVolume(_padsVolume).catchError((_) {}));
    }
  }

  double _approach(double current, double target) {
    final next = current + (target - current) * _fadeStep;
    // Onder een half procent afstand mag de fade landen.
    return (next - target).abs() < 0.005 ? target : next;
  }

  /// Zacht lo-fi bliepje bij een leeggetrokken cassette.
  void playCassetteEmpty() => _playSting(_blip);

  /// Subtiel mechanisch dubbelklikje van de Storings-Analist bij
  /// verhoogd storingsrisico.
  void playJamRisk() => _playSting(_click);

  void _playSting(AudioPlayer? player) {
    if (player == null || _muted) {
      return;
    }
    unawaited(player.seek(Duration.zero).then((_) => player.play()));
  }

  /// Zet alle audio aan of uit (volume; de spelers blijven lopen zodat
  /// aanzetten direct weer klinkt).
  void setMuted(bool value) {
    _muted = value;
    unawaited(_music?.setVolume(value ? 0 : _musicVolume).catchError((_) {}));
    unawaited(
      _percussion?.setVolume(value ? 0 : _percussionVolume).catchError((_) {}),
    );
    unawaited(_pads?.setVolume(value ? 0 : _padsVolume).catchError((_) {}));
  }

  Future<void> dispose() async {
    await _music?.dispose();
    await _percussion?.dispose();
    await _pads?.dispose();
    await _blip?.dispose();
    await _click?.dispose();
  }
}

final gameAudioProvider = Provider<GameAudio>((ref) {
  final audio = GameAudio();
  ref.onDispose(() => audio.dispose());
  return audio;
});
