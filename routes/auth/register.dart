import 'dart:async';

import 'package:dart_frog/dart_frog.dart';
import 'package:yumyum_backend/auth/password_hasher.dart';
import 'package:yumyum_backend/repositories/user_repository.dart';
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

  // The insert is what enforces uniqueness, so a concurrent registration of the
  // same address loses here rather than racing past a preceding SELECT.
  final user = await context.read<UserRepository>().create(
        firstName: firstName,
        lastName: lastName,
        email: email,
        passwordHash: context.read<PasswordHasher>().hash(password),
      );

  if (user == null) {
    return Response.json(
      statusCode: 409,
      body: {'error': 'Email already registered'},
    );
  }

  final tokens = await context.read<SessionService>().start(user.uid);
  return Response.json(
    statusCode: 201,
    body: {...tokens.toJson(), 'user': user.toJson()},
  );
}
