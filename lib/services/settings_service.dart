import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/atelier.dart';
import '../theme/conservator_themes.dart';

/// Game modes. [party] is pass-and-play relay on one device.
enum GameMode { classic, clock, challenge, daily, party }

extension GameModeLabel on GameMode {
  String get label => switch (this) {
        GameMode.classic => 'Classic Restoration',
        GameMode.clock => 'Beat the Clock',
        GameMode.challenge => 'Move Challenge',
        GameMode.daily => 'Daily Scramble',
        GameMode.party => 'Party Relay',
      };

  String get blurb => switch (this) {
        GameMode.classic => 'Restore the board at your own pace.',
        GameMode.clock => 'Finish before the clock runs out.',
        GameMode.challenge => 'Solve within a tight move budget.',
        GameMode.daily => 'One shared scramble per day. Keep the streak.',
        GameMode.party => 'Pass-and-play: friends alternate moves.',
      };

  bool get isPro => switch (this) {
        GameMode.classic || GameMode.clock => false,
        GameMode.challenge || GameMode.daily || GameMode.party => true,
      };
}

/// Persisted settings + records for Sliding Puzzle.
///
/// Stores: audio toggles, player names, theme/appearance choices (incl.
/// custom theme colors), default size/mode, best records per size, daily
/// streak, Pro unlock state.
class WorkshopSettings extends ChangeNotifier {
  static const _kMusic = 'sp_music_on';
  static const _kSfx = 'sp_sfx_on';
  static const _kVolume = 'sp_volume';
  static const _kName = 'sp_player_name';
  static const _kPartyNames = 'sp_party_names'; // legacy unordered StringSet key
  /// Order-safe party-name storage: a single JSON string. Android's
  /// SharedPreferences stores StringLists as an unordered StringSet, so the
  /// old key scrambled name order on every app restart. Never use a
  /// StringList for ordered data on Android.
  static const _kPartyNamesJson = 'slidingpuzzle_player_names_json';
  static const _kTheme = 'sp_theme_id';
  static const _kTileStyle = 'sp_tile_style';
  static const _kFrameStyle = 'sp_frame_style';
  static const _kSize = 'sp_default_size';
  static const _kMode = 'sp_default_mode';
  static const _kIsPro = 'sp_is_pro';
  static const _kStreak = 'sp_daily_streak';
  static const _kLastDaily = 'sp_last_daily'; // yyyy-MM-dd of last daily solve
  static const _kCustomPrefix = 'sp_custom_';

  static const defaultPartyNames = ['Curator', 'Apprentice', 'Expert', 'Guest'];

  /// Encode the 4 party names as one JSON string (order-preserving).
  static String encodePlayerNames(List<String> names) => jsonEncode(names);

  static String _cleanName(int i, Object? v) {
    final s = v is String ? v.trim() : '';
    return s.isEmpty ? defaultPartyNames[i] : s;
  }

  /// Decode persisted names; falls back to defaults on missing/corrupt data.
  static List<String> decodePlayerNames(String? raw) {
    if (raw == null) return List.of(defaultPartyNames);
    try {
      final d = jsonDecode(raw);
      if (d is List && d.length == 4) {
        return [for (int i = 0; i < 4; i++) _cleanName(i, d[i])];
      }
    } catch (_) {}
    return List.of(defaultPartyNames);
  }

  bool musicOn = true;
  bool sfxOn = true;
  double volume = 0.8;
  String playerName = 'Curator';
  List<String> partyNames = List.of(defaultPartyNames);
  String themeId = 'conservator';
  int tileStyle = 0;
  int frameStyle = 0;
  int defaultSize = 4;
  GameMode defaultMode = GameMode.classic;
  bool isPro = true; // everything unlocked — no Pro version
  int dailyStreak = 0;

  /// Custom theme colors (ARGB ints).
  Map<String, int> customColors = Map.of(_defaultCustomColors);

  static const Map<String, int> _defaultCustomColors = {
    'woodDark': 0xFF2E2013,
    'woodMid': 0xFF7A5C3E,
    'woodLight': 0xFF9A7A52,
    'backdrop': 0xFF3E2C1E,
    'canvasFace': 0xFFE7DCC3,
    'canvasEdge': 0xFF8A7A5C,
    'numeral': 0xFF4A3520,
    'brass': 0xFFB08D4F,
    'brassLight': 0xFFD9BE7E,
    'brassDark': 0xFF6E5626,
    'recess': 0xFF241812,
    'parchment': 0xFFEFE3C8,
    'inkBrown': 0xFF4A3520,
    'spotlight': 0xFFF2DCA8,
  };

  AtelierTheme get customTheme =>
      ConservatorThemes.buildCustom(customColors);

  AtelierTheme get theme =>
      ConservatorThemes.byId(themeId, custom: customTheme);

  TileStyle get tileStyleEnum =>
      TileStyle.values[tileStyle.clamp(0, TileStyle.values.length - 1)];
  FrameStyle get frameStyleEnum =>
      FrameStyle.values[frameStyle.clamp(0, FrameStyle.values.length - 1)];

  SharedPreferences? _prefs;

  String _bestKey(int size, String what) => 'sp_best_${size}_$what';

  int bestMoves(int size) => _prefs?.getInt(_bestKey(size, 'moves')) ?? 0;
  int bestTime(int size) => _prefs?.getInt(_bestKey(size, 'time')) ?? 0;
  int bestScore(int size) => _prefs?.getInt(_bestKey(size, 'score')) ?? 0;

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    final p = _prefs!;
    musicOn = p.getBool(_kMusic) ?? true;
    sfxOn = p.getBool(_kSfx) ?? true;
    volume = p.getDouble(_kVolume) ?? 0.8;
    playerName = p.getString(_kName) ?? 'Curator';
    // Party names: prefer the order-safe JSON key. Fall back to the legacy
    // StringList key once (one-time migration); it may already be scrambled
    // on Android, which is exactly the bug this replaces.
    final namesRaw = p.getString(_kPartyNamesJson);
    if (namesRaw != null) {
      partyNames = decodePlayerNames(namesRaw);
    } else {
      final pn = p.getStringList(_kPartyNames);
      partyNames = (pn != null && pn.length == 4)
          ? [for (int i = 0; i < 4; i++) _cleanName(i, pn[i])]
          : List.of(defaultPartyNames);
    }
    themeId = p.getString(_kTheme) ?? 'conservator';
    tileStyle = (p.getInt(_kTileStyle) ?? 0).clamp(0, TileStyle.values.length - 1);
    frameStyle =
        (p.getInt(_kFrameStyle) ?? 0).clamp(0, FrameStyle.values.length - 1);
    defaultSize = (p.getInt(_kSize) ?? 4).clamp(3, 6);
    final mi = p.getInt(_kMode) ?? 0;
    defaultMode = GameMode.values[mi.clamp(0, GameMode.values.length - 1)];
    isPro = true; // everything unlocked
    dailyStreak = p.getInt(_kStreak) ?? 0;
    for (final k in _defaultCustomColors.keys) {
      customColors[k] =
          p.getInt('$_kCustomPrefix$k') ?? _defaultCustomColors[k]!;
    }
    _enforceFreeLimits(silent: true);
    notifyListeners();
  }

  Future<void> _save() async {
    final p = _prefs;
    if (p == null) return;
    await p.setBool(_kMusic, musicOn);
    await p.setBool(_kSfx, sfxOn);
    await p.setDouble(_kVolume, volume);
    await p.setString(_kName, playerName);
    await p.setString(_kPartyNamesJson, encodePlayerNames(partyNames));
    await p.remove(_kPartyNames); // drop the legacy unordered key for good
    await p.setString(_kTheme, themeId);
    await p.setInt(_kTileStyle, tileStyle);
    await p.setInt(_kFrameStyle, frameStyle);
    await p.setInt(_kSize, defaultSize);
    await p.setInt(_kMode, defaultMode.index);
    await p.setBool(_kIsPro, isPro);
    await p.setInt(_kStreak, dailyStreak);
    for (final e in customColors.entries) {
      await p.setInt('$_kCustomPrefix${e.key}', e.value);
    }
  }

  void _enforceFreeLimits({bool silent = false}) {
    if (isPro) return;
    var changed = false;
    if (ConservatorThemes.isProTheme(themeId)) {
      themeId = 'conservator';
      changed = true;
    }
    if (TileStyle.values[tileStyle].isPro) {
      tileStyle = 0;
      changed = true;
    }
    if (FrameStyle.values[frameStyle].isPro) {
      frameStyle = 0;
      changed = true;
    }
    if (defaultMode.isPro) {
      defaultMode = GameMode.classic;
      changed = true;
    }
    if (defaultSize > 5) {
      defaultSize = 4;
      changed = true;
    }
    if (changed && !silent) {
      notifyListeners();
      _save();
    }
  }

  Future<void> setPro(bool v) async {
    isPro = v;
    if (!v) _enforceFreeLimits();
    notifyListeners();
    await _save();
  }

  Future<void> setMusic(bool v) async {
    musicOn = v;
    notifyListeners();
    await _save();
  }

  Future<void> setSfx(bool v) async {
    sfxOn = v;
    notifyListeners();
    await _save();
  }

  Future<void> setVolume(double v) async {
    volume = v.clamp(0.0, 1.0);
    notifyListeners();
    await _save();
  }

  Future<void> setPlayerName(String name) async {
    final clean = name.trim();
    playerName = clean.isEmpty ? 'Curator' : clean;
    notifyListeners();
    await _save();
  }

  Future<void> setPartyName(int index, String name) async {
    if (index < 0 || index > 3) return;
    final clean = name.trim();
    partyNames[index] = clean.isEmpty ? defaultPartyNames[index] : clean;
    notifyListeners();
    await _save();
  }

  Future<void> setTheme(String id) async {
    if (!isPro && ConservatorThemes.isProTheme(id)) return;
    themeId = id;
    notifyListeners();
    await _save();
  }

  Future<void> setTileStyle(int v) async {
    v = v.clamp(0, TileStyle.values.length - 1);
    if (!isPro && TileStyle.values[v].isPro) return;
    tileStyle = v;
    notifyListeners();
    await _save();
  }

  Future<void> setFrameStyle(int v) async {
    v = v.clamp(0, FrameStyle.values.length - 1);
    if (!isPro && FrameStyle.values[v].isPro) return;
    frameStyle = v;
    notifyListeners();
    await _save();
  }

  Future<void> setCustomColor(String key, int argb) async {
    if (!_defaultCustomColors.containsKey(key)) return;
    customColors[key] = argb;
    notifyListeners();
    await _save();
  }

  Future<void> resetCustomColors() async {
    customColors = Map.of(_defaultCustomColors);
    notifyListeners();
    await _save();
  }

  Future<void> setDefaultSize(int v) async {
    defaultSize = v.clamp(3, 6);
    if (!isPro && defaultSize > 5) defaultSize = 5;
    notifyListeners();
    await _save();
  }

  Future<void> setDefaultMode(GameMode m) async {
    if (!isPro && m.isPro) return;
    defaultMode = m;
    notifyListeners();
    await _save();
  }

  /// Record a finished solve. Returns true if any best was beaten.
  Future<bool> recordSolve({
    required int size,
    required int moves,
    required int seconds,
  }) async {
    final p = _prefs;
    var newBest = false;
    if (p != null) {
      final pm = p.getInt(_bestKey(size, 'moves')) ?? 0;
      final pt = p.getInt(_bestKey(size, 'time')) ?? 0;
      final ps = p.getInt(_bestKey(size, 'score')) ?? 0;
      final score = SlidingScoring.score(moves, seconds);
      if (pm == 0 || moves < pm) {
        await p.setInt(_bestKey(size, 'moves'), moves);
        newBest = true;
      }
      if (pt == 0 || seconds < pt) {
        await p.setInt(_bestKey(size, 'time'), seconds);
        newBest = true;
      }
      if (score > ps) {
        await p.setInt(_bestKey(size, 'score'), score);
        newBest = true;
      }
    }
    notifyListeners();
    return newBest;
  }

  /// Daily streak bookkeeping. Call on a daily-mode solve.
  Future<void> recordDailySolve(DateTime day) async {
    final p = _prefs;
    if (p == null) return;
    final key = _dateKey(day);
    final last = p.getString(_kLastDaily);
    if (last == key) return; // already counted today
    final yesterday = _dateKey(day.subtract(const Duration(days: 1)));
    dailyStreak = (last == yesterday) ? dailyStreak + 1 : 1;
    await p.setString(_kLastDaily, key);
    await p.setInt(_kStreak, dailyStreak);
    notifyListeners();
  }

  static String _dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

/// Scoring helpers (RULES.md §8).
class SlidingScoring {
  /// Optimal-par move counts per board size (RULES.md §7, extended to 6×6).
  static int parFor(int size) => switch (size) {
        3 => 30,
        4 => 80,
        5 => 200,
        6 => 350,
        _ => 80,
      };

  /// Star rating: ≤ par → 3, < 1.5× par → 2, else 1. Hint caps at 2.
  /// Note RULES §13 test 12: exactly 1.5× par → 2 stars.
  static int starsFor(int size, int moves, {required bool hintUsed}) {
    final par = parFor(size);
    int stars;
    if (moves <= par) {
      stars = 3;
    } else if (moves <= (par * 1.5).ceil()) {
      stars = 2;
    } else {
      stars = 1;
    }
    if (hintUsed && stars > 2) stars = 2;
    return stars;
  }

  static int score(int moves, int seconds) =>
      (100000 - moves * 100 - seconds * 10).clamp(0, 100000);

  /// Scramble depths per size (RULES.md §2, extended to 6×6).
  static int scrambleDepth(int size) => switch (size) {
        3 => 40,
        4 => 120,
        5 => 240,
        6 => 400,
        _ => 120,
      };

  /// Countdown seconds for Beat-the-Clock mode per size.
  static int clockBudget(int size) => switch (size) {
        3 => 300,
        4 => 900,
        5 => 1800,
        6 => 3600,
        _ => 900,
      };
}
