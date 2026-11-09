import 'dart:async';

import 'package:dart_frog/dart_frog.dart';
import 'package:yumyum_backend/core/http/query_params.dart';
import 'package:yumyum_backend/features/catalog/domain/product_repository.dart';

/// `GET /api/v1/products[?category=<id>]`
FutureOr<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.get) {
    return Response(statusCode: 405);
  }

  final (categoryId, badCategory) = intQueryParam(context, 'category');
  if (badCategory != null) return badCategory;

  final products =
      await context.read<ProductRepository>().findAll(categoryId: categoryId);
  return Response.json(body: products.map((p) => p.toJson()).toList());
}
