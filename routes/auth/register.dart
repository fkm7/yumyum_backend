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

  final firstName = body['first_name'] as String?;
  final lastName = body['last_name'] as String?;
  final email = body['email'] as String?;
  final password = body['password'] as String?;

  if (firstName == null ||
      lastName == null ||
      email == null ||
      password == null) {
    return Response.json(
      statusCode: 422,
      body: {'error': 'first_name, last_name, email and password are required'},
    );
  }

  final conn = await context.read<DatabaseService>().connection;

  final existing = await conn.execute(
    Sql.named('SELECT uid FROM users WHERE email = @email'),
    parameters: {'email': email},
  );
  if (existing.isNotEmpty) {
    return Response.json(
      statusCode: 409,
      body: {'error': 'Email already registered'},
    );
  }

  final uid = DateTime.now().millisecondsSinceEpoch.toString();
  await conn.execute(
    Sql.named('''
      INSERT INTO users (uid, first_name, last_name, email, password_hash, photo_url)
      VALUES (@uid, @first_name, @last_name, @email, @password_hash, @photo_url)
    '''),
    parameters: {
      'uid': uid,
      'first_name': firstName,
      'last_name': lastName,
      'email': email,
      'password_hash': hashPassword(password),
      'photo_url': '',
    },
  );

  final accessToken = generateAccessToken(uid);
  final refreshToken = generateRefreshToken(uid);
  return Response.json(
    statusCode: 201,
    body: {
      'access_token': accessToken,
      'access_token_expires_in': accessTokenExpiresIn.inSeconds,
      'refresh_token': refreshToken,
      'refresh_token_expires_in': refreshTokenExpiresIn.inSeconds,
      'user': {
        'uid': uid,
        'first_name': firstName,
        'last_name': lastName,
        'email': email,
        'photo_url': '',
      },
    },
  );
}
