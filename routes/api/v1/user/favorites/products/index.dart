import 'dart:async';

import 'package:dart_frog/dart_frog.dart';
import 'package:yumyum_backend/auth/authenticated_user.dart';
import 'package:yumyum_backend/repositories/favorite_repository.dart';
import 'package:yumyum_backend/repositories/product_repository.dart';

FutureOr<Response> onRequest(RequestContext context) async {
  return switch (context.request.method) {
    HttpMethod.get => await _list(context),
    HttpMethod.post => await _add(context),
    _ => Response(statusCode: 405),
  };
}

Future<Response> _list(RequestContext context) async {
  final user = context.read<AuthenticatedUser>();
  final ids = await context
      .read<FavoriteRepository>()
      .findIds(user.uid, FavoriteType.product);
  final products = await context.read<ProductRepository>().findByIds(ids);
  return Response.json(body: products.map((p) => p.toJson()).toList());
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

  final product = await context.read<ProductRepository>().findById(productId);
  if (product == null) {
    return Response.json(
      statusCode: 404,
      body: {'error': 'Product not found'},
    );
  }

  final user = context.read<AuthenticatedUser>();
  await context
      .read<FavoriteRepository>()
      .add(user.uid, FavoriteType.product, productId);

  return Response.json(statusCode: 201, body: product.toJson());
}
