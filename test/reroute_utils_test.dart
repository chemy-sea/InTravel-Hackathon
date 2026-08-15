import 'package:flutter_test/flutter_test.dart';
import 'package:intravel/utils/reroute_utils.dart';

void main() {
  group('computeRerouteDurationDelta', () {
    test('returns null when there is no previous duration to compare', () {
      expect(
        computeRerouteDurationDelta(
          previousDurationSeconds: null,
          newDurationSeconds: 300,
        ),
        isNull,
      );
    });

    test('returns null when the difference is below the significance '
        'threshold', () {
      expect(
        computeRerouteDurationDelta(
          previousDurationSeconds: 300,
          newDurationSeconds: 310, // +10s, below the default 30s threshold
        ),
        isNull,
      );
    });

    test('returns a positive delta when the new route is slower', () {
      final delta = computeRerouteDurationDelta(
        previousDurationSeconds: 300,
        newDurationSeconds: 420, // +120s
      );
      expect(delta, 120);
    });

    test('returns a negative delta when the new route is faster', () {
      final delta = computeRerouteDurationDelta(
        previousDurationSeconds: 420,
        newDurationSeconds: 300, // -120s
      );
      expect(delta, -120);
    });

    test('respects a custom significance threshold', () {
      final delta = computeRerouteDurationDelta(
        previousDurationSeconds: 300,
        newDurationSeconds: 320,
        minSignificantDeltaSeconds: 10,
      );
      expect(delta, 20);
    });
  });

  group('shouldSuggestUTurn', () {
    test('is false when the real routing service found a forward path', () {
      expect(
        shouldSuggestUTurn(
          realRouteFoundForwardPath: true,
          fallbackGraphFoundForwardPath: false,
        ),
        isFalse,
      );
    });

    test('is false when only the fallback graph found a forward path', () {
      expect(
        shouldSuggestUTurn(
          realRouteFoundForwardPath: false,
          fallbackGraphFoundForwardPath: true,
        ),
        isFalse,
      );
    });

    test('is true only when neither source found a forward path', () {
      expect(
        shouldSuggestUTurn(
          realRouteFoundForwardPath: false,
          fallbackGraphFoundForwardPath: false,
        ),
        isTrue,
      );
    });
  });

  group('rerouteDeltaMinutes', () {
    test('rounds up to the nearest whole minute', () {
      expect(rerouteDeltaMinutes(61), 2);
      expect(rerouteDeltaMinutes(120), 2);
      expect(rerouteDeltaMinutes(30), 1);
    });

    test('uses the absolute value regardless of sign', () {
      expect(rerouteDeltaMinutes(-90), 2);
    });

    test('is never less than 1 minute', () {
      expect(rerouteDeltaMinutes(1), 1);
    });
  });
}
