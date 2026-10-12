import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:dbcrypt/dbcrypt.dart';
import 'package:yumyum_backend/auth/authenticated_user.dart';
import 'package:yumyum_backend/auth/token_service.dart';

import 'package:yumyum_backend/repositories/auth_repository.dart';
import 'package:yumyum_backend/repositories/user_repository.dart';
import 'package:yumyum_backend/services/session_service.dart';

import 'forgot_password.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.post) {
    return Response(statusCode: HttpStatus.methodNotAllowed);
  }

  final uid = bearerUid(context, context.read<TokenService>());
  if (uid == null) {
    return Response.json(statusCode: 401, body: {'error': 'Unauthorized'});
  }

  final body = await context.request.json() as Map<String, dynamic>;
  final token = body['token'] as String?;
  final password = body['password'] as String?;

  if (token == null || password == null || password.length < 8) {
    return Response.json(
      statusCode: HttpStatus.badRequest,
      body: {'error': 'Invalid request'},
    );
  }

  final authRepository = context.read<AuthRepository>();
  final userRepository = context.read<UserRepository>();
  final sessionService = context.read<SessionService>();

  final record = await authRepository.findValidPasswordReset(
    hashToken(token),
  ); // not used, not expired
  if (record == null) {
    return Response.json(
      statusCode: HttpStatus.badRequest,
      body: {'error': 'Invalid or expired token'},
    );
  }

  final newHash = DBCrypt().hashpw(password, DBCrypt().gensalt());
  await userRepository.updatePasswordHash(record.userId, newHash);
  await authRepository.markUsedResetToken(record.id);
  await sessionService.revokeAllResetTokens(record.userId);

  return Response.json(body: {'message': 'Password updated'});
}
