/// Pure decision logic for the "smart re-routing" feature in
/// [NavigationScreen] (lib/screens/navigation_screen.dart), pulled out of
/// that widget's private state so it can be unit-tested directly without
/// needing a live GPS fix or a real/fake [RoutingService] round-trip —
/// the widget-level tests for navigation already document that no GPS fix
/// is available in the test environment, so any logic that only runs
/// after a position update needs to be verifiable independently of that.
library;

/// Computes the signed reroute time-difference notice: [newDurationSeconds]
/// minus [previousDurationSeconds], or `null` when there's nothing
/// meaningful to show.
///
/// Returns `null` when:
/// - there's no previous route to compare against ([previousDurationSeconds]
///   is `null` — e.g. this is the very first route fetched for a
///   navigation session), or
/// - the difference is smaller than [minSignificantDeltaSeconds] — every
///   other duration display in this app
///   ([lib/models/route_result_model.dart]'s `durationLabel`, and
///   [NavigationScreen]'s own ETA text) is minute-granular, so a
///   sub-threshold delta would just round down to "0 min" and read as a
///   glitch rather than useful information.
///
/// A positive result means the new route is slower than the one it
/// replaced; negative means faster.
double? computeRerouteDurationDelta({
  required double? previousDurationSeconds,
  required double newDurationSeconds,
  double minSignificantDeltaSeconds = 30,
}) {
  if (previousDurationSeconds == null) return null;
  final delta = newDurationSeconds - previousDurationSeconds;
  return delta.abs() >= minSignificantDeltaSeconds ? delta : null;
}

/// Whether a "no forward path — turn back" suggestion should be shown,
/// given whether each of the two routing sources
/// ([lib/services/routing_service.dart]'s real routing service, and
/// [lib/services/walking_path_service.dart]'s static graph fallback)
/// managed to find *any* forward path from the user's current, deviated
/// position to the destination.
///
/// A U-turn is the last resort: it's only suggested when *both* sources
/// agree there is genuinely no way forward from here, never just because
/// one of the two failed (e.g. a transient network error from the real
/// service shouldn't trigger this if the static graph still found a way
/// through).
bool shouldSuggestUTurn({
  required bool realRouteFoundForwardPath,
  required bool fallbackGraphFoundForwardPath,
}) {
  return !realRouteFoundForwardPath && !fallbackGraphFoundForwardPath;
}

/// Rounds a duration difference in seconds to a whole, minute-granular,
/// unsigned magnitude for display (e.g. in a "Rerouted — N min
/// slower/faster" notice) — always at least 1, since
/// [computeRerouteDurationDelta] never returns a delta below its
/// significance threshold in the first place.
int rerouteDeltaMinutes(double deltaSeconds) {
  return (deltaSeconds.abs() / 60).ceil().clamp(1, 999);
}
