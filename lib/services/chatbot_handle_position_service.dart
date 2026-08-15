import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Which screen edge [ChatbotSideHandle] is currently docked to.
enum ChatbotHandleEdge { left, right }

/// Persists where the user last dragged/docked the IntraBadi chat handle
/// (improvement-batch spec: "movable/draggable side handle"), mirroring
/// [ChatbotVisibilityService]'s singleton + SharedPreferences pattern so
/// the handle stays where the user left it across app restarts instead of
/// resetting to the default right-edge position every launch.
///
/// Deliberately independent of [ChatbotVisibilityService] (permanent
/// show/hide) and the chat-open transient visibility flag — dragging the
/// handle must never affect whether it's shown, and opening/closing the
/// chat must never affect its saved position.
///
/// Only two values are persisted: which edge it's docked to
/// ([ChatbotHandleEdge]), and a vertical position expressed as a 0.0-1.0
/// fraction of the available (safe-area-clamped) vertical space rather
/// than a raw pixel offset — a fraction stays valid across screen
/// rotations and different device sizes, where a stored pixel value
/// could end up off-screen or in a completely different relative spot on
/// a different device.
class ChatbotHandlePositionService extends ChangeNotifier {
  static final ChatbotHandlePositionService instance =
      ChatbotHandlePositionService._internal();
  ChatbotHandlePositionService._internal();

  static const String _edgeKey = 'intravel.chatbot-handle-edge.v1';
  static const String _verticalFractionKey =
      'intravel.chatbot-handle-vertical-fraction.v1';

  // Matches the handle's original fixed position (`right: 0, bottom:
  // 140`) as the first-launch default, so existing users see no visual
  // change until they actually drag it somewhere else.
  ChatbotHandleEdge _edge = ChatbotHandleEdge.right;
  double? _verticalFraction;
  bool _isLoaded = false;

  ChatbotHandleEdge get edge => _edge;

  /// Vertical position as a fraction (0.0 = top of the available safe
  /// area, 1.0 = bottom) of wherever the handle was last dropped, or
  /// `null` if the user has never dragged it yet — callers should fall
  /// back to the original fixed `bottom: 140` layout in that case.
  double? get verticalFraction => _verticalFraction;

  Future<void> load() async {
    if (_isLoaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedEdge = prefs.getString(_edgeKey);
      if (storedEdge == ChatbotHandleEdge.left.name) {
        _edge = ChatbotHandleEdge.left;
      } else if (storedEdge == ChatbotHandleEdge.right.name) {
        _edge = ChatbotHandleEdge.right;
      }
      final storedFraction = prefs.getDouble(_verticalFractionKey);
      if (storedFraction != null) {
        _verticalFraction = storedFraction.clamp(0.0, 1.0);
      }
    } catch (_) {
      // Keep the in-memory default if persistence is unavailable.
    }
    _isLoaded = true;
    notifyListeners();
  }

  /// Saves the handle's new docked edge and vertical fraction after a
  /// drag-and-snap gesture completes. Always persists both together
  /// (rather than separately) since a single drag gesture determines
  /// both at once.
  Future<void> setPosition({
    required ChatbotHandleEdge edge,
    required double verticalFraction,
  }) async {
    final clamped = verticalFraction.clamp(0.0, 1.0);
    if (_edge == edge && _verticalFraction == clamped) return;
    _edge = edge;
    _verticalFraction = clamped;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_edgeKey, edge.name);
      await prefs.setDouble(_verticalFractionKey, clamped);
    } catch (_) {}
  }
}
