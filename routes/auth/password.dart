import 'dart:async';

import 'package:dart_frog/dart_frog.dart';

import 'package:yumyum_backend/auth/authenticated_user.dart';
import 'package:yumyum_backend/auth/token_service.dart';
import 'package:yumyum_backend/services/credential_service.dart';
import 'package:yumyum_backend/services/session_service.dart';

/// Changes the caller's password. Accepts PATCH, and POST for clients built
/// against the removed `/auth/change_password` endpoint.
FutureOr<Response> onRequest(RequestContext context) async {
  final method = context.request.method;
  if (method != HttpMethod.patch && method != HttpMethod.post) {
    return Response(statusCode: 405);
  }

  // This route cannot sit behind authMiddleware: it shares a directory with
  // /auth/login and /auth/register, which must stay public.
  final uid = bearerUid(context, context.read<TokenService>());
  if (uid == null) {
    return Response.json(statusCode: 401, body: {'error': 'Unauthorized'});
  }

  final Map<String, dynamic> body;
  try {
    body = await context.request.json() as Map<String, dynamic>;
  } catch (_) {
    return Response.json(statusCode: 400, body: {'error': 'Invalid JSON'});
  }

  final currentPassword =
      (body['currentPassword'] ?? body['current_password']) as String?;
  final newPassword = (body['newPassword'] ?? body['new_password']) as String?;

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

  final credentials = context.read<CredentialService>();
  if (!await credentials.verifyByUid(uid, currentPassword)) {
    return Response.json(
      statusCode: 401,
      body: {'error': 'Incorrect current password'},
    );
  }

  await credentials.setPassword(uid, newPassword);

  // Invalidates every other logged-in session — anyone holding the old
  // refresh token (a stolen device, a leaked token) is signed out, and the
  // caller gets a fresh pair so their own session keeps working.
  final tokens = await context.read<SessionService>().restartAllSessions(uid);

  return Response.json(body: tokens.toJson());
}
