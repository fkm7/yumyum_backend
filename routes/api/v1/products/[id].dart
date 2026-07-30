import 'dart:async';

import 'package:dart_frog/dart_frog.dart';
import 'package:delmer_backend/db/database_service.dart';
import 'package:postgres/postgres.dart';

FutureOr<Response> onRequest(RequestContext context, String id) async {
  if (context.request.method != HttpMethod.get) {
    return Response(statusCode: 405);
  }

  final conn = await context.read<DatabaseService>().connection;
  final result = await conn.execute(
    Sql.named('''
      SELECT id, restaurant_id, category, status, price, title_en, title_ru, title_uz, image, description
      FROM products WHERE id = @id
    '''),
    parameters: {'id': id},
  );

  if (result.isEmpty) {
    return Response.json(statusCode: 404, body: {'error': 'Not found'});
  }

  return Response.json(body: result.first.toColumnMap());
}
