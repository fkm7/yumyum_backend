import 'package:dart_frog/dart_frog.dart';
import 'package:yumyum_backend/services/session_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../routes/auth/logout.dart' as route;
import '../../helpers/test_context.dart';

Future<Response> _invoke(Request request, {MockSessionService? sessions}) {
  final service = sessions ?? MockSessionService();
  when(() => service.revoke(any())).thenAnswer((_) async {});

  final context = TestContext(request: request)
    ..provide<SessionService>(service);
  return Future.value(context.context).then(route.onRequest);
}

void main() {
  group('POST /auth/logout', () {
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

    for (final key in ['refreshToken', 'refresh_token']) {
      test('accepts the "$key" spelling', () async {
        final sessions = MockSessionService();
        final response = await _invoke(
          jsonRequest('POST', body: {key: 'presented'}),
          sessions: sessions,
        );

        expect(response.statusCode, equals(204));
        verify(() => sessions.revoke('presented')).called(1);
      });
    }

    test('revokes the presented token', () async {
      final sessions = MockSessionService();
      await _invoke(
        jsonRequest('POST', body: {'refreshToken': 'presented'}),
        sessions: sessions,
      );

      verify(() => sessions.revoke('presented')).called(1);
    });

    test('responds 204 with an empty body', () async {
      final response = await _invoke(
        jsonRequest('POST', body: {'refreshToken': 'presented'}),
      );

      expect(response.statusCode, equals(204));
      expect(await response.body(), isEmpty);
    });

    // Logout must not double as a probe for which tokens are live, so an
    // unknown token is answered exactly like a real one.
    test('answers identically for an unrecognised token', () async {
      final known = await _invoke(
        jsonRequest('POST', body: {'refreshToken': 'presented'}),
      );
      final unknown = await _invoke(
        jsonRequest('POST', body: {'refreshToken': 'never-issued'}),
      );

      expect(known.statusCode, equals(unknown.statusCode));
      expect(await known.body(), equals(await unknown.body()));
    });

    // A client whose access token has already expired still needs to be able
    // to log out, so no Authorization header is required.
    test('does not require an access token', () async {
      final response = await _invoke(
        jsonRequest('POST', body: {'refreshToken': 'presented'}),
      );

      expect(response.statusCode, equals(204));
    });

    test('is idempotent', () async {
      final sessions = MockSessionService();
      final request = {'refreshToken': 'presented'};

      final first = await _invoke(
        jsonRequest('POST', body: request),
        sessions: sessions,
      );
      final second = await _invoke(
        jsonRequest('POST', body: request),
        sessions: sessions,
      );

      expect(first.statusCode, equals(204));
      expect(second.statusCode, equals(204));
    });
  });
}
