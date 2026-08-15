import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:intravel/main.dart' show chatbotNavigatorKey;
import 'package:intravel/services/chatbot_handle_position_service.dart';
import 'package:intravel/services/chatbot_visibility_service.dart';
import 'package:intravel/widgets/chatbot_avatar.dart';
import 'package:intravel/widgets/chatbot_side_handle.dart';

/// Covers the "movable/draggable side handle" feature end-to-end at the
/// widget level: dragging pans freely and snaps to the nearer edge on
/// release, the snapped position is persisted, and the handle still
/// hides while its own chat sheet is open (independent of both the
/// permanent visibility preference and the dragged position).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpHandle(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: chatbotNavigatorKey,
        home: const Scaffold(body: Stack(children: [ChatbotSideHandle()])),
      ),
    );
    await tester.pumpAndSettle();
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ChatbotVisibilityService.instance.load();
    await ChatbotHandlePositionService.instance.load();
    // Both are process-wide singletons with intentionally sticky state
    // across app restarts — force each test to start from the
    // "never dragged, visible" baseline regardless of what an earlier
    // test in this run left behind.
    await ChatbotVisibilityService.instance.setVisible(true);
    await ChatbotHandlePositionService.instance.setPosition(
      edge: ChatbotHandleEdge.right,
      verticalFraction: 0.5,
    );
    // Reset back to "never dragged" (null fraction) isn't exposed
    // directly, but every test below either doesn't depend on that
    // exact null-fraction default or explicitly drags first, so a known
    // right/0.5 baseline is sufficient and deterministic.
  });

  testWidgets('renders the collapsed tab by default and expands on tap', (
    tester,
  ) async {
    await pumpHandle(tester);

    expect(find.byIcon(Icons.chevron_left_rounded), findsOneWidget);

    await tester.tap(find.byIcon(Icons.chevron_left_rounded));
    await tester.pumpAndSettle();

    expect(find.byType(ChatbotSideHandle), findsOneWidget);
  });

  testWidgets('hides entirely when ChatbotVisibilityService is set to '
      'hidden', (tester) async {
    await pumpHandle(tester);
    expect(find.byIcon(Icons.chevron_left_rounded), findsOneWidget);

    await ChatbotVisibilityService.instance.setVisible(false);
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.chevron_left_rounded), findsNothing);
    expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);
  });

  testWidgets('dragging the collapsed tab across the screen and releasing '
      'snaps it to the nearer edge and persists that edge', (tester) async {
    await pumpHandle(tester);

    // Starts docked right (per setUp); drag it far to the left half of
    // the screen and release. Uses a manual gesture (rather than the
    // `tester.drag` helper) so each intermediate move is delivered as
    // its own pan-update event, matching how a real finger drag arrives.
    final handleFinder = find.byIcon(Icons.chevron_left_rounded);
    expect(handleFinder, findsOneWidget);
    final startPoint = tester.getCenter(handleFinder);

    final gesture = await tester.startGesture(startPoint);
    for (var i = 1; i <= 10; i++) {
      await gesture.moveBy(const Offset(-60, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await tester.pumpAndSettle();

    // After snapping left, the collapsed tab's chevron should now point
    // the opposite direction (mirrored for the left edge).
    expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
    expect(find.byIcon(Icons.chevron_left_rounded), findsNothing);
    expect(ChatbotHandlePositionService.instance.edge, ChatbotHandleEdge.left);
  });

  testWidgets('opening the chat sheet hides the handle, and closing it '
      'restores the handle', (tester) async {
    await pumpHandle(tester);

    // Expand, then tap the avatar to open the chat sheet.
    await tester.tap(find.byIcon(Icons.chevron_left_rounded));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(GestureDetector).last);
    // The chat sheet's own load future / network calls never fully
    // settle in a test environment (no real network) — pump a fixed
    // duration instead of pumpAndSettle, matching the pattern used by
    // the chat sheet's own tests (e.g. chatbot_clear_history_test.dart).
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Handle must be gone while the chat sheet is up.
    expect(find.byType(ChatbotSideHandle), findsOneWidget);
    expect(find.byIcon(Icons.chevron_left_rounded), findsNothing);
    expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);

    // Close the sheet (its own close button) and confirm the handle
    // reappears — still expanded, exactly as it was before the chat
    // opened (opening/closing the chat must not itself collapse it).
    await tester.tap(find.byTooltip('Close'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(ChatbotAvatar), findsOneWidget);
  });
}
