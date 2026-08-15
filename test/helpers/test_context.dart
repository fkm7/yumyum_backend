import 'dart:convert';

import 'package:dart_frog/dart_frog.dart';
import 'package:delmer_backend/auth/authenticated_user.dart';
import 'package:delmer_backend/auth/token_service.dart';
import 'package:delmer_backend/repositories/category_repository.dart';
import 'package:delmer_backend/repositories/order_repository.dart';
import 'package:delmer_backend/repositories/product_repository.dart';
import 'package:delmer_backend/repositories/restaurant_repository.dart';
import 'package:delmer_backend/repositories/user_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

/// A mock [RequestContext].
class MockRequestContext extends Mock implements RequestContext {}

/// A mock [UserRepository].
class MockUserRepository extends Mock implements UserRepository {}

/// A mock [CategoryRepository].
class MockCategoryRepository extends Mock implements CategoryRepository {}

/// A mock [RestaurantRepository].
class MockRestaurantRepository extends Mock implements RestaurantRepository {}

/// A mock [ProductRepository].
class MockProductRepository extends Mock implements ProductRepository {}

/// A mock [OrderRepository].
class MockOrderRepository extends Mock implements OrderRepository {}

/// The [TokenService] used across route tests.
const testTokens = TokenService(secret: 'test-secret');

/// A [RequestContext] wired for a single route invocation.
///
/// The mock boundary sits at the repository interfaces, so no test ever has to
/// fake a postgres `Connection`, `Result`, or `ResultRow`.
class TestContext {
  /// Builds a context around [request], defaulting to `GET /`.
  TestContext({Request? request}) {
    when(() => context.request).thenReturn(
      request ?? Request.get(Uri.parse('http://localhost/')),
    );
    provide<TokenService>(testTokens);
  }

  /// The underlying mock handed to `onRequest`.
  final MockRequestContext context = MockRequestContext();

  /// Makes [value] readable from the context as a [T].
  void provide<T extends Object>(T value) {
    when(() => context.read<T>()).thenReturn(value);
  }

  /// Marks this request as authenticated as [uid].
  void authenticateAs(String uid) {
    provide<AuthenticatedUser>(AuthenticatedUser(uid));
  }
}

/// Builds a JSON request with the given [method], [body] and [headers].
Request jsonRequest(
  String method, {
  Object? body,
  Map<String, String>? headers,
  String path = 'http://localhost/',
  Map<String, String>? query,
}) {
  final uri = Uri.parse(path).replace(queryParameters: query);
  return Request(
    method,
    uri,
    body: body == null ? null : jsonEncode(body),
    headers: {'Content-Type': 'application/json', ...?headers},
  );
}

/// Decodes a JSON response body.
Future<dynamic> jsonBody(Response response) async =>
    jsonDecode(await response.body());

/// Asserts that [invoke] answers 405 for every method except [allowed].
///
/// Every route hand-rolls its own method check, so this covers the branch
/// uniformly instead of once per route by hand.
Future<void> expectMethodNotAllowed(
  Future<Response> Function(Request request) invoke, {
  required Set<String> allowed,
}) async {
  const methods = ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'HEAD'];
  for (final method in methods.where((m) => !allowed.contains(m))) {
    final response = await invoke(jsonRequest(method));
    expect(
      response.statusCode,
      equals(405),
      reason: '$method should not be allowed',
    );
  }
}
