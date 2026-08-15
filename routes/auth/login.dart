import 'dart:async';

import 'package:dart_frog/dart_frog.dart';
import 'package:delmer_backend/auth/password_hasher.dart';
import 'package:delmer_backend/models/user.dart';
import 'package:delmer_backend/repositories/user_repository.dart';
import 'package:delmer_backend/services/session_service.dart';

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

  final users = context.read<UserRepository>();
  final hasher = context.read<PasswordHasher>();
  final user = await users.findByEmail(email);

  if (user == null) {
    // Hash anyway. bcrypt is deliberately slow, so returning here without
    // doing the work would make an unregistered address measurably faster to
    // reject than a registered one with the wrong password.
    hasher.verifyAbsentUser(password);
    return _invalidCredentials();
  }

  final storedHash = user.passwordHash;
  if (storedHash == null || !hasher.verify(password, storedHash)) {
    return _invalidCredentials();
  }

  // A successful login is the only point where the plaintext is available, so
  // it is the only chance to move a legacy digest onto the current algorithm.
  if (hasher.needsRehash(storedHash)) {
    await users.updatePasswordHash(user.uid, hasher.hash(password));
  }

  return _session(context, user);
}

Response _invalidCredentials() => Response.json(
      statusCode: 401,
      body: {'error': 'Invalid email or password'},
    );

Future<Response> _session(RequestContext context, User user) async {
  final tokens = await context.read<SessionService>().start(user.uid);
  return Response.json(
    body: {...tokens.toJson(), 'user': user.toJson()},
  );
}
