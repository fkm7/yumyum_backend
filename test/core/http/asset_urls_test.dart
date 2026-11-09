import 'package:dart_frog/dart_frog.dart';
import 'package:test/test.dart';
import 'package:yumyum_backend/core/http/asset_urls.dart';

import '../../helpers/test_context.dart';

Future<Response> _run(String url, Handler handler) {
  final request = Request.get(Uri.parse(url));
  final context = TestContext(request: request).context;
  return Future.value(assetUrls()(handler)(context));
}

void main() {
  group('resolveAssetUrls', () {
    final origin = Uri.parse('https://api.example.com/api/v1/x?page=2');

    test('resolves /assets/ paths against the origin, dropping path & query',
        () {
      expect(
        resolveAssetUrls('/assets/categories/burger.svg', origin),
        equals('https://api.example.com/assets/categories/burger.svg'),
      );
    });

    test('keeps the port of a local server', () {
      expect(
        resolveAssetUrls(
          '/assets/products/fries.jpg',
          Uri.parse('http://10.0.2.2:8080/api/v1/products'),
        ),
        equals('http://10.0.2.2:8080/assets/products/fries.jpg'),
      );
    });

    test('walks nested maps and lists', () {
      final json = {
        'logo': '/assets/restaurants/bh_logo.jpg',
        'category': {'icon': '/assets/categories/burger.svg'},
        'items': [
          {'image': '/assets/products/fries.jpg'},
        ],
      };

      expect(
        resolveAssetUrls(json, origin),
        equals({
          'logo': 'https://api.example.com/assets/restaurants/bh_logo.jpg',
          'category': {
            'icon': 'https://api.example.com/assets/categories/burger.svg',
          },
          'items': [
            {'image': 'https://api.example.com/assets/products/fries.jpg'},
          ],
        }),
      );
    });

    test('leaves absolute URLs, other strings, numbers and nulls alone', () {
      final json = {
        'icon': 'https://cdn.example.com/assets/a.png',
        'name': 'assets/not-a-path',
        'price': 25000.0,
        'image': null,
      };

      expect(resolveAssetUrls(json, origin), equals(json));
    });
  });

  group('assetUrls middleware', () {
    test('rewrites asset paths in a JSON body using the request host',
        () async {
      final response = await _run(
        'http://localhost:8080/api/v1/categories',
        (_) => Response.json(
          body: [
            {'id': 1, 'icon': '/assets/categories/burger.svg'},
          ],
        ),
      );

      expect(response.statusCode, equals(200));
      expect(
        await jsonBody(response),
        equals([
          {
            'id': 1,
            'icon': 'http://localhost:8080/assets/categories/burger.svg',
          },
        ]),
      );
    });

    test('keeps the status code of a rewritten response', () async {
      final response = await _run(
        'http://localhost:8080/api/v1/user/favorites/products',
        (_) => Response.json(
          statusCode: 201,
          body: {'image': '/assets/products/fries.jpg'},
        ),
      );

      expect(response.statusCode, equals(201));
      expect(
        await jsonBody(response),
        equals({'image': 'http://localhost:8080/assets/products/fries.jpg'}),
      );
    });

    test('passes JSON without asset paths through unchanged', () async {
      final response = await _run(
        'http://localhost:8080/api/v1/x',
        (_) => Response.json(body: {'error': 'Not found'}, statusCode: 404),
      );

      expect(response.statusCode, equals(404));
      expect(await jsonBody(response), equals({'error': 'Not found'}));
    });

    test('does not touch non-JSON responses', () async {
      final response = await _run(
        'http://localhost:8080/api/v1/x',
        (_) => Response(body: '"/assets/a.png"'),
      );

      expect(await response.body(), equals('"/assets/a.png"'));
    });
  });
}
