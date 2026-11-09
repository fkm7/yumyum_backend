import 'dart:async';

import 'package:dart_frog/dart_frog.dart';
import 'package:yumyum_backend/features/auth/presentation/authenticated_user.dart';
import 'package:yumyum_backend/features/favorites/application/favorites_service.dart';

FutureOr<Response> onRequest(RequestContext context) async {
  return switch (context.request.method) {
    HttpMethod.get => await _list(context),
    HttpMethod.post => await _add(context),
    _ => Response(statusCode: 405),
  };
}

Future<Response> _list(RequestContext context) async {
  final user = context.read<AuthenticatedUser>();
  final products = await context.read<FavoritesService>().products(user.uid);
  return Response.json(body: products.map((e) => e.toJson()).toList());
}

Future<Response> _add(RequestContext context) async {
  final Map<String, dynamic> body;
  try {
    body = await context.request.json() as Map<String, dynamic>;
  } catch (_) {
    return Response.json(statusCode: 400, body: {'error': 'Invalid JSON'});
  }

  final productId = body['productId'];
  if (productId is! int) {
    return Response.json(
      statusCode: 422,
      body: {'error': 'productId is required and must be an integer'},
    );
  }

  final user = context.read<AuthenticatedUser>();
  final product =
      await context.read<FavoritesService>().addProduct(user.uid, productId);
  if (product == null) {
    return Response.json(
      statusCode: 404,
      body: {'error': 'Product not found'},
    );
  }

  return Response.json(statusCode: 201, body: product.toJson());
}
