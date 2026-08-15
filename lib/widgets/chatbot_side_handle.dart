import 'package:flutter/material.dart';
import '../main.dart' show chatbotNavigatorKey;
import '../services/chatbot_handle_position_service.dart';
import '../services/chatbot_page_context_service.dart';
import '../services/chatbot_visibility_service.dart';
import '../theme/app_theme.dart';
import 'chatbot_chat_sheet.dart';
import 'chatbot_avatar.dart';

/// The IntraBadi assistant's entry point (chatbot spec Section 1): "a
/// toggleable side icon, visible on every page of the app — not a fixed
/// floating bubble that's always sitting on-screen. The user can
/// show/hide it themselves (e.g., a small tab or handle on the side of
/// the screen that expands into the chat button when tapped, and can be
/// collapsed/hidden again when not needed)."
///
/// Two visual states, docked to whichever screen edge (left or right)
/// the user last dragged it to (improvement-batch spec: "movable/
/// draggable side handle" — see [ChatbotHandlePositionService]):
/// - **Collapsed**: a slim vertical tab/handle the user taps to reveal
///   the full chat button.
/// - **Expanded**: the full round chat icon button, with a small
///   collapse affordance to hide it again.
///
/// Dragging (either state): freely follows the finger while dragging,
/// then animates to snap against whichever edge is closer once released
/// — the same pattern as Messenger's chat bubble / Android's
/// accessibility button — rather than staying wherever it's dropped.
/// Vertical position is clamped to the safe area (notch, system nav bar)
/// automatically; it does not auto-avoid other floating buttons (e.g.
/// the map re-center button) — manual placement is acceptable, and the
/// user can always just drag it away from an overlap.
///
/// Shown/hidden state is read from [ChatbotVisibilityService] (the
/// user's permanent show/hide preference), further suppressed while the
/// chat window itself is open ([_isChatOpen] — deliberately transient,
/// not persisted, and independent of both the visibility preference and
/// the dragged position: closing the chat always restores the handle
/// exactly where it was, regardless of the permanent preference or the
/// last docked position).
class ChatbotSideHandle extends StatefulWidget {
  const ChatbotSideHandle({super.key});

  @override
  State<ChatbotSideHandle> createState() => _ChatbotSideHandleState();
}

class _ChatbotSideHandleState extends State<ChatbotSideHandle> {
  bool _expanded = false;

  /// True while the chat sheet opened from this handle is on screen —
  /// transient (never persisted), and independent of
  /// [ChatbotVisibilityService]'s permanent show/hide preference: the
  /// handle hides for the duration of the chat and reappears exactly as
  /// it was the moment the sheet closes, by any dismissal method (close
  /// button, drag-down, tap-outside, back gesture — [showChatbotChatSheet]
  /// resolves its returned future on all of them the same way).
  bool _isChatOpen = false;

  // ─── Drag state ───────────────────────────────────────────────────────
  // The handle's rendered position is always expressed as `left`/`top`
  // (never `right`/`bottom`) so drag math never has to juggle two
  // coordinate systems: "docked right" is simply `left == screenWidth -
  // handleWidth`. [_liveLeft]/[_liveTop] hold the *current* on-screen
  // position and are kept in sync with the persisted docked
  // edge/vertical-fraction on every build unless a drag is in progress
  // (or its post-release snap animation hasn't finished yet), in which
  // case they're the source of truth instead.
  double? _liveLeft;
  double? _liveTop;
  bool _dragging = false;

  /// Bumped on every drag release so a delayed cleanup from an earlier
  /// drag (see [_onPanEnd]) can detect it's stale and not clobber a
  /// newer one.
  int _dragGeneration = 0;

  static const Duration _snapDuration = Duration(milliseconds: 220);

  /// Estimated handle footprint per expand state, used only for edge/
  /// clamping math (which edge is closer, keeping it inside the safe
  /// area) — doesn't need to be pixel-exact since [Positioned] still
  /// sizes the actual child by its own intrinsic size regardless of
  /// this estimate.
  Size get _handleSize => _expanded ? const Size(66, 84) : const Size(26, 56);

  void _openChat() async {
    // `context` here has no Navigator ancestor: this widget is
    // deliberately mounted in `MaterialApp.builder`, above/outside the
    // Navigator's subtree (see main.dart), so it persists across page
    // push/pop instead of being rebuilt. Use the app-wide
    // `chatbotNavigatorKey` to reach a context that *does* sit inside
    // the Navigator, so `showModalBottomSheet` (called from
    // `showChatbotChatSheet`) can find it via `Navigator.of(context)`.
    final navigatorContext = chatbotNavigatorKey.currentState?.context;
    if (navigatorContext == null) return;
    setState(() => _isChatOpen = true);
    try {
      await showChatbotChatSheet(
        navigatorContext,
        // Forwards whichever location the user is currently viewing (see
        // [ChatbotPageContextService]) so vague follow-ups like "tell me
        // more about this place" resolve. This was previously never
        // supplied, leaving the engine's page-awareness path inert.
        currentPageContext:
            ChatbotPageContextService.instance.currentLocationId,
      );
    } finally {
      if (mounted) setState(() => _isChatOpen = false);
    }
  }

  void _hideHandleEntirely() {
    ChatbotVisibilityService.instance.setVisible(false);
  }

  /// Resolves the handle's idle (non-dragging) `left`/`top` from the
  /// persisted docked edge + vertical fraction, falling back to the
  /// original fixed right-edge/`bottom: 140` position for a user who has
  /// never dragged the handle yet (`verticalFraction == null`).
  Offset _idlePosition(Size screenSize, EdgeInsets safeArea) {
    final handleSize = _handleSize;
    final positionService = ChatbotHandlePositionService.instance;
    final fraction = positionService.verticalFraction;

    final left = positionService.edge == ChatbotHandleEdge.left
        ? 0.0
        : screenSize.width - handleSize.width;

    if (fraction == null) {
      // Never dragged: reproduce the original fixed position exactly
      // (right edge, 140 logical pixels above the bottom of the
      // screen) so existing users see no visual change at all until
      // they actually drag the handle somewhere else.
      final top = screenSize.height - 140 - handleSize.height;
      return Offset(left, top);
    }

    final availableHeight =
        screenSize.height - safeArea.top - safeArea.bottom - handleSize.height;
    final top =
        safeArea.top + fraction * availableHeight.clamp(0.0, double.infinity);
    return Offset(left, top);
  }

  void _onPanStart(DragStartDetails details, Offset idle) {
    setState(() {
      _dragging = true;
      _liveLeft = idle.dx;
      _liveTop = idle.dy;
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    final media = MediaQuery.of(context);
    final handleSize = _handleSize;
    setState(() {
      _liveLeft = (_liveLeft! + details.delta.dx).clamp(
        0.0,
        media.size.width - handleSize.width,
      );
      _liveTop = (_liveTop! + details.delta.dy).clamp(
        media.padding.top,
        media.size.height - media.padding.bottom - handleSize.height,
      );
    });
  }

  void _onPanEnd(DragEndDetails details) {
    final media = MediaQuery.of(context);
    final handleSize = _handleSize;
    final screenWidth = media.size.width;
    final currentCenterX = _liveLeft! + handleSize.width / 2;
    final targetEdge = currentCenterX < screenWidth / 2
        ? ChatbotHandleEdge.left
        : ChatbotHandleEdge.right;
    final targetLeft = targetEdge == ChatbotHandleEdge.left
        ? 0.0
        : screenWidth - handleSize.width;

    final availableHeight =
        media.size.height -
        media.padding.top -
        media.padding.bottom -
        handleSize.height;
    final verticalFraction = availableHeight <= 0
        ? 0.0
        : ((_liveTop! - media.padding.top) / availableHeight).clamp(0.0, 1.0);

    final generation = ++_dragGeneration;
    setState(() {
      _dragging = false;
      _liveLeft = targetLeft;
      // _liveTop stays as-is: only the horizontal position snaps to an
      // edge, vertical position is exactly where the user released it
      // (already clamped to the safe area in [_onPanUpdate]).
    });
    ChatbotHandlePositionService.instance.setPosition(
      edge: targetEdge,
      verticalFraction: verticalFraction,
    );
    // Once the snap-to-edge animation has finished, drop the live
    // override so future rebuilds (e.g. a screen rotation resizing the
    // available safe area) recompute the idle position fresh from the
    // just-persisted edge/fraction instead of an animation-time
    // snapshot. Guarded by [_dragGeneration] so a second drag started
    // before this fires doesn't have its own live position yanked out
    // from under it.
    Future.delayed(_snapDuration, () {
      if (mounted && generation == _dragGeneration) {
        setState(() {
          _liveLeft = null;
          _liveTop = null;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final media = MediaQuery.of(context);

    return AnimatedBuilder(
      animation: Listenable.merge([
        ChatbotVisibilityService.instance,
        ChatbotHandlePositionService.instance,
      ]),
      builder: (context, _) {
        if (!ChatbotVisibilityService.instance.isVisible || _isChatOpen) {
          return const SizedBox.shrink();
        }

        final idle = _idlePosition(media.size, media.padding);
        final left = _liveLeft ?? idle.dx;
        final top = _liveTop ?? idle.dy;
        // The docked edge for the *currently rendered* position — used
        // to mirror the collapsed tab's chevron/rounded-corner side and
        // the expanded handle's inner padding. While actively dragging,
        // this tracks whichever half of the screen the finger is
        // currently over, so the visuals preview the eventual snap
        // target instead of only updating after release.
        final renderedEdge =
            (left + _handleSize.width / 2) < media.size.width / 2
            ? ChatbotHandleEdge.left
            : ChatbotHandleEdge.right;

        final handle = AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: SizeTransition(
              sizeFactor: animation,
              axis: Axis.horizontal,
              alignment: renderedEdge == ChatbotHandleEdge.left
                  ? Alignment.centerLeft
                  : Alignment.centerRight,
              child: child,
            ),
          ),
          child: _expanded
              ? _ExpandedHandle(
                  key: const ValueKey('expanded'),
                  colors: colors,
                  edge: renderedEdge,
                  onOpenChat: _openChat,
                  onCollapse: () => setState(() => _expanded = false),
                  onHide: _hideHandleEntirely,
                )
              : _CollapsedTab(
                  key: const ValueKey('collapsed'),
                  colors: colors,
                  edge: renderedEdge,
                  onTap: () => setState(() => _expanded = true),
                ),
        );

        final draggable = GestureDetector(
          // No `onTap` here: leaving it unset lets a plain tap (no
          // meaningful movement) still resolve to the inner button's own
          // `onTap`/`InkWell` via the gesture arena, while any real
          // drag movement is captured by this pan recognizer instead —
          // the standard way a draggable control coexists with its own
          // tap targets.
          onPanStart: (details) => _onPanStart(details, Offset(left, top)),
          onPanUpdate: _onPanUpdate,
          onPanEnd: _onPanEnd,
          child: handle,
        );

        // Always the same widget type/position in the tree (unlike
        // switching between `Positioned` and `AnimatedPositioned`, which
        // would tear down and recreate the `GestureDetector` element
        // mid-drag — killing the pan gesture arena right after the
        // first `onPanStart`, before any `onPanUpdate`/`onPanEnd` could
        // ever fire). Animate only when not actively being dragged
        // (zero duration while dragging), so releasing still snaps
        // smoothly to the target edge, but the handle follows the
        // finger immediately with no animation lag while being dragged.
        return AnimatedPositioned(
          duration: _dragging ? Duration.zero : _snapDuration,
          curve: Curves.easeOut,
          left: left,
          top: top,
          child: draggable,
        );
      },
    );
  }
}

/// The slim, mostly-off-screen tab shown when the handle is collapsed.
/// Tapping it reveals the full chat button ([_ExpandedHandle]). Mirrors
/// its rounded corner and chevron direction to whichever edge ([edge])
/// it's currently docked to.
class _CollapsedTab extends StatelessWidget {
  final AppColors colors;
  final ChatbotHandleEdge edge;
  final VoidCallback onTap;

  const _CollapsedTab({
    super.key,
    required this.colors,
    required this.edge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isLeft = edge == ChatbotHandleEdge.left;
    final radius = BorderRadius.horizontal(
      left: isLeft ? Radius.zero : const Radius.circular(16),
      right: isLeft ? const Radius.circular(16) : Radius.zero,
    );
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Container(
          width: 26,
          height: 56,
          decoration: BoxDecoration(
            color: colors.forest,
            borderRadius: radius,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 6,
                offset: Offset(isLeft ? 1 : -1, 2),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Icon(
            isLeft ? Icons.chevron_right_rounded : Icons.chevron_left_rounded,
            size: 18,
            color: Colors.white.withValues(alpha: 0.85),
          ),
        ),
      ),
    );
  }
}

/// The full round chat-launcher button, shown once the user taps the
/// collapsed tab. Tapping the icon opens the chat window; the small
/// secondary control lets the user collapse the handle back down or hide
/// it entirely, per spec. Mirrors its inner edge-gap padding to whichever
/// edge ([edge]) it's currently docked to.
class _ExpandedHandle extends StatelessWidget {
  final AppColors colors;
  final ChatbotHandleEdge edge;
  final VoidCallback onOpenChat;
  final VoidCallback onCollapse;
  final VoidCallback onHide;

  const _ExpandedHandle({
    super.key,
    required this.colors,
    required this.edge,
    required this.onOpenChat,
    required this.onCollapse,
    required this.onHide,
  });

  @override
  Widget build(BuildContext context) {
    final isLeft = edge == ChatbotHandleEdge.left;
    return Padding(
      padding: EdgeInsets.only(left: isLeft ? 10 : 0, right: isLeft ? 0 : 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Collapse-back-to-tab control, kept small/secondary since the
          // main action on this handle is opening the chat, not hiding it.
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onCollapse,
              customBorder: const CircleBorder(),
              onLongPress: onHide,
              child: Container(
                width: 22,
                height: 22,
                margin: const EdgeInsets.only(bottom: 6),
                decoration: BoxDecoration(
                  color: colors.card,
                  shape: BoxShape.circle,
                  border: Border.all(color: colors.line),
                ),
                child: Icon(
                  isLeft
                      ? Icons.chevron_left_rounded
                      : Icons.chevron_right_rounded,
                  size: 14,
                  color: colors.muted,
                ),
              ),
            ),
          ),
          // Character only — the forest-green circle and its drop shadow
          // are gone, per the confirmed "transparent background, character
          // only" requirement, so the eagle floats directly on the page.
          //
          // Locked to `idle` on purpose: this handle is persistently
          // on-screen on every page, so the expressive states would be a
          // constant distraction and a continuous frame/battery cost for no
          // benefit. Expressive states live in the chat sheet, where the
          // user is actually engaged.
          GestureDetector(
            onTap: onOpenChat,
            behavior: HitTestBehavior.opaque,
            child: const SizedBox(
              width: 56,
              height: 56,
              child: Center(
                child: ChatbotAvatar(
                  state: ChatbotAvatarState.idle,
                  size: 52,
                  // Static: creates no tickers, so the always-on-screen
                  // handle costs nothing per frame.
                  animate: false,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
