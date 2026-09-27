import 'dart:async';

import 'package:dart_frog/dart_frog.dart';
import 'package:delmer_backend/auth/authenticated_user.dart';
import 'package:delmer_backend/auth/password_hasher.dart';
import 'package:delmer_backend/repositories/user_repository.dart';
import 'package:delmer_backend/services/session_service.dart';

/// Sits under `routes/api/v1/user/`, so `authMiddleware` (applied by that
/// tree's `_middleware.dart`) already guarantees a valid access token.
FutureOr<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.patch) {
    return Response(statusCode: 405);
  }

  final Map<String, dynamic> body;
  try {
    body = await context.request.json() as Map<String, dynamic>;
  } catch (_) {
    return Response.json(statusCode: 400, body: {'error': 'Invalid JSON'});
  }

  final currentPassword =
      (body['currentPassword'] ?? body['current_password']) as String?;
  final newPassword =
      (body['newPassword'] ?? body['new_password']) as String?;

  if (currentPassword == null || currentPassword.isEmpty) {
    return Response.json(
      statusCode: 422,
      body: {'error': 'currentPassword is required'},
    );
  }
  if (newPassword == null || newPassword.length < 8) {
    return Response.json(
      statusCode: 422,
      body: {
        'error': 'newPassword is required and must be at least 8 characters',
      },
    );
  }

  final authenticatedUser = context.read<AuthenticatedUser>();
  final users = context.read<UserRepository>();
  final hasher = context.read<PasswordHasher>();

  final account = await users.findByUid(authenticatedUser.uid);
  if (account == null) {
    return Response.json(statusCode: 404, body: {'error': 'User not found'});
  }

  // findByUid deliberately omits the password hash (see UserRepository
  // docs), so it's fetched again via email, matching the pattern used by
  // the account-deletion endpoint.
  final withHash = await users.findByEmail(account.email);
  final storedHash = withHash?.passwordHash;
  if (storedHash == null || !hasher.verify(currentPassword, storedHash)) {
    return Response.json(
      statusCode: 401,
      body: {'error': 'Incorrect current password'},
    );
  }

  await users.updatePasswordHash(
    authenticatedUser.uid,
    hasher.hash(newPassword),
  );

  // Invalidates every other logged-in session — anyone holding the old
  // refresh token (a stolen device, a leaked token) is signed out, and the
  // caller gets a fresh pair so their own session keeps working.
  final tokens = await context
      .read<SessionService>()
      .restartAllSessions(authenticatedUser.uid);

  return Response.json(body: tokens.toJson());
}
