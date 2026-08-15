import 'dart:async';

import 'package:dart_frog/dart_frog.dart';
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

  final refreshToken =
      (body['refreshToken'] ?? body['refresh_token']) as String?;
  if (refreshToken == null || refreshToken.isEmpty) {
    return Response.json(
      statusCode: 422,
      body: {'error': 'refreshToken is required'},
    );
  }

  final result = await context.read<SessionService>().rotate(refreshToken);

  // Reuse is answered exactly like an ordinary rejection: the caller is either
  // an attacker replaying a stolen token or a client that lost a response, and
  // neither should be told which.
  return switch (result) {
    RefreshSucceeded(:final tokens) => Response.json(body: tokens.toJson()),
    RefreshRejected() || RefreshReuseDetected() => Response.json(
        statusCode: 401,
        body: {'error': 'Invalid or expired refresh token'},
      ),
    RefreshUserMissing() => Response.json(
        statusCode: 404,
        body: {'error': 'User not found'},
      ),
  };
}
