import 'package:dart_frog/dart_frog.dart';
import 'package:delmer_backend/middleware/error_handler.dart';
import 'package:test/test.dart';

import '../helpers/test_context.dart';

Future<Response> _run(Handler handler) {
  final context = TestContext(request: jsonRequest('GET')).context;
  return Future.value(errorHandler()(handler)(context));
}

void main() {
  group('errorHandler', () {
    test('passes a successful response straight through', () async {
      final response = await _run((_) => Response(body: 'ok'));

      expect(response.statusCode, equals(200));
      expect(await response.body(), equals('ok'));
    });

    test('passes a non-200 response straight through', () async {
      final response = await _run((_) => Response(statusCode: 404));
      expect(response.statusCode, equals(404));
    });

    test('turns a synchronous throw into a JSON 500', () async {
      final response = await _run((_) => throw Exception('boom'));

      expect(response.statusCode, equals(500));
      expect(
        await jsonBody(response),
        equals({'error': 'Internal Server Error'}),
      );
    });

    test('turns an asynchronous throw into a JSON 500', () async {
      final response = await _run((_) async {
        await Future<void>.delayed(Duration.zero);
        throw StateError('boom');
      });

      expect(response.statusCode, equals(500));
    });

    // Database errors carry table names and SQL; none of that belongs in a
    // response body.
    test('does not leak the exception message to the client', () async {
      final response = await _run(
        (_) => throw Exception('relation "users" does not exist'),
      );

      final body = await response.body();
      expect(body, isNot(contains('users')));
      expect(body, isNot(contains('relation')));
    });
  });
}
