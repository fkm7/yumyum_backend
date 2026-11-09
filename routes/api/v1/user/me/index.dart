import 'dart:async';
import 'dart:io';

import 'package:dart_frog/dart_frog.dart';

import 'package:yumyum_backend/features/account/application/profile_service.dart';
import 'package:yumyum_backend/features/auth/presentation/authenticated_user.dart';

FutureOr<Response> onRequest(RequestContext context) async {
  return switch (context.request.method) {
    HttpMethod.get => await _get(context),
    HttpMethod.post => await _update(context),
    _ => Response.json(
        statusCode: HttpStatus.methodNotAllowed,
        body: {'error': 'Method not allowed'},
      ),
  };
}

Future<Response> _get(RequestContext context) async {
  final uid = context.read<AuthenticatedUser>().uid;
  final user = await context.read<ProfileService>().find(uid);
  if (user == null) return _notFound();
  return Response.json(body: {'user': user.toMap()});
}

Future<Response> _update(RequestContext context) async {
  final Map<String, dynamic> body;
  try {
    body = await context.request.json() as Map<String, dynamic>;
  } catch (_) {
    return Response.json(
      statusCode: HttpStatus.badRequest,
      body: {'error': 'Invalid JSON'},
    );
  }

  final fullName = body['fullname'];
  final email = body['email'];
  if ((fullName != null && fullName is! String) ||
      (email != null && email is! String)) {
    return Response.json(
      statusCode: HttpStatus.unprocessableEntity,
      body: {'error': 'fullname and email must be strings'},
    );
  }

  final uid = context.read<AuthenticatedUser>().uid;
  final user = await context.read<ProfileService>().update(
        uid,
        fullName: fullName as String?,
        email: email as String?,
      );
  if (user == null) return _notFound();

  return Response.json(
    body: {
      'status': 'Success',
      'message': 'Profile has been updated.',
      'user': user.toMap(),
    },
  );
}

Response _notFound() => Response.json(
      statusCode: HttpStatus.notFound,
      body: {'error': 'User not found'},
    );
