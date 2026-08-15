import 'dart:async';

import 'package:dart_frog/dart_frog.dart';
import 'package:delmer_backend/repositories/category_repository.dart';

FutureOr<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.get) {
    return Response(statusCode: 405);
  }

  final categories = await context.read<CategoryRepository>().findAll();
  return Response.json(body: categories.map((c) => c.toJson()).toList());
}
