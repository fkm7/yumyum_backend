import 'dart:async';

import 'package:dart_frog/dart_frog.dart';
import 'package:delmer_backend/auth/authenticated_user.dart';
import 'package:delmer_backend/auth/token_service.dart';
import 'package:delmer_backend/repositories/user_repository.dart';

FutureOr<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.get) {
    return Response(statusCode: 405);
  }

  // This route cannot sit behind authMiddleware: it shares a directory with
  // /auth/login and /auth/register, which must stay public.
  final uid = bearerUid(context, context.read<TokenService>());
  if (uid == null) {
    return Response.json(statusCode: 401, body: {'error': 'Unauthorized'});
  }

  final user = await context.read<UserRepository>().findByUid(uid);
  if (user == null) {
    return Response.json(statusCode: 404, body: {'error': 'User not found'});
  }

  return Response.json(
    body: {
      'user': user.toJson(),
    },
  );
}
