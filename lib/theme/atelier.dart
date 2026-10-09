import 'package:flutter/material.dart';

/// Atelier Conservator — pseudo-3D museum restoration workshop materials.
///
/// Everything lives in the warm oak / brass / parchment range. No neon,
/// no flat Material cards. Depth comes from layered shadows, bevel
/// highlights and subtle ambient occlusion painted by hand.
class AtelierTheme {
  final String id;
  final String name;
  final bool isPro;
  final Color woodDark; // deep walnut frame shadow
  final Color woodMid; // aged oak frame body
  final Color woodLight; // waxed oak bevel highlight
  final Color backdrop; // dark walnut workbench
  final Color canvasFace; // aged linen tile face
  final Color canvasEdge; // tile side wall / backing board
  final Color numeral; // engraved numeral ink
  final Color brass; // patinated brass body
  final Color brassLight; // brass specular
  final Color brassDark; // brass recess
  final Color recess; // empty-slot well
  final Color parchment; // stats slips
  final Color inkBrown; // carved lettering
  final Color spotlight; // warm top-left light wash

  const AtelierTheme({
    required this.id,
    required this.name,
    this.isPro = false,
    required this.woodDark,
    required this.woodMid,
    required this.woodLight,
    required this.backdrop,
    required this.canvasFace,
    required this.canvasEdge,
    required this.numeral,
    required this.brass,
    required this.brassLight,
    required this.brassDark,
    required this.recess,
    required this.parchment,
    required this.inkBrown,
    required this.spotlight,
  });
}

/// Engraved / carved text styles. Heavy weights + letter spacing fake the
/// incised letterforms; no bundled serif font needed.
class AtelierType {
  static TextStyle display(double size, AtelierTheme t) => TextStyle(
        fontSize: size,
        fontWeight: FontWeight.w900,
        letterSpacing: 2.5,
        color: t.brassLight,
        shadows: [
          Shadow(
              color: Colors.black.withValues(alpha: 0.65),
              offset: const Offset(0, 2),
              blurRadius: 3),
          Shadow(
              color: t.brassDark.withValues(alpha: 0.9),
              offset: const Offset(0, -1),
              blurRadius: 1),
        ],
      );

  static TextStyle plaqueTitle(double size, AtelierTheme t) => TextStyle(
        fontSize: size,
        fontWeight: FontWeight.w800,
        letterSpacing: 3.0,
        color: t.inkBrown,
        shadows: [
          Shadow(
              color: t.brassLight.withValues(alpha: 0.8),
              offset: const Offset(0, 1),
              blurRadius: 0),
        ],
      );

  static TextStyle label(double size, AtelierTheme t, {Color? color}) =>
      TextStyle(
        fontSize: size,
        fontWeight: FontWeight.w700,
        letterSpacing: 2.2,
        color: color ?? t.parchment.withValues(alpha: 0.85),
      );

  static TextStyle body(double size, AtelierTheme t, {Color? color}) =>
      TextStyle(
        fontSize: size,
        fontWeight: FontWeight.w500,
        color: color ?? t.parchment,
        height: 1.45,
      );

  static TextStyle numeral(double size, AtelierTheme t) => TextStyle(
        fontSize: size,
        fontWeight: FontWeight.w900,
        color: t.numeral,
        shadows: [
          Shadow(
              color: t.canvasFace.withValues(alpha: 0.9),
              offset: const Offset(0, 1),
              blurRadius: 0),
          Shadow(
              color: Colors.black.withValues(alpha: 0.45),
              offset: const Offset(0, -1),
              blurRadius: 2),
        ],
      );
}

// ---------------------------------------------------------------------------
// Wood grain + canvas weave painters (cheap, physical, no image assets).
// ---------------------------------------------------------------------------

class _GrainPainter extends CustomPainter {
  final Color base;
  _GrainPainter(this.base);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.stroke;
    // Long wavy vertical grain strokes with varying alpha.
    for (int i = 0; i < 46; i++) {
      final x = (i / 46) * size.width + (i % 3) * 2.0;
      final alpha = 0.04 + (i % 5) * 0.012;
      paint.color = base.withValues(alpha: alpha);
      paint.strokeWidth = 1.0 + (i % 3) * 0.7;
      final path = Path()..moveTo(x, 0);
      for (double y = 0; y <= size.height; y += size.height / 8) {
        path.quadraticBezierTo(
          x + ((i * 7 + y) % 13) - 6,
          y + size.height / 16,
          x,
          y + size.height / 8,
        );
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GrainPainter old) => old.base != base;
}

class _WeavePainter extends CustomPainter {
  final Color line;
  _WeavePainter(this.line);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = line.withValues(alpha: 0.10)
      ..strokeWidth = 1;
    const step = 7.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _WeavePainter old) => old.line != line;
}

/// Full-screen dark-walnut workbench: grain + warm top-left spotlight wash.
class WoodBackdrop extends StatelessWidget {
  final AtelierTheme theme;
  final Widget child;
  const WoodBackdrop({super.key, required this.theme, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: theme.backdrop),
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(painter: _GrainPainter(theme.woodDark)),
          ),
          // Museum spotlight from the top-left (~135 deg throw).
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(-0.75, -0.85),
                  radius: 1.35,
                  colors: [
                    theme.spotlight.withValues(alpha: 0.16),
                    theme.spotlight.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          // Deep vignette toward the edges.
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.05,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.42),
                  ],
                  stops: const [0.55, 1.0],
                ),
              ),
            ),
          ),
          Positioned.fill(child: child),
        ],
      ),
    );
  }
}

/// Brass name plaque with incised lettering and soft reflections.
class BrassPlaque extends StatelessWidget {
  final AtelierTheme theme;
  final String text;
  final double fontSize;
  final EdgeInsets padding;
  const BrassPlaque({
    super.key,
    required this.theme,
    required this.text,
    this.fontSize = 15,
    this.padding = const EdgeInsets.symmetric(horizontal: 26, vertical: 12),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [theme.brassLight, theme.brass, theme.brassDark],
          stops: const [0.0, 0.55, 1.0],
        ),
        border: Border.all(color: theme.brassDark, width: 1.5),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.55),
              offset: const Offset(0, 4),
              blurRadius: 8),
          BoxShadow(
              color: theme.spotlight.withValues(alpha: 0.35),
              offset: const Offset(-2, -2),
              blurRadius: 4),
        ],
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: AtelierType.plaqueTitle(fontSize, theme),
      ),
    );
  }
}

/// Aged-oak menu button with brass rim. Press = physical depression.
class OakButton extends StatefulWidget {
  final AtelierTheme theme;
  final String label;
  final String? sublabel;
  final VoidCallback? onTap;
  final double fontSize;
  const OakButton({
    super.key,
    required this.theme,
    required this.label,
    this.sublabel,
    this.onTap,
    this.fontSize = 17,
  });

  @override
  State<OakButton> createState() => _OakButtonState();
}

class _OakButtonState extends State<OakButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap?.call();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 90),
        width: double.infinity,
        padding: EdgeInsets.symmetric(
            horizontal: 20, vertical: widget.sublabel == null ? 16 : 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: _pressed
                ? [t.woodDark, t.woodMid]
                : [t.woodLight, t.woodMid, t.woodDark],
            stops: _pressed ? const [0.0, 1.0] : const [0.0, 0.5, 1.0],
          ),
          border: Border.all(color: t.brass, width: 2),
          boxShadow: _pressed
              ? [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.6),
                      offset: const Offset(0, 1),
                      blurRadius: 3,
                      blurStyle: BlurStyle.inner),
                ]
              : [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.55),
                      offset: const Offset(0, 5),
                      blurRadius: 10),
                  BoxShadow(
                      color: t.spotlight.withValues(alpha: 0.25),
                      offset: const Offset(0, -2),
                      blurRadius: 3),
                ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.label,
                textAlign: TextAlign.center,
                style: AtelierType.display(widget.fontSize, t)),
            if (widget.sublabel != null) ...[
              const SizedBox(height: 4),
              Text(widget.sublabel!,
                  textAlign: TextAlign.center,
                  style: AtelierType.label(11, t)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Round brass control button with an engraved icon glyph.
class BrassRoundButton extends StatefulWidget {
  final AtelierTheme theme;
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final double size;
  final bool highlighted;
  const BrassRoundButton({
    super.key,
    required this.theme,
    required this.icon,
    required this.tooltip,
    this.onTap,
    this.size = 58,
    this.highlighted = false,
  });

  @override
  State<BrassRoundButton> createState() => _BrassRoundButtonState();
}

class _BrassRoundButtonState extends State<BrassRoundButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    return Tooltip(
      message: widget.tooltip,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) {
          setState(() => _pressed = false);
          widget.onTap?.call();
        },
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 90),
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: _pressed
                  ? [t.brassDark, t.brass]
                  : [t.brassLight, t.brass, t.brassDark],
              stops: _pressed ? const [0.0, 1.0] : const [0.0, 0.55, 1.0],
            ),
            border: Border.all(
                color: widget.highlighted ? t.spotlight : t.brassDark,
                width: widget.highlighted ? 3 : 1.5),
            boxShadow: _pressed
                ? [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.55),
                        offset: const Offset(0, 1),
                        blurRadius: 4,
                        blurStyle: BlurStyle.inner),
                  ]
                : [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.6),
                        offset: const Offset(0, 5),
                        blurRadius: 10),
                    BoxShadow(
                        color: t.spotlight.withValues(alpha: 0.4),
                        offset: const Offset(-2, -3),
                        blurRadius: 4),
                  ],
          ),
          child: Icon(widget.icon,
              color: t.inkBrown,
              size: widget.size * 0.42,
              shadows: [
                Shadow(
                    color: t.brassLight.withValues(alpha: 0.7),
                    offset: const Offset(0, 1),
                    blurRadius: 0),
              ]),
        ),
      ),
    );
  }
}

/// Brass lever toggle — physical hardware, never a flat switch.
class LeverToggle extends StatelessWidget {
  final AtelierTheme theme;
  final bool value;
  final ValueChanged<bool> onChanged;
  const LeverToggle(
      {super.key,
      required this.theme,
      required this.value,
      required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Container(
        width: 74,
        height: 36,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [t.woodDark, t.recess],
          ),
          border: Border.all(color: t.brassDark, width: 1.5),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.6),
                offset: const Offset(0, 2),
                blurRadius: 4,
                blurStyle: BlurStyle.inner),
          ],
        ),
        child: Stack(
          children: [
            AnimatedAlign(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOutBack,
              alignment:
                  value ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                width: 34,
                height: 34,
                margin: const EdgeInsets.all(1),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: value
                        ? [t.brassLight, t.brass]
                        : [t.woodLight, t.woodMid],
                  ),
                  border: Border.all(color: t.brassDark, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        offset: const Offset(0, 2),
                        blurRadius: 4),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Animated loading line (brass fill on a recessed track).
class LoadingLine extends StatelessWidget {
  final AtelierTheme theme;
  final Animation<double> progress;
  final double width;
  const LoadingLine(
      {super.key,
      required this.theme,
      required this.progress,
      this.width = 220});

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return SizedBox(
      width: width,
      child: AnimatedBuilder(
        animation: progress,
        builder: (_, _) => Container(
          height: 8,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            color: t.recess,
            border: Border.all(color: t.brassDark.withValues(alpha: 0.7)),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.6),
                  offset: const Offset(0, 1),
                  blurRadius: 2,
                  blurStyle: BlurStyle.inner),
            ],
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: progress.value.clamp(0.02, 1.0),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                gradient: LinearGradient(
                  colors: [t.brassLight, t.brass],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Brass star medallion that stamps in on the victory screen.
class StarMedallion extends StatelessWidget {
  final AtelierTheme theme;
  final bool earned;
  final double size;
  const StarMedallion(
      {super.key, required this.theme, required this.earned, this.size = 52});

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: earned ? 1.6 : 1.0, end: 1.0),
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutBack,
      builder: (_, s, _) => Transform.scale(
        scale: s,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: earned
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [t.brassLight, t.brass, t.brassDark],
                  )
                : LinearGradient(
                    colors: [t.woodDark, t.recess],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
            border: Border.all(
                color: earned ? t.brassLight : t.woodDark, width: 2),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.55),
                  offset: const Offset(0, 4),
                  blurRadius: 8),
            ],
          ),
          child: Icon(
            Icons.star,
            color: earned ? t.inkBrown : t.woodDark.withValues(alpha: 0.6),
            size: size * 0.55,
          ),
        ),
      ),
    );
  }
}

/// Canvas tile face with weave texture, beveled edges and warm contact shadow.
/// Used by the board; the numeral itself is drawn by the tile-style renderer.
class TileFace extends StatelessWidget {
  final AtelierTheme theme;
  final Widget numeral;
  final bool pressed;
  const TileFace(
      {super.key, required this.theme, required this.numeral, this.pressed = false});

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: pressed
              ? [t.canvasEdge, t.canvasFace]
              : [
                  Color.lerp(t.canvasFace, Colors.white, 0.10)!,
                  t.canvasFace,
                  Color.lerp(t.canvasFace, t.canvasEdge, 0.35)!,
                ],
          stops: const [0.0, 0.5, 1.0],
        ),
        border: Border.all(color: t.canvasEdge.withValues(alpha: 0.8), width: 1),
        boxShadow: pressed
            ? [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.45),
                    offset: const Offset(0, 1),
                    blurRadius: 2,
                    blurStyle: BlurStyle.inner),
              ]
            : [
                // Warm contact shadow toward bottom-right (museum light).
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    offset: const Offset(2, 4),
                    blurRadius: 6),
                BoxShadow(
                    color: t.spotlight.withValues(alpha: 0.35),
                    offset: const Offset(-1, -2),
                    blurRadius: 2),
              ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          children: [
            Positioned.fill(
                child: CustomPaint(painter: _WeavePainter(t.numeral))),
            Center(child: numeral),
          ],
        ),
      ),
    );
  }
}

/// The dark recessed well of the empty slot — a missing piece.
class EmptyWell extends StatelessWidget {
  final AtelierTheme theme;
  const EmptyWell({super.key, required this.theme});

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: t.recess,
        border: Border.all(color: Colors.black.withValues(alpha: 0.7), width: 1.5),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.8),
              offset: const Offset(0, 2),
              blurRadius: 6,
              blurStyle: BlurStyle.inner),
          BoxShadow(
              color: t.spotlight.withValues(alpha: 0.12),
              offset: const Offset(0, -1),
              blurRadius: 2),
        ],
      ),
    );
  }
}
