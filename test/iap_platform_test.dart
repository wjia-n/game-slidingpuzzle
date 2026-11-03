import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slidingpuzzle/services/iap_service.dart';

void main() {
  test('iOS maps to the single star product', () {
    final ids = StoreService.productIdsFor(TargetPlatform.iOS);
    expect(ids, <String>{'slidingpuzzlestar'});
    expect(ids.length, 1);
  });

  test('Android maps to coffee + chocolate', () {
    final ids = StoreService.productIdsFor(TargetPlatform.android);
    expect(ids, <String>{'slidingpuzzlecoffee', 'slidingpuzzlechocolate'});
    expect(ids.length, 2);
  });

  test('star id has no dots or underscores', () {
    expect(StoreService.starId.contains('.'), isFalse);
    expect(StoreService.starId.contains('_'), isFalse);
  });
}
