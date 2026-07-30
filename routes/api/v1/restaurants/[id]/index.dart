import 'package:dart_frog/dart_frog.dart';
import 'package:delmer_backend/db/database_service.dart';
import 'package:postgres/postgres.dart';

Future<Response> onRequest(RequestContext context, String id) async {
  if (context.request.method != HttpMethod.get) {
    return Response(statusCode: 405);
  }

  final restaurantId = int.tryParse(id);
  if (restaurantId == null) {
    return Response.json(statusCode: 400, body: {'error': 'Invalid id'});
  }

  final conn = await context.read<DatabaseService>().connection;
  final result = await conn.execute(
    Sql.named('''
      SELECT id, name, is_open, rating, logo, address, image, category,
             start_time, end_time, description, phone_number, delivery_cost,
             min_delivery_time, max_delivery_time, free_delivery_from,
             product_categories
      FROM restaurants WHERE id = @id
    '''),
    parameters: {'id': restaurantId},
  );

  if (result.isEmpty) {
    return Response.json(statusCode: 404, body: {'error': 'Not found'});
  }

  return Response.json(body: result.first.toColumnMap());
}
