import 'package:dart_frog/dart_frog.dart';
import 'package:yumyum_backend/services/session_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../routes/auth/refresh.dart' as route;
import '../../helpers/test_context.dart';

final _pair = TokenPair(
  accessToken: 'new-access',
  refreshToken: 'new-refresh',
  accessTokenExpiresAt: DateTime.fromMillisecondsSinceEpoch(86400 * 1000),
  refreshTokenExpiresAt: DateTime.fromMillisecondsSinceEpoch(259200 * 1000),
);

Future<Response> _invoke(
  Request request, {
  RefreshResult? result,
  MockSessionService? sessions,
}) {
  final service = sessions ?? MockSessionService();
  when(() => service.rotate(any()))
      .thenAnswer((_) async => result ?? RefreshSucceeded(_pair));

  final context = TestContext(request: request)
    ..provide<SessionService>(service);
  return Future.value(context.context).then(route.onRequest);
}

void main() {
  group('POST /auth/refresh', () {
    test('rejects every method except POST', () async {
      await expectMethodNotAllowed(_invoke, allowed: {'POST'});
    });

    test('responds 400 for a malformed JSON body', () async {
      final response = await _invoke(
        Request('POST', Uri.parse('http://localhost/'), body: 'nope'),
      );
      expect(response.statusCode, equals(400));
    });

    test('responds 422 when the token is missing or empty', () async {
      for (final body in [
        <String, dynamic>{},
        {'refreshToken': ''},
      ]) {
        final response = await _invoke(jsonRequest('POST', body: body));
        expect(response.statusCode, equals(422));
      }
    });

    // The route accepts both spellings; both are pinned so neither is dropped
    // by accident.
    for (final key in ['refreshToken', 'refresh_token']) {
      test('accepts the "$key" spelling', () async {
        final sessions = MockSessionService();
        final response = await _invoke(
          jsonRequest('POST', body: {key: 'presented'}),
          sessions: sessions,
        );

        expect(response.statusCode, equals(200));
        verify(() => sessions.rotate('presented')).called(1);
      });
    }

    test('returns the rotated pair', () async {
      final response = await _invoke(
        jsonRequest('POST', body: {'refreshToken': 'presented'}),
      );

      expect(response.statusCode, equals(200));
      expect(
        await jsonBody(response),
        equals({
          'access_token': 'new-access',
          'access_token_expires_at': 86400,
          'refresh_token': 'new-refresh',
          'refresh_token_expires_at': 259200,
        }),
      );
    });

    test('does not echo the user object', () async {
      final response = await _invoke(
        jsonRequest('POST', body: {'refreshToken': 'presented'}),
      );
      final json = await jsonBody(response) as Map<String, dynamic>;
      expect(json.containsKey('user'), isFalse);
    });

    test('responds 401 for a rejected token', () async {
      final response = await _invoke(
        jsonRequest('POST', body: {'refreshToken': 'presented'}),
        result: const RefreshRejected(),
      );

      expect(response.statusCode, equals(401));
      expect(
        await jsonBody(response),
        equals({'error': 'Invalid or expired refresh token'}),
      );
    });

    test('responds 404 when the user is gone', () async {
      final response = await _invoke(
        jsonRequest('POST', body: {'refreshToken': 'presented'}),
        result: const RefreshUserMissing(),
      );
      expect(response.statusCode, equals(404));
    });

    // A replayed token must not be answered differently from an ordinary bad
    // one, or the endpoint confirms to an attacker that the token they hold
    // was genuine.
    test('answers reuse exactly like an ordinary rejection', () async {
      final reuse = await _invoke(
        jsonRequest('POST', body: {'refreshToken': 'presented'}),
        result: const RefreshReuseDetected('family-1'),
      );
      final rejected = await _invoke(
        jsonRequest('POST', body: {'refreshToken': 'presented'}),
        result: const RefreshRejected(),
      );

      expect(reuse.statusCode, equals(rejected.statusCode));
      expect(await jsonBody(reuse), equals(await jsonBody(rejected)));
    });

    test('does not leak the revoked family id', () async {
      final response = await _invoke(
        jsonRequest('POST', body: {'refreshToken': 'presented'}),
        result: const RefreshReuseDetected('family-1'),
      );

      expect(await response.body(), isNot(contains('family-1')));
    });
  });
}
