import 'package:dart_frog/dart_frog.dart';
import 'package:delmer_backend/auth/password_hasher.dart';
import 'package:delmer_backend/models/user.dart';
import 'package:delmer_backend/repositories/user_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../routes/auth/login.dart' as route;
import '../../helpers/test_context.dart';

final _user = User(
  uid: 'user-1',
  firstName: 'Ada',
  lastName: 'Lovelace',
  email: 'ada@example.com',
  photoUrl: '',
  passwordHash: hashPassword('hunter2'),
);

Future<Response> _invoke(Request request, {User? found}) {
  final repository = MockUserRepository();
  when(() => repository.findByEmail(any())).thenAnswer((_) async => found);
  return Future.value(
    (TestContext(request: request)..provide<UserRepository>(repository))
        .context,
  ).then(route.onRequest);
}

void main() {
  group('POST /auth/login', () {
    test('rejects every method except POST', () async {
      await expectMethodNotAllowed(_invoke, allowed: {'POST'});
    });

    test('responds 400 for a malformed JSON body', () async {
      final response = await _invoke(
        Request('POST', Uri.parse('http://localhost/'), body: 'not json'),
      );

      expect(response.statusCode, equals(400));
      expect(await jsonBody(response), equals({'error': 'Invalid JSON'}));
    });

    test('responds 422 when email or password is missing', () async {
      for (final body in [
        <String, dynamic>{},
        {'email': 'ada@example.com'},
        {'password': 'hunter2'},
      ]) {
        final response = await _invoke(jsonRequest('POST', body: body));
        expect(response.statusCode, equals(422));
      }
    });

    test('responds 401 for an unknown email', () async {
      final response = await _invoke(
        jsonRequest(
          'POST',
          body: {'email': 'nobody@example.com', 'password': 'hunter2'},
        ),
      );

      expect(response.statusCode, equals(401));
    });

    test('responds 401 for a wrong password', () async {
      final response = await _invoke(
        jsonRequest(
          'POST',
          body: {'email': 'ada@example.com', 'password': 'wrong'},
        ),
        found: _user,
      );

      expect(response.statusCode, equals(401));
    });

    // Anti-enumeration: the two failures must be indistinguishable, or the
    // endpoint tells an attacker which addresses are registered.
    test('answers identically for an unknown email and a wrong password',
        () async {
      final unknown = await _invoke(
        jsonRequest(
          'POST',
          body: {'email': 'nobody@example.com', 'password': 'hunter2'},
        ),
      );
      final wrongPassword = await _invoke(
        jsonRequest(
          'POST',
          body: {'email': 'ada@example.com', 'password': 'wrong'},
        ),
        found: _user,
      );

      expect(unknown.statusCode, equals(wrongPassword.statusCode));
      expect(await jsonBody(unknown), equals(await jsonBody(wrongPassword)));
    });

    group('on success', () {
      Future<Map<String, dynamic>> body() async {
        final response = await _invoke(
          jsonRequest(
            'POST',
            body: {'email': 'ada@example.com', 'password': 'hunter2'},
          ),
          found: _user,
        );
        expect(response.statusCode, equals(200));
        return await jsonBody(response) as Map<String, dynamic>;
      }

      test('returns an access token that verifies to the uid', () async {
        final json = await body();
        expect(
          testTokens.verifyAccessToken(json['access_token'] as String),
          equals('user-1'),
        );
      });

      test('returns a refresh token that verifies to the uid', () async {
        final json = await body();
        expect(
          testTokens.verifyRefreshToken(json['refresh_token'] as String),
          equals('user-1'),
        );
      });

      test('reports both token lifetimes in seconds', () async {
        final json = await body();
        expect(json['access_token_expires_in'], equals(86400));
        expect(json['refresh_token_expires_in'], equals(259200));
      });

      test('returns the user in snake_case', () async {
        final json = await body();
        expect(
          json['user'],
          equals({
            'uid': 'user-1',
            'first_name': 'Ada',
            'last_name': 'Lovelace',
            'email': 'ada@example.com',
            'photo_url': '',
          }),
        );
      });

      // The digest is loaded for the comparison, so the response is the place
      // it could leak.
      test('never leaks the password hash', () async {
        final json = await body();
        expect(json.toString(), isNot(contains(_user.passwordHash)));
        expect((json['user']! as Map).containsKey('password_hash'), isFalse);
      });
    });
  });
}
