import 'package:flutter/material.dart';
import '../services/audio_service.dart';
import '../services/settings_service.dart';
import '../theme/atelier.dart';
import 'menu_screen.dart';

/// Launch splash: game logo + name, animated loading line, credits.
/// Single splash only — the company logo rides along on the credits line.
class SplashScreen extends StatefulWidget {
  final WorkshopAudio audio;
  final WorkshopSettings settings;
  const SplashScreen({super.key, required this.audio, required this.settings});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _loader;

  @override
  void initState() {
    super.initState();
    _loader = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1700),
    );
    _run();
  }

  Future<void> _run() async {
    // Pre-warm audio while the splash shows, then start menu music.
    widget.audio.prewarm();
    widget.audio.startMenuMusic();
    _loader.forward();
    await Future.delayed(const Duration(milliseconds: 2100));
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => MenuScreen(
          audio: widget.audio,
          settings: widget.settings,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _loader.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.settings.theme;
    return Scaffold(
      backgroundColor: t.backdrop,
      body: WoodBackdrop(
        theme: t,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 190,
                height: 190,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: t.brass, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.65),
                      offset: const Offset(0, 12),
                      blurRadius: 26,
                    ),
                    BoxShadow(
                      color: t.spotlight.withValues(alpha: 0.25),
                      offset: const Offset(-4, -6),
                      blurRadius: 10,
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.asset('assets/slidingpuzzle_logo.png',
                    fit: BoxFit.cover),
              ),
              const SizedBox(height: 24),
              Text('SLIDING PUZZLE',
                  textAlign: TextAlign.center,
                  style: AtelierType.display(34, t)),
              const SizedBox(height: 8),
              Text('A RESTORATION OF ORDER',
                  style: AtelierType.label(13, t)),
              const SizedBox(height: 32),
              LoadingLine(theme: t, progress: _loader),
              const SizedBox(height: 12),
              AnimatedBuilder(
                animation: _loader,
                builder: (_, _) => Text(
                  _loader.value < 1 ? 'Uncrating the tiles…' : 'Ready!',
                  style: AtelierType.body(13, t,
                      color: t.parchment.withValues(alpha: 0.75)),
                ),
              ),
              const SizedBox(height: 48),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset('assets/wajiha_logo.png',
                      width: 30, height: 30, fit: BoxFit.contain),
                  const SizedBox(width: 10),
                  Text('Credits: WAJIHA', style: AtelierType.label(14, t)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
