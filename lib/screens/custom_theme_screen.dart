import 'package:flutter/material.dart';
import '../services/audio_service.dart';
import '../services/settings_service.dart';
import '../theme/atelier.dart';
import '../theme/conservator_themes.dart';

/// Custom theme creator (Pro): mix your own workshop palette.
/// Live preview tile + frame, persisted per color.
class CustomThemeScreen extends StatefulWidget {
  final WorkshopAudio audio;
  final WorkshopSettings settings;
  const CustomThemeScreen(
      {super.key, required this.audio, required this.settings});

  @override
  State<CustomThemeScreen> createState() => _CustomThemeScreenState();
}

class _CustomThemeScreenState extends State<CustomThemeScreen> {
  static const _swatches = [
    0xFF2E2013, 0xFF7A5C3E, 0xFF9A7A52, 0xFF3E2C1E, // woods
    0xFFE7DCC3, 0xFFDFD2B4, 0xFFF2ECDC, 0xFFDCC9A0, // canvases
    0xFF4A3520, 0xFF1E1A14, 0xFF3E3E44, 0xFF54402A, // inks
    0xFFB08D4F, 0xFFD9BE7E, 0xFF6E5626, 0xFFA8763E, // brass
    0xFF7E9E8A, 0xFFB06E42, 0xFF6E3A34, 0xFF4E5A50, // accents
    0xFF241812, 0xFF0A0806, 0xFF1C1C20, 0xFFF2DCA8, // deep + light
  ];

  static const _labels = {
    'woodDark': 'Deep wood',
    'woodMid': 'Oak mid',
    'woodLight': 'Oak highlight',
    'backdrop': 'Workbench',
    'canvasFace': 'Canvas face',
    'canvasEdge': 'Canvas edge',
    'numeral': 'Numeral ink',
    'brass': 'Brass',
    'brassLight': 'Brass shine',
    'brassDark': 'Brass shadow',
    'recess': 'Empty well',
    'parchment': 'Parchment',
    'inkBrown': 'Carved text',
    'spotlight': 'Spotlight',
  };

  String _selected = 'woodMid';

  @override
  Widget build(BuildContext context) {
    final t = widget.settings.theme;
    final s = widget.settings;
    final preview = ConservatorThemes.buildCustom(s.customColors);
    return Scaffold(
      backgroundColor: t.backdrop,
      body: WoodBackdrop(
        theme: t,
        child: SafeArea(
          child: SingleChildScrollView(
            padding:
                const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    BrassRoundButton(
                      theme: t,
                      icon: Icons.arrow_back,
                      tooltip: 'Back',
                      size: 44,
                      onTap: () {
                        widget.audio.click();
                        Navigator.of(context).pop();
                      },
                    ),
                    const SizedBox(width: 14),
                    Text('CUSTOM THEME', style: AtelierType.display(20, t)),
                  ],
                ),
                const SizedBox(height: 16),
                // Live preview.
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: preview.backdrop,
                    border:
                        Border.all(color: preview.brassDark, width: 1.5),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 96,
                        height: 96,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              preview.woodLight,
                              preview.woodMid,
                              preview.woodDark
                            ],
                          ),
                          border: Border.all(
                              color: preview.woodDark, width: 2),
                        ),
                        child: TileFace(
                          theme: preview,
                          numeral: tileNumeral(15, s.tileStyleEnum,
                              preview, 30),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            BrassPlaque(
                                theme: preview,
                                text: 'MY CREATION',
                                fontSize: 13),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: 44,
                              height: 44,
                              child: EmptyWell(theme: preview),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text('PAINT — ${_labels[_selected]!.toUpperCase()}',
                    style: AtelierType.label(12, t)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _labels.keys.map((key) {
                    final sel = _selected == key;
                    return GestureDetector(
                      onTap: () {
                        widget.audio.click();
                        setState(() => _selected = key);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 7),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          color: sel
                              ? t.brass
                              : t.woodDark,
                          border: Border.all(
                              color: sel ? t.brassLight : t.brassDark),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 14,
                              height: 14,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(
                                    s.customColors[key]!),
                                border: Border.all(
                                    color: Colors.black45),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(_labels[key]!,
                                style: AtelierType.label(
                                    10, t,
                                    color: sel
                                        ? t.inkBrown
                                        : t.parchment)),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
                GridView.count(
                  crossAxisCount: 8,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  children: _swatches.map((argb) {
                    final sel = s.customColors[_selected] == argb;
                    return GestureDetector(
                      onTap: () {
                        widget.audio.click();
                        s.setCustomColor(_selected, argb);
                        setState(() {});
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(argb),
                          border: Border.all(
                              color: sel
                                  ? t.brassLight
                                  : Colors.black45,
                              width: sel ? 3 : 1.5),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black
                                    .withValues(alpha: 0.4),
                                offset: const Offset(0, 2),
                                blurRadius: 4),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OakButton(
                        theme: t,
                        label: 'USE THIS THEME',
                        onTap: () {
                          widget.audio.click();
                          s.setTheme('custom');
                          Navigator.of(context).pop();
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OakButton(
                        theme: t,
                        label: 'RESET',
                        onTap: () {
                          widget.audio.click();
                          s.resetCustomColors();
                          setState(() {});
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
