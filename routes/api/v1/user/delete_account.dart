import 'dart:async';

import 'package:dart_frog/dart_frog.dart';

import 'package:delmer_backend/auth/authenticated_user.dart';
import 'package:delmer_backend/auth/password_hasher.dart';
import 'package:delmer_backend/repositories/user_repository.dart';

/// Permanently deletes the authenticated user's account.
///
/// Sits under `routes/api/v1/user/`, so `authMiddleware` (applied by that
/// tree's `_middleware.dart`) already guarantees a valid access token; this
/// additionally requires the current password in the body, since a
/// destructive action like this is worth more than "a bearer token was
/// presented" — an access token can live for up to a day per
/// `TokenService.accessTokenExpiresIn`.
FutureOr<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.delete) {
    return Response(statusCode: 405);
  }

  final Map<String, dynamic> body;
  try {
    body = await context.request.json() as Map<String, dynamic>;
  } catch (_) {
    return Response.json(statusCode: 400, body: {'error': 'Invalid JSON'});
  }

  final password = body['password'];
  if (password is! String || password.isEmpty) {
    return Response.json(
      statusCode: 422,
      body: {'error': 'password is required to confirm account deletion'},
    );
  }

  final authenticatedUser = context.read<AuthenticatedUser>();
  final users = context.read<UserRepository>();
  final hasher = context.read<PasswordHasher>();

  final account = await users.findByUid(authenticatedUser.uid);
  if (account == null) {
    // Already gone (e.g. a retried request, or deleted via the web page in
    // another tab) — deletion is idempotent from the caller's perspective.
    return Response(statusCode: 204);
  }

  // findByUid deliberately omits the password hash (see UserRepository docs),
  // so it's fetched again via email, matching the pattern login.dart uses.
  final withHash = await users.findByEmail(account.email);
  final storedHash = withHash?.passwordHash;
  if (storedHash == null || !hasher.verify(password, storedHash)) {
    return Response.json(
      statusCode: 401,
      body: {'error': 'Incorrect password'},
    );
  }

  await users.delete(authenticatedUser.uid);

  return Response(statusCode: 204);
}
