import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:yumyum_backend/repositories/auth_repository.dart';
import 'package:yumyum_backend/repositories/user_repository.dart';
import 'package:yumyum_backend/services/mail_service.dart';

String _generateToken() {
  final rnd = Random.secure();
  final bytes = List<int>.generate(32, (_) => rnd.nextInt(256));
  return base64UrlEncode(bytes).replaceAll('=', '');
}

String hashToken(String token) => sha256.convert(utf8.encode(token)).toString();

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.post) {
    return Response(statusCode: HttpStatus.methodNotAllowed);
  }

  final body = await context.request.json() as Map<String, dynamic>;
  final email = (body['email'] as String?)?.trim().toLowerCase();

  // Same response regardless of outcome
  final response = Response.json(
    body: {'message': 'If the account exists, an email was sent.'},
  );
  if (email == null || email.isEmpty) return response;

  final userRepository = context.read<UserRepository>();
  final authRespository = context.read<AuthRepository>();
  final mailer = context.read<MailService>();

  final user = await userRepository.findByEmail(email);
  if (user == null) return response;

  final token = _generateToken();
  await authRespository.invalidateAllFor(user.uid); // one active token per user
  await authRespository.createPasswordResetRecord(
    userId: user.uid,
    tokenHash: hashToken(token),
    expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 30)),
  );

  // Fire and forget so response timing doesn't reveal whether the user exists
  unawaited(mailer.sendResetEmail(to: user.email, token: token));
  return response;
}
