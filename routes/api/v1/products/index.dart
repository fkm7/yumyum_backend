import 'dart:async';

import 'package:dart_frog/dart_frog.dart';
import 'package:delmer_backend/repositories/product_repository.dart';

FutureOr<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.get) {
    return Response(statusCode: 405);
  }

  final products = await context.read<ProductRepository>().findAll();
  return Response.json(body: products.map((p) => p.toJson()).toList());
}
