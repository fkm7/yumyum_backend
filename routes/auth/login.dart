import 'dart:async';

import 'package:dart_frog/dart_frog.dart';
import 'package:delmer_backend/auth/password_hasher.dart';
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

  final email = body['email'] as String?;
  final password = body['password'] as String?;

  if (email == null || password == null) {
    return Response.json(
      statusCode: 422,
      body: {'error': 'email and password are required'},
    );
  }

  final user = await context.read<UserRepository>().findByEmail(email);

  // An unknown address and a wrong password answer identically, so the endpoint
  // cannot be used to enumerate registered users.
  if (user == null || user.passwordHash != hashPassword(password)) {
    return Response.json(
      statusCode: 401,
      body: {'error': 'Invalid email or password'},
    );
  }

  final tokens = context.read<TokenService>();
  return Response.json(
    body: {
      'access_token': tokens.generateAccessToken(user.uid),
      'access_token_expires_in': tokens.accessTokenExpiresIn.inSeconds,
      'refresh_token': tokens.generateRefreshToken(user.uid),
      'refresh_token_expires_in': tokens.refreshTokenExpiresIn.inSeconds,
      'user': user.toJson(),
    },
  );
}
