import 'dart:async';

import 'package:dart_frog/dart_frog.dart';
import 'package:delmer_backend/db/database_service.dart';
import 'package:postgres/postgres.dart';

FutureOr<Response> onRequest(RequestContext context) async {
  return switch (context.request.method) {
    HttpMethod.get => await _getProducts(context),
    _ => Response(statusCode: 405),
  };
}

Future<Response> _getProducts(RequestContext context) async {
  final conn = await context.read<DatabaseService>().connection;
  final result = await conn.execute(
    Sql.named('''
      SELECT id, restaurant_id, category, status, price, title_en, title_ru, title_uz, image, description
      FROM products ORDER BY id
    '''),
  );

  final products = result.map((row) => row.toColumnMap()).toList();

  return Response.json(body: products);
}
