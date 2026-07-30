import 'dart:async';

import 'package:dart_frog/dart_frog.dart';
import 'package:delmer_backend/db/database_service.dart';
import 'package:postgres/postgres.dart';

const _selectColumns = '''
  id, name, is_open, rating, logo, address, image, category, start_time,
  end_time, description, phone_number, delivery_cost, min_delivery_time,
  max_delivery_time, free_delivery_from, product_categories
''';

FutureOr<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.get) {
    return Response(statusCode: 405);
  }

  final categoryId = context.request.uri.queryParameters['category'];
  final conn = await context.read<DatabaseService>().connection;

  final result = categoryId == null
      ? await conn.execute(
          'SELECT $_selectColumns FROM restaurants ORDER BY id',
        )
      : await conn.execute(
          Sql.named(
            'SELECT $_selectColumns FROM restaurants '
            'WHERE category = @category ORDER BY id',
          ),
          parameters: {'category': int.tryParse(categoryId)},
        );

  final restaurants = result.map((row) => row.toColumnMap()).toList();
  return Response.json(
    body: restaurants,
  );
}
