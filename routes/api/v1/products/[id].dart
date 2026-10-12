import 'dart:async';

import 'package:dart_frog/dart_frog.dart';
import 'package:yumyum_backend/repositories/product_repository.dart';

FutureOr<Response> onRequest(RequestContext context, String id) async {
  if (context.request.method != HttpMethod.get) {
    return Response(statusCode: 405);
  }

  // The previous version passed the raw path segment straight into a query
  // against an INTEGER primary key, so a non-numeric id surfaced as a database
  // type error and a 500 rather than a 400.
  final productId = int.tryParse(id);
  if (productId == null) {
    return Response.json(statusCode: 400, body: {'error': 'Invalid id'});
  }

  final product = await context.read<ProductRepository>().findById(productId);
  if (product == null) {
    return Response.json(statusCode: 404, body: {'error': 'Not found'});
  }

  return Response.json(body: product.toJson());
}
