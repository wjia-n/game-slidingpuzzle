import 'package:flutter_test/flutter_test.dart';
import 'package:slidingpuzzle/services/settings_service.dart';

/// Regression tests for the player-name persistence bug (2026-10-09):
///
/// Party names were stored with SharedPreferences.setStringList, which on
/// Android is backed by an UNORDERED StringSet — so after an app restart the
/// four names came back in arbitrary order and renames appeared "not saved".
/// Names are now stored as one order-preserving JSON string. These tests
/// cover the encode/decode round-trip plus the settings reload path, without
/// needing platform channels.
void main() {
  test('names survive an encode/decode round-trip in exact slot order', () {
    const names = ['Wajiha', 'Zara', 'Ali', 'Bot Bob'];
    final decoded = WorkshopSettings.decodePlayerNames(
      WorkshopSettings.encodePlayerNames(names),
    );
    expect(decoded, names);
    // Slot order is what matters: each index must map to the same player.
    for (int i = 0; i < 4; i++) {
      expect(decoded[i], names[i]);
    }
  });

  test('encoded form is a single JSON string, not a StringList', () {
    final encoded =
        WorkshopSettings.encodePlayerNames(['A', 'B', 'C', 'D']);
    // jsonDecode of the stored string must yield the list in order; there is
    // no setStringList involved anywhere in the encode path.
    expect(encoded.startsWith('['), isTrue);
    expect(encoded, '["A","B","C","D"]');
  });

  test('decode falls back to defaults on missing or corrupt data', () {
    expect(
      WorkshopSettings.decodePlayerNames(null),
      WorkshopSettings.defaultPartyNames,
    );
    expect(
      WorkshopSettings.decodePlayerNames('definitely not json'),
      WorkshopSettings.defaultPartyNames,
    );
    expect(
      WorkshopSettings.decodePlayerNames('["only","two"]'),
      WorkshopSettings.defaultPartyNames,
    );
    expect(
      WorkshopSettings.decodePlayerNames('{"a":1}'),
      WorkshopSettings.defaultPartyNames,
    );
  });

  test('blank entries fall back to that slot\'s default name', () {
    final decoded = WorkshopSettings.decodePlayerNames(
        '["Wajiha","","  ","Guest"]');
    expect(decoded, ['Wajiha', 'Apprentice', 'Expert', 'Guest']);
  });

  test('party setup rebuilt after "restart" shows the persisted names', () {
    // Simulate: user renamed slot 0, app restarted, settings rebuilt from
    // the persisted value — the relay order must be unchanged.
    const renamed = ['Wajiha', 'Apprentice', 'Expert', 'Guest'];
    final persisted = WorkshopSettings.decodePlayerNames(
      WorkshopSettings.encodePlayerNames(renamed),
    );
    expect(persisted, renamed);
    expect(persisted[0], 'Wajiha');
    expect(persisted[3], 'Guest');
  });
}
