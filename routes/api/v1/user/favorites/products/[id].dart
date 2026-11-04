import 'dart:async';

import 'package:dart_frog/dart_frog.dart';
import 'package:yumyum_backend/features/auth/presentation/authenticated_user.dart';
import 'package:yumyum_backend/features/favorites/application/favorites_service.dart';

FutureOr<Response> onRequest(RequestContext context, String id) async {
  if (context.request.method != HttpMethod.delete) {
    return Response(statusCode: 405);
  }

  final productId = int.tryParse(id);
  if (productId == null) {
    return Response.json(statusCode: 400, body: {'error': 'Invalid id'});
  }

  final user = context.read<AuthenticatedUser>();
  await context.read<FavoritesService>().removeProduct(user.uid, productId);

  return Response(statusCode: 204);
}
