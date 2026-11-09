import 'dart:async';

import 'package:dart_frog/dart_frog.dart';
import 'package:yumyum_backend/features/catalog/domain/category_repository.dart';

/// The food categories shown on the search screen. Pass an id to
/// `GET /api/v1/restaurants?category=<id>` for the restaurants serving it.
FutureOr<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.get) {
    return Response(statusCode: 405);
  }

  final categories = await context.read<CategoryRepository>().findAll();
  return Response.json(body: categories.map((c) => c.toJson()).toList());
}
