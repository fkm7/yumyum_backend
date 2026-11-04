import 'package:dart_frog/dart_frog.dart';
import 'package:test/test.dart';
import 'package:yumyum_backend/features/account/application/profile_service.dart';
import 'package:yumyum_backend/features/account/domain/user.dart';

import '../../../../../routes/api/v1/user/me/index.dart' as route;
import '../../../../helpers/fakes.dart';
import '../../../../helpers/test_context.dart';

const _user = User(
  uid: 'user-1',
  firstName: 'Ada',
  lastName: 'Lovelace',
  email: 'ada@example.com',
  photoUrl: 'ada.png',
);

/// Authentication is enforced by `routes/api/v1/user/_middleware.dart`
/// (covered in auth_middleware_test), so these start already signed in.
Future<Response> _invoke(Request request, {User? found = _user}) {
  final context = TestContext(request: request)
    ..authenticateAs('user-1')
    ..provide<ProfileService>(
      ProfileService(
        users: StubUserRepository(found),
        photos: InMemoryPhotoStorage(),
      ),
    );
  return Future.value(context.context).then(route.onRequest);
}

void main() {
  group('/api/v1/user/me', () {
    test('rejects every method except GET and POST', () async {
      await expectMethodNotAllowed(_invoke, allowed: {'GET', 'POST'});
    });

    group('GET', () {
      test('responds 200 with the user in snake_case', () async {
        final response = await _invoke(jsonRequest('GET'));

        expect(response.statusCode, equals(200));
        expect(
          await jsonBody(response),
          equals({
            'user': {
              'uid': 'user-1',
              'first_name': 'Ada',
              'last_name': 'Lovelace',
              'email': 'ada@example.com',
              'photo_url': 'ada.png',
            },
          }),
        );
      });

      test('responds 404 when the account is gone', () async {
        final response = await _invoke(jsonRequest('GET'), found: null);

        expect(response.statusCode, equals(404));
        expect(await jsonBody(response), equals({'error': 'User not found'}));
      });
    });

    group('POST', () {
      test('responds 400 for a malformed JSON body', () async {
        final response = await _invoke(
          Request('POST', Uri.parse('http://localhost/'), body: '{'),
        );

        expect(response.statusCode, equals(400));
      });

      test('responds 422 when fullname is not a string', () async {
        final response = await _invoke(
          jsonRequest('POST', body: {'fullname': 42}),
        );

        expect(response.statusCode, equals(422));
      });

      test('responds 200 with the updated user', () async {
        final response = await _invoke(
          jsonRequest('POST', body: {'fullname': 'Ada King Lovelace'}),
        );
        final json = await jsonBody(response) as Map<String, dynamic>;

        expect(response.statusCode, equals(200));
        expect(json['status'], equals('Success'));
        expect(json['user'], isA<Map<String, dynamic>>());
      });
    });
  });
}
