import 'dart:async';

import 'package:dart_frog/dart_frog.dart';
import 'package:delmer_backend/auth/jwt_service.dart';
import 'package:delmer_backend/db/database_service.dart';
import 'package:postgres/postgres.dart';

FutureOr<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.get) {
    return Response(statusCode: 405);
  }

  final uid = _extractUid(context);
  if (uid == null) {
    return Response.json(statusCode: 401, body: {'error': 'Unauthorized'});
  }

  final conn = await context.read<DatabaseService>().connection;
  final result = await conn.execute(
    Sql.named('''
      SELECT uid, first_name, last_name, email, photo_url
      FROM users WHERE uid = @uid
    '''),
    parameters: {'uid': uid},
  );

  if (result.isEmpty) {
    return Response.json(statusCode: 404, body: {'error': 'User not found'});
  }

  final user = result.first.toColumnMap();
  return Response.json(
    body: {
      'uid': user['uid'],
      'firstName': user['first_name'],
      'lastName': user['last_name'],
      'email': user['email'],
      'photoUrl': user['photo_url'],
    },
  );
}

String? _extractUid(RequestContext context) {
  final authHeader = context.request.headers['Authorization'];
  if (authHeader == null || !authHeader.startsWith('Bearer ')) return null;
  return verifyAccessToken(authHeader.substring(7));
}
