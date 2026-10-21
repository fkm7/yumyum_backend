import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dart_frog/dart_frog.dart';

import 'package:yumyum_backend/auth/authenticated_user.dart';
import 'package:yumyum_backend/auth/token_service.dart';
import 'package:yumyum_backend/repositories/user_repository.dart';

Future<Response> onRequest(RequestContext context) async {
  // This route cannot sit behind authMiddleware: it shares a directory with
  // /auth/login and /auth/register, which must stay public.
  final uid = bearerUid(context, context.read<TokenService>());
  if (uid == null) {
    return Response.json(
      statusCode: HttpStatus.unauthorized,
      body: {
        'error': 'Unauthorized',
      },
    );
  }

  final user = await context.read<UserRepository>().findByUid(uid);
  if (user == null) {
    return Response.json(
      statusCode: HttpStatus.notFound,
      body: {
        'error': 'User not found',
      },
    );
  }

  switch (context.request.method) {
    case HttpMethod.get:
      return Response.json(body: {'user': user.toMap()});
    case HttpMethod.post:
      final Map<String, dynamic> body;
      try {
        body = await context.request.json() as Map<String, dynamic>;
      } catch (_) {
        return Response.json(
          statusCode: HttpStatus.badRequest,
          body: {
            'error': 'Invalid JSON',
            'message': _.toString(),
          },
        );
      }
      final fullname = body['fullname'] as String?;
      final email = body['email'] as String?;
      // final phone = body['phone_number'] as String?;
      final userRepository = context.read<UserRepository>();
      final user = await userRepository.updateProfile(
        uid: uid,
        firstName: fullname?.split(' ').first,
        lastName: (fullname?.split(' ').length ?? 0) > 1
            ? fullname?.split(' ').last
            : '',
        email: email ?? '',
        // phoneNumber: phone ?? '',
      );
      return Response(
        body: json.encode({
          'status': 'Success',
          'message': 'Profile has been updated.',
          'user': user?.toMap(),
        }),
      );
    default:
      return Response.json(
        statusCode: HttpStatus.methodNotAllowed,
        body: {'error': 'Method not allowed'},
      );
  }
}
