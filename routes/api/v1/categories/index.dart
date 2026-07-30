import 'dart:async';

import 'package:dart_frog/dart_frog.dart';
import 'package:delmer_backend/db/database_service.dart';

FutureOr<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.get) {
    return Response(statusCode: 405);
  }

  final conn = await context.read<DatabaseService>().connection;
  final result = await conn.execute(
    'SELECT id, title_en, title_ru, title_uz, icon FROM categories ORDER BY id',
  );

  return Response.json(body: result.map((row) => row.toColumnMap()).toList());
}
