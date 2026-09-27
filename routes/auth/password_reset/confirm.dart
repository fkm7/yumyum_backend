import 'dart:async';

import 'package:dart_frog/dart_frog.dart';
import 'package:delmer_backend/services/password_reset_service.dart';

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

  final token = body['token'] as String?;
  final newPassword = (body['newPassword'] ?? body['new_password']) as String?;

  if (token == null || token.isEmpty) {
    return Response.json(
      statusCode: 422,
      body: {'error': 'token is required'},
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

  final result = await context.read<PasswordResetService>().confirm(
        rawToken: token,
        newPassword: newPassword,
      );

  // Reuse is answered exactly like an unknown or expired token: the caller
  // is either an attacker guessing tokens or a client that already used
  // this link, and neither should be told which — mirroring
  // auth/refresh.dart's handling of RefreshReuseDetected vs RefreshRejected.
  return switch (result) {
    PasswordResetConfirmed(:final tokens, :final user) => Response.json(
        body: {...tokens.toJson(), 'user': user.toJson()},
      ),
    PasswordResetTokenRejected() => Response.json(
        statusCode: 401,
        body: {'error': 'Invalid or expired reset token'},
      ),
  };
}
