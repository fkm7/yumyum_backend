import 'package:dart_frog/dart_frog.dart';
import 'package:delmer_backend/auth/authenticated_user.dart';
import 'package:delmer_backend/auth/token_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../helpers/test_context.dart';

/// Result of driving [authMiddleware] with a given Authorization header.
class _Run {
  _Run({String? authorization}) {
    final testContext = TestContext(
      request: jsonRequest(
        'GET',
        headers:
            authorization == null ? null : {'Authorization': authorization},
      ),
    );
    outer = testContext.context;

    // `provide` returns a fresh context; the inner handler reads the identity
    // off that one.
    when(() => outer.provide<AuthenticatedUser>(any())).thenAnswer((
      invocation,
    ) {
      final create =
          invocation.positionalArguments.first as AuthenticatedUser Function();
      provided = create();
      when(() => inner.read<AuthenticatedUser>()).thenReturn(provided!);
      return inner;
    });
    when(() => inner.request).thenReturn(outer.request);
  }

  late final MockRequestContext outer;
  final MockRequestContext inner = MockRequestContext();
  AuthenticatedUser? provided;
  bool handlerRan = false;

  Future<Response> call() {
    final handler = authMiddleware()((context) {
      handlerRan = true;
      return Response(body: 'reached the handler');
    });
    return Future.value(handler(outer));
  }
}

void main() {
  setUpAll(() {
    registerFallbackValue(() => const AuthenticatedUser('fallback'));
  });

  group('authMiddleware', () {
    // Calling onRequest directly bypasses middleware entirely, so this is the
    // only place enforcement itself gets covered.
    group('rejects the request without running the handler', () {
      final rejected = <String, String?>{
        'no Authorization header': null,
        'empty header': '',
        'non-Bearer scheme': 'Basic abc123',
        'Bearer with no token': 'Bearer ',
        'garbage token': 'Bearer nonsense',
      };

      for (final entry in rejected.entries) {
        test(entry.key, () async {
          final run = _Run(authorization: entry.value);
          final response = await run.call();

          expect(response.statusCode, equals(401));
          expect(await jsonBody(response), equals({'error': 'Unauthorized'}));
          expect(
            run.handlerRan,
            isFalse,
            reason: 'the handler must never see an unauthenticated request',
          );
        });
      }

      test('a refresh token presented as an access token', () async {
        final refresh = testTokens.generateRefreshToken('user-1');
        final run = _Run(authorization: 'Bearer $refresh');

        expect((await run.call()).statusCode, equals(401));
        expect(run.handlerRan, isFalse);
      });

      test('an expired access token', () async {
        const expired = TokenService(
          secret: 'test-secret',
          accessTokenExpiresIn: Duration(seconds: -1),
        );
        final run = _Run(
          authorization: 'Bearer ${expired.generateAccessToken('user-1')}',
        );

        expect((await run.call()).statusCode, equals(401));
        expect(run.handlerRan, isFalse);
      });

      test('a token signed with a different secret', () async {
        const attacker = TokenService(secret: 'other-secret');
        final run = _Run(
          authorization: 'Bearer ${attacker.generateAccessToken('user-1')}',
        );

        expect((await run.call()).statusCode, equals(401));
        expect(run.handlerRan, isFalse);
      });
    });

    group('accepts a valid access token', () {
      test('runs the handler', () async {
        final token = testTokens.generateAccessToken('user-1');
        final run = _Run(authorization: 'Bearer $token');

        final response = await run.call();

        expect(response.statusCode, equals(200));
        expect(run.handlerRan, isTrue);
      });

      test('provides the uid carried by the token', () async {
        final token = testTokens.generateAccessToken('user-42');
        final run = _Run(authorization: 'Bearer $token');

        await run.call();

        expect(run.provided?.uid, equals('user-42'));
      });

      test('matches the scheme case-insensitively', () async {
        final token = testTokens.generateAccessToken('user-1');
        for (final scheme in ['Bearer', 'bearer', 'BEARER']) {
          final run = _Run(authorization: '$scheme $token');
          expect(
            (await run.call()).statusCode,
            equals(200),
            reason: '"$scheme" should be accepted',
          );
        }
      });
    });
  });
}
