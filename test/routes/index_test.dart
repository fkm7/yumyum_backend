import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../routes/index.dart' as route;

class _MockRequestContext extends Mock implements RequestContext {}

void main() {
  group('GET /', () {
    test('serves the landing page from public/index.html', () async {
      final response = await route.onRequest(_MockRequestContext());

      expect(response.statusCode, equals(HttpStatus.ok));
      expect(
        response.headers[HttpHeaders.contentTypeHeader],
        startsWith('text/html'),
      );
      expect(
        await response.body(),
        equals(File('public/index.html').readAsStringSync()),
      );
    });
  });
}
