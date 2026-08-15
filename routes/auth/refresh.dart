import 'dart:async';

import 'package:dart_frog/dart_frog.dart';
import 'package:delmer_backend/auth/token_service.dart';
import 'package:delmer_backend/repositories/user_repository.dart';

FutureOr<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.post) {
    return Response(statusCode: 405);
  }

  final Map<String, dynamic> body;
  try {
    body = await context.request.json() as Map<String, dynamic>;
  } catch (_) {
    return Response.json(statusCode: 400, body: {'error': 'Invalid JSON'});
  }

  final refreshToken =
      (body['refreshToken'] ?? body['refresh_token']) as String?;
  if (refreshToken == null || refreshToken.isEmpty) {
    return Response.json(
      statusCode: 422,
      body: {'error': 'refreshToken is required'},
    );
  }

  final tokens = context.read<TokenService>();
  final uid = tokens.verifyRefreshToken(refreshToken);
  if (uid == null) {
    return Response.json(
      statusCode: 401,
      body: {'error': 'Invalid or expired refresh token'},
    );
  }

  final user = await context.read<UserRepository>().findByUid(uid);
  if (user == null) {
    return Response.json(statusCode: 404, body: {'error': 'User not found'});
  }

  // NOTE: the presented refresh token stays valid until it expires. Revocation
  // and rotation need a persisted token store, which does not exist yet.
  return Response.json(
    body: {
      'access_token': tokens.generateAccessToken(uid),
      'access_token_expires_in': tokens.accessTokenExpiresIn.inSeconds,
      'refresh_token': tokens.generateRefreshToken(uid),
      'refresh_token_expires_in': tokens.refreshTokenExpiresIn.inSeconds,
    },
  );
}
