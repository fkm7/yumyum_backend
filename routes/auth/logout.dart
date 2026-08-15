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

  // No access token is required: holding the refresh token is authority enough
  // to throw it away, and demanding a valid access token would stop a client
  // from logging out once its access token had expired.
  await context.read<SessionService>().revoke(refreshToken);

  // Always 204, whether or not the token existed. Reporting "unknown token"
  // would turn logout into an oracle for which tokens are live.
  return Response(statusCode: 204);
}
