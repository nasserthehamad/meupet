import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Topo do login: vídeo em loop do gatinho com as pinceladas e o logo
/// (igual ao protótipo). Mostra a primeira imagem enquanto o vídeo carrega.
class LoginHero extends StatefulWidget {
  /// Desligado nas prints automáticas (não há player de vídeo nos testes).
  static bool enableVideo = true;

  const LoginHero({super.key});

  @override
  State<LoginHero> createState() => _LoginHeroState();
}

class _LoginHeroState extends State<LoginHero> {
  VideoPlayerController? _c;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    if (!LoginHero.enableVideo) return;
    try {
      final c = VideoPlayerController.asset(
        'assets/video/login.mp4',
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );
      _c = c;
      c.initialize().then((_) async {
        await c.setVolume(0);
        await c.setLooping(true);
        await c.play();
        if (mounted) setState(() => _ready = true);
      }).catchError((Object _) {});
    } catch (_) {
      _c = null;
    }
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Proporção do vídeo recortado: 540 x 564
    return AspectRatio(
      aspectRatio: 540 / 564,
      child: Stack(fit: StackFit.expand, children: [
        Image.asset('assets/images/login_poster.jpg', fit: BoxFit.cover),
        if (_ready && _c != null)
          FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: _c!.value.size.width,
              height: _c!.value.size.height,
              child: VideoPlayer(_c!),
            ),
          ),
      ]),
    );
  }
}
