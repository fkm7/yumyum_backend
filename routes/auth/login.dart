import 'dart:async';

import 'package:dart_frog/dart_frog.dart';
import 'package:yumyum_backend/repositories/user_repository.dart';
import 'package:yumyum_backend/services/credential_service.dart';
import 'package:yumyum_backend/services/session_service.dart';

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

  // Unknown email and wrong password both come back null, in equal time, so
  // the response cannot reveal which addresses are registered.
  final uid =
      await context.read<CredentialService>().verifyByEmail(email, password);
  if (uid == null) return _invalidCredentials();

  final user = await context.read<UserRepository>().findByUid(uid);
  // Deleted between the credential check and this read.
  if (user == null) return _invalidCredentials();

  final tokens = await context.read<SessionService>().start(user.uid);
  return Response.json(
    body: {...tokens.toJson(), 'user': user.toMap()},
  );
}

Response _invalidCredentials() => Response.json(
      statusCode: 401,
      body: {'error': 'Invalid email or password'},
    );
