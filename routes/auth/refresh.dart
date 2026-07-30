import 'dart:async';

import 'package:dart_frog/dart_frog.dart';
import 'package:delmer_backend/auth/jwt_service.dart';
import 'package:delmer_backend/db/database_service.dart';
import 'package:postgres/postgres.dart';

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

  final uid = verifyRefreshToken(refreshToken);
  if (uid == null) {
    return Response.json(
      statusCode: 401,
      body: {'error': 'Invalid or expired refresh token'},
    );
  }

  final conn = await context.read<DatabaseService>().connection;
  final result = await conn.execute(
    Sql.named('SELECT uid FROM users WHERE uid = @uid'),
    parameters: {'uid': uid},
  );

  if (result.isEmpty) {
    return Response.json(statusCode: 404, body: {'error': 'User not found'});
  }

  final newAccessToken = generateAccessToken(uid);
  final newRefreshToken = generateRefreshToken(uid);

  return Response.json(
    body: {
      'access_token': newAccessToken,
      'access_token_expires_in': accessTokenExpiresIn.inSeconds,
      'refresh_token': newRefreshToken,
      'refresh_token_expires_in': refreshTokenExpiresIn.inSeconds,
    },
  );
}