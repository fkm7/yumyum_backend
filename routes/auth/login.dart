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

  final email = body['email'] as String?;
  final password = body['password'] as String?;

  if (email == null || password == null) {
    return Response.json(
      statusCode: 422,
      body: {'error': 'email and password are required'},
    );
  }

  final conn = await context.read<DatabaseService>().connection;
  final result = await conn.execute(
    Sql.named('''
      SELECT uid, first_name, last_name, email, password_hash, photo_url
      FROM users WHERE email = @email
    '''),
    parameters: {'email': email},
  );

  if (result.isEmpty) {
    return Response.json(
      statusCode: 401,
      body: {'error': 'Invalid email or password'},
    );
  }

  final user = result.first.toColumnMap();
  if (user['password_hash'] != hashPassword(password)) {
    return Response.json(
      statusCode: 401,
      body: {'error': 'Invalid email or password'},
    );
  }

  final accessToken = generateAccessToken(user['uid'] as String);
  final refreshToken = generateRefreshToken(user['uid'] as String);
  return Response.json(
    body: {
      'access_token': accessToken,
      'access_token_expires_in': accessTokenExpiresIn.inSeconds,
      'refresh_token': refreshToken,
      'refresh_token_expires_in': refreshTokenExpiresIn.inSeconds,
      'user': {
        'uid': user['uid'],
        'first_name': user['first_name'],
        'last_name': user['last_name'],
        'email': user['email'],
        'photo_url': user['photo_url'],
      },
    },
  );
}
