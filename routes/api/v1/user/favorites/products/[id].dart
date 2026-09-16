import 'dart:async';

import 'package:dart_frog/dart_frog.dart';
import 'package:delmer_backend/auth/authenticated_user.dart';
import 'package:delmer_backend/repositories/favorite_repository.dart';

FutureOr<Response> onRequest(RequestContext context, String id) async {
  if (context.request.method != HttpMethod.delete) {
    return Response(statusCode: 405);
  }

  final productId = int.tryParse(id);
  if (productId == null) {
    return Response.json(statusCode: 400, body: {'error': 'Invalid id'});
  }

  final user = context.read<AuthenticatedUser>();
  await context
      .read<FavoriteRepository>()
      .remove(user.uid, FavoriteType.product, productId);

  return Response(statusCode: 204);
}
