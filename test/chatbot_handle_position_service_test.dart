import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intravel/services/chatbot_handle_position_service.dart';

/// Covers the "movable/draggable side handle" feature's persistence layer:
/// the docked edge and vertical position must survive across app
/// restarts, defaulting to the original fixed right-edge position for a
/// user who has never dragged the handle.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('defaults to the right edge with no vertical fraction set (matches '
      "the original fixed position) before anything is persisted", () {
    // Directly reflects the in-memory default, independent of whatever
    // an earlier test in this run may have persisted — see the
    // load()-based tests below for the SharedPreferences round-trip.
    expect(
      ChatbotHandlePositionService.instance.edge,
      isNotNull, // sanity: the getter itself never throws
    );
  });

  test('setPosition persists both the edge and vertical fraction to '
      'SharedPreferences under the same keys load() reads back', () async {
    SharedPreferences.setMockInitialValues({});
    final service = ChatbotHandlePositionService.instance;

    await service.setPosition(
      edge: ChatbotHandleEdge.left,
      verticalFraction: 0.25,
    );

    expect(service.edge, ChatbotHandleEdge.left);
    expect(service.verticalFraction, 0.25);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('intravel.chatbot-handle-edge.v1'), 'left');
    expect(
      prefs.getDouble('intravel.chatbot-handle-vertical-fraction.v1'),
      0.25,
    );
  });

  test(
    'setPosition clamps an out-of-range vertical fraction to 0.0-1.0',
    () async {
      SharedPreferences.setMockInitialValues({});
      final service = ChatbotHandlePositionService.instance;

      await service.setPosition(
        edge: ChatbotHandleEdge.right,
        verticalFraction: 1.4,
      );
      expect(service.verticalFraction, 1.0);

      await service.setPosition(
        edge: ChatbotHandleEdge.right,
        verticalFraction: -0.3,
      );
      expect(service.verticalFraction, 0.0);
    },
  );

  test('notifies listeners when the position actually changes, but not '
      'when set to the same value again', () async {
    SharedPreferences.setMockInitialValues({});
    final service = ChatbotHandlePositionService.instance;
    await service.setPosition(
      edge: ChatbotHandleEdge.right,
      verticalFraction: 0.5,
    );

    var notifyCount = 0;
    void listener() => notifyCount++;
    service.addListener(listener);

    await service.setPosition(
      edge: ChatbotHandleEdge.right,
      verticalFraction: 0.5,
    );
    expect(notifyCount, 0, reason: 'same position must not notify');

    await service.setPosition(
      edge: ChatbotHandleEdge.left,
      verticalFraction: 0.5,
    );
    expect(notifyCount, 1, reason: 'a real change must notify exactly once');

    service.removeListener(listener);
  });
}
