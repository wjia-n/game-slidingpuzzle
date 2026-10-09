import 'package:flutter/material.dart';
import 'atelier.dart';

/// The theme catalog — MANY workshop-appropriate schemes, all persisted.
/// Free tier: the first 6. The rest (and the custom creator) are Pro.
class ConservatorThemes {
  static const List<AtelierTheme> all = [
    AtelierTheme(
      id: 'conservator',
      name: 'Classic Conservator',
      woodDark: Color(0xFF2E2013),
      woodMid: Color(0xFF7A5C3E),
      woodLight: Color(0xFF9A7A52),
      backdrop: Color(0xFF3E2C1E),
      canvasFace: Color(0xFFE7DCC3),
      canvasEdge: Color(0xFF8A7A5C),
      numeral: Color(0xFF4A3520),
      brass: Color(0xFFB08D4F),
      brassLight: Color(0xFFD9BE7E),
      brassDark: Color(0xFF6E5626),
      recess: Color(0xFF241812),
      parchment: Color(0xFFEFE3C8),
      inkBrown: Color(0xFF4A3520),
      spotlight: Color(0xFFF2DCA8),
    ),
    AtelierTheme(
      id: 'walnut',
      name: 'Walnut Study',
      woodDark: Color(0xFF1E130B),
      woodMid: Color(0xFF5A4030),
      woodLight: Color(0xFF7A5C44),
      backdrop: Color(0xFF2A1D12),
      canvasFace: Color(0xFFDFD2B4),
      canvasEdge: Color(0xFF77664A),
      numeral: Color(0xFF3A2A18),
      brass: Color(0xFFA8874E),
      brassLight: Color(0xFFCFAE6E),
      brassDark: Color(0xFF5F4B22),
      recess: Color(0xFF191008),
      parchment: Color(0xFFE8D9BC),
      inkBrown: Color(0xFF3A2A18),
      spotlight: Color(0xFFEFD6A0),
    ),
    AtelierTheme(
      id: 'cherry',
      name: 'Cherrywood Library',
      woodDark: Color(0xFF2E1610),
      woodMid: Color(0xFF8A4A30),
      woodLight: Color(0xFFAB6A4A),
      backdrop: Color(0xFF3A2118),
      canvasFace: Color(0xFFE9DCC0),
      canvasEdge: Color(0xFF8A7458),
      numeral: Color(0xFF4E2E1C),
      brass: Color(0xFFB8935A),
      brassLight: Color(0xFFDCc084),
      brassDark: Color(0xFF715522),
      recess: Color(0xFF221410),
      parchment: Color(0xFFF0E4C6),
      inkBrown: Color(0xFF4E2E1C),
      spotlight: Color(0xFFF5DFAE),
    ),
    AtelierTheme(
      id: 'ebony',
      name: 'Ebony & Ivory',
      woodDark: Color(0xFF0E0C0A),
      woodMid: Color(0xFF2E2822),
      woodLight: Color(0xFF4A4238),
      backdrop: Color(0xFF1A1612),
      canvasFace: Color(0xFFF2ECDC),
      canvasEdge: Color(0xFF9A9284),
      numeral: Color(0xFF1E1A14),
      brass: Color(0xFFC0A062),
      brassLight: Color(0xFFE0C88E),
      brassDark: Color(0xFF7A6234),
      recess: Color(0xFF0A0806),
      parchment: Color(0xFFF5EFE0),
      inkBrown: Color(0xFF1E1A14),
      spotlight: Color(0xFFF8ECD0),
    ),
    AtelierTheme(
      id: 'marble',
      name: 'Marble Hall',
      woodDark: Color(0xFF2A2A2E),
      woodMid: Color(0xFF6E6E74),
      woodLight: Color(0xFF9A9AA2),
      backdrop: Color(0xFF333336),
      canvasFace: Color(0xFFEDEAE2),
      canvasEdge: Color(0xFF8E8E96),
      numeral: Color(0xFF3E3E44),
      brass: Color(0xFFB08D4F),
      brassLight: Color(0xFFD9BE7E),
      brassDark: Color(0xFF6E5626),
      recess: Color(0xFF1C1C20),
      parchment: Color(0xFFF2EEE4),
      inkBrown: Color(0xFF3E3E44),
      spotlight: Color(0xFFF4F0E2),
    ),
    AtelierTheme(
      id: 'sandstone',
      name: 'Sandstone Vault',
      woodDark: Color(0xFF33261A),
      woodMid: Color(0xFF8A6E48),
      woodLight: Color(0xFFAA8E62),
      backdrop: Color(0xFF42321F),
      canvasFace: Color(0xFFE3D3AC),
      canvasEdge: Color(0xFF8A7550),
      numeral: Color(0xFF54402A),
      brass: Color(0xFFB28E50),
      brassLight: Color(0xFFD4B878),
      brassDark: Color(0xFF6E5626),
      recess: Color(0xFF241A10),
      parchment: Color(0xFFEDDCB8),
      inkBrown: Color(0xFF54402A),
      spotlight: Color(0xFFF6E2B0),
    ),
    // ---- Pro themes below ----
    AtelierTheme(
      id: 'bronze',
      name: 'Bronze Age',
      isPro: true,
      woodDark: Color(0xFF2A1E12),
      woodMid: Color(0xFF6E5A3A),
      woodLight: Color(0xFF8E7A52),
      backdrop: Color(0xFF36281A),
      canvasFace: Color(0xFFDCC9A0),
      canvasEdge: Color(0xFF7A6848),
      numeral: Color(0xFF3E2E1A),
      brass: Color(0xFFA8763E),
      brassLight: Color(0xFFD89E5E),
      brassDark: Color(0xFF5E3E1E),
      recess: Color(0xFF201610),
      parchment: Color(0xFFE8D4AE),
      inkBrown: Color(0xFF3E2E1A),
      spotlight: Color(0xFFF2D49E),
    ),
    AtelierTheme(
      id: 'verdigris',
      name: 'Verdigris Gallery',
      isPro: true,
      woodDark: Color(0xFF1E2420),
      woodMid: Color(0xFF4E5A50),
      woodLight: Color(0xFF6E7E70),
      backdrop: Color(0xFF2A332E),
      canvasFace: Color(0xFFE4DCC6),
      canvasEdge: Color(0xFF7E8272),
      numeral: Color(0xFF33402E),
      brass: Color(0xFF7E9E8A),
      brassLight: Color(0xFFA8C4B2),
      brassDark: Color(0xFF4E6A5A),
      recess: Color(0xFF161E1A),
      parchment: Color(0xFFEAE2CC),
      inkBrown: Color(0xFF33402E),
      spotlight: Color(0xFFEAF2DC),
    ),
    AtelierTheme(
      id: 'copper',
      name: 'Copper Mine',
      isPro: true,
      woodDark: Color(0xFF2E1A10),
      woodMid: Color(0xFF7A5238),
      woodLight: Color(0xFF9A6E4E),
      backdrop: Color(0xFF38241A),
      canvasFace: Color(0xFFE6D6B8),
      canvasEdge: Color(0xFF8A7052),
      numeral: Color(0xFF4A2E1E),
      brass: Color(0xFFB06E42),
      brassLight: Color(0xFFD89A6A),
      brassDark: Color(0xFF6E4022),
      recess: Color(0xFF221410),
      parchment: Color(0xFFEEE0C2),
      inkBrown: Color(0xFF4A2E1E),
      spotlight: Color(0xFFF4D8AC),
    ),
    AtelierTheme(
      id: 'rosewood',
      name: 'Rosewood Salon',
      isPro: true,
      woodDark: Color(0xFF241210),
      woodMid: Color(0xFF6E3A34),
      woodLight: Color(0xFF8E544C),
      backdrop: Color(0xFF301A18),
      canvasFace: Color(0xFFEADFC6),
      canvasEdge: Color(0xFF8A7660),
      numeral: Color(0xFF4E2622),
      brass: Color(0xFFBA9458),
      brassLight: Color(0xFFDCBE80),
      brassDark: Color(0xFF74582A),
      recess: Color(0xFF1C0E0C),
      parchment: Color(0xFFF0E5CA),
      inkBrown: Color(0xFF4E2622),
      spotlight: Color(0xFFF5DCB2),
    ),
    AtelierTheme(
      id: 'limestone',
      name: 'Limestone Archive',
      isPro: true,
      woodDark: Color(0xFF26221C),
      woodMid: Color(0xFF6A6252),
      woodLight: Color(0xFF8A8272),
      backdrop: Color(0xFF322D24),
      canvasFace: Color(0xFFDCD4BE),
      canvasEdge: Color(0xFF7E7664),
      numeral: Color(0xFF3E382C),
      brass: Color(0xFFA8925E),
      brassLight: Color(0xFFCCB880),
      brassDark: Color(0xFF665832),
      recess: Color(0xFF1C1914),
      parchment: Color(0xFFE6DCC4),
      inkBrown: Color(0xFF3E382C),
      spotlight: Color(0xFFF0E6CC),
    ),
    AtelierTheme(
      id: 'parchment',
      name: 'Parchment & Ink',
      isPro: true,
      woodDark: Color(0xFF2C2318),
      woodMid: Color(0xFF74644A),
      woodLight: Color(0xFF94846A),
      backdrop: Color(0xFF382F22),
      canvasFace: Color(0xFFF0E6CE),
      canvasEdge: Color(0xFF8E8066),
      numeral: Color(0xFF2E2418),
      brass: Color(0xFF8E7A4E),
      brassLight: Color(0xFFB89E6E),
      brassDark: Color(0xFF5A4A2E),
      recess: Color(0xFF201A12),
      parchment: Color(0xFFF4EAD2),
      inkBrown: Color(0xFF2E2418),
      spotlight: Color(0xFFF8EED4),
    ),
  ];

  static AtelierTheme byId(String id, {required AtelierTheme custom}) {
    if (id == 'custom') return custom;
    for (final t in all) {
      if (t.id == id) return t;
    }
    return all.first;
  }

  static bool isProTheme(String id) {
    for (final t in all) {
      if (t.id == id) return t.isPro;
    }
    return id == 'custom';
  }

  static AtelierTheme buildCustom(Map<String, int> c) {
    Color col(String k, int fallback) => Color(c[k] ?? fallback);
    return AtelierTheme(
      id: 'custom',
      name: 'My Creation',
      woodDark: col('woodDark', 0xFF2E2013),
      woodMid: col('woodMid', 0xFF7A5C3E),
      woodLight: col('woodLight', 0xFF9A7A52),
      backdrop: col('backdrop', 0xFF3E2C1E),
      canvasFace: col('canvasFace', 0xFFE7DCC3),
      canvasEdge: col('canvasEdge', 0xFF8A7A5C),
      numeral: col('numeral', 0xFF4A3520),
      brass: col('brass', 0xFFB08D4F),
      brassLight: col('brassLight', 0xFFD9BE7E),
      brassDark: col('brassDark', 0xFF6E5626),
      recess: col('recess', 0xFF241812),
      parchment: col('parchment', 0xFFEFE3C8),
      inkBrown: col('inkBrown', 0xFF4A3520),
      spotlight: col('spotlight', 0xFFF2DCA8),
    );
  }
}

// ---------------------------------------------------------------------------
// Tile face styles — how the numeral is rendered on the canvas tile.
// ---------------------------------------------------------------------------

enum TileStyle {
  engraved('Engraved Serif', false),
  roman('Roman Numerals', false),
  inlay('Brass Inlay Ring', false),
  typewriter('Typewriter Plate', false),
  stamp('Conservator Stamp', true),
  chisel('Chisel Cut', true),
  gilded('Gilded Leaf', true),
  stencil('Stencil Mark', true);

  final String label;
  final bool isPro;
  const TileStyle(this.label, this.isPro);
}

String _roman(int v) {
  const table = [
    (10, 'X'), (9, 'IX'), (5, 'V'), (4, 'IV'), (1, 'I')
  ];
  final sb = StringBuffer();
  var n = v;
  for (final (val, sym) in table) {
    while (n >= val) {
      sb.write(sym);
      n -= val;
    }
  }
  return sb.toString();
}

/// Renders the numeral widget for a tile value under the given style.
Widget tileNumeral(int value, TileStyle style, AtelierTheme t, double size) {
  final base = AtelierType.numeral(size, t);
  switch (style) {
    case TileStyle.roman:
      return Text(_roman(value),
          style: base.copyWith(letterSpacing: 1.0, fontSize: size * 0.82));
    case TileStyle.inlay:
      return Container(
        padding: EdgeInsets.all(size * 0.10),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: t.brass, width: 2),
          boxShadow: [
            BoxShadow(
                color: t.brassLight.withValues(alpha: 0.5),
                offset: const Offset(0, 1),
                blurRadius: 1),
          ],
        ),
        child: Text('$value', style: base),
      );
    case TileStyle.stamp:
      return Container(
        padding: EdgeInsets.symmetric(
            horizontal: size * 0.22, vertical: size * 0.12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: t.numeral.withValues(alpha: 0.75), width: 2),
        ),
        child: Text('$value', style: base.copyWith(fontSize: size * 0.9)),
      );
    case TileStyle.typewriter:
      return Text('$value',
          style: base.copyWith(
              fontFamily: 'monospace',
              fontWeight: FontWeight.w700,
              fontSize: size * 0.92));
    case TileStyle.chisel:
      return Text('$value',
          style: base.copyWith(shadows: [
            Shadow(
                color: Colors.black.withValues(alpha: 0.7),
                offset: const Offset(0, 2),
                blurRadius: 2),
            Shadow(
                color: t.canvasFace.withValues(alpha: 0.9),
                offset: const Offset(0, -2),
                blurRadius: 1),
          ]));
    case TileStyle.gilded:
      return Text('$value',
          style: base.copyWith(color: t.brass, shadows: [
            Shadow(
                color: t.brassDark.withValues(alpha: 0.9),
                offset: const Offset(0, 2),
                blurRadius: 2),
            Shadow(
                color: t.brassLight.withValues(alpha: 0.8),
                offset: const Offset(0, -1),
                blurRadius: 1),
          ]));
    case TileStyle.stencil:
      return Text('$value',
          style: base.copyWith(
              letterSpacing: 3.0,
              fontWeight: FontWeight.w800,
              fontSize: size * 0.9));
    case TileStyle.engraved:
      return Text('$value', style: base);
  }
}

// ---------------------------------------------------------------------------
// Frame styles — how the carved oak frame around the board is rendered.
// ---------------------------------------------------------------------------

enum FrameStyle {
  carved('Carved Oak', false),
  brassBound('Brass-Bound', false),
  plainBevel('Plain Bevel', true),
  museumCase('Museum Case', true);

  final String label;
  final bool isPro;
  const FrameStyle(this.label, this.isPro);
}
