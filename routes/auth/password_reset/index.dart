import 'dart:async';

import 'package:dart_frog/dart_frog.dart';
import 'package:yumyum_backend/services/password_reset_service.dart';

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
  if (email == null || email.isEmpty) {
    return Response.json(
      statusCode: 422,
      body: {'error': 'email is required'},
    );
  }

  await context.read<PasswordResetService>().requestReset(email);

  // Always the same response, whether or not the address is registered —
  // otherwise this endpoint becomes an oracle for which emails have
  // accounts, the same reasoning login.dart uses for an unknown email.
  return Response.json(
    body: {
      'message':
          'If that email is registered, a password reset link has been sent.',
    },
  );
}
