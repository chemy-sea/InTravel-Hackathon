import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:intravel/services/chat_memory_service.dart';
import 'package:intravel/services/gemini_api_key_loader.dart';
import 'package:intravel/services/gemini_chat_service.dart';

/// Fake client that never completes its response — simulates a hung
/// Backboard request (dead connection, stuck server-side) with no error
/// and no response, ever. Uses Backboard's real `{status, content}` wire
/// shape for its (never-delivered) body, matching what
/// [GeminiChatService] actually parses today — deliberately not the
/// stale pre-migration Gemini SDK shape the other retry-test fixtures
/// still use.
class _HangingClient extends http.BaseClient {
  int requestCount = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requestCount++;
    // Never completes within the test's lifetime — the service's own
    // `.timeout(...)` is what must cut this short, not this fake.
    await Completer<void>().future;
    // Unreachable, but keeps the return type honest.
    return http.StreamedResponse(const Stream.empty(), 200);
  }
}

/// Fake client that completes quickly but past the point a caller should
/// be willing to wait — used to prove the timeout actually fires instead
/// of just hoping a hanging future never resolves.
class _SlowThenHealthyClient extends http.BaseClient {
  _SlowThenHealthyClient(this.delays);

  /// One delay per request, consumed in order.
  final List<Duration> delays;
  int requestCount = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final delay = delays[requestCount.clamp(0, delays.length - 1)];
    requestCount++;
    await Future<void>.delayed(delay);
    final body = jsonEncode({'status': 'COMPLETED', 'content': 'pong'});
    return http.StreamedResponse(
      Stream.value(utf8.encode(body)),
      200,
      headers: const {'content-type': 'application/json'},
    );
  }
}

/// Locks in the timeout handling added so a hung Backboard call fails
/// gracefully (retries, then a catchable [GeminiChatException]) instead
/// of leaving the caller's `await` — and the chat sheet's typing
/// indicator — waiting forever.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ChatMemoryService.instance.clear();
    rootBundle.evict('env.json');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', (message) async {
          final key = utf8.decode(message!.buffer.asUint8List());
          if (key == 'env.json') {
            final bytes = utf8.encode('{"BACKBOARD_API_KEY": ""}');
            return ByteData.view(Uint8List.fromList(bytes).buffer);
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', null);
  });

  GeminiChatService serviceWith(http.Client client) => GeminiChatService(
    apiKeyLoader: GeminiApiKeyLoader(compileTimeApiKey: 'test-key'),
    httpClient: client,
  );

  test(
    'a request that never responds eventually fails with a '
    'GeminiChatException instead of hanging forever',
    () async {
      final client = _HangingClient();

      await expectLater(
        serviceWith(client).sendMessage('ping'),
        throwsA(isA<GeminiChatException>()),
      );
      // Every attempt timed out, so the bounded retry loop still ran to
      // its full 3 attempts — a timeout is treated as transient, same
      // as any other capacity/network blip.
      expect(client.requestCount, 3);
    },
    // The fake itself never completes, so this test's own wall-clock
    // bound is the service's timeout (20s) times up to 3 attempts plus
    // backoff — give it enough headroom not to flake on a slow CI box.
    timeout: const Timeout(Duration(seconds: 90)),
  );

  test(
    'a slow-but-eventually-successful request still succeeds as long as '
    'it beats the timeout',
    () async {
      final client = _SlowThenHealthyClient([const Duration(milliseconds: 50)]);

      final result = await serviceWith(client).sendMessage('ping');

      expect(result.text, 'pong');
      expect(
        client.requestCount,
        1,
        reason: 'a fast-enough response must not be treated as a timeout',
      );
    },
  );
}
