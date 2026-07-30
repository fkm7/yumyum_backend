import 'package:dart_frog/dart_frog.dart';
import 'package:delmer_backend/db/database_service.dart';
import 'package:postgres/postgres.dart';

Future<Response> onRequest(RequestContext context, String id) async {
  if (context.request.method != HttpMethod.get) {
    return Response(statusCode: 405);
  }

  final conn = await context.read<DatabaseService>().connection;
  final result = await conn.execute(
    Sql.named('''
      SELECT id, cost, status, order_time, restaurant_info, products,
             delivery_address, courier, payment_detail
      FROM orders WHERE id = @id
    '''),
    parameters: {'id': id},
  );

  if (result.isEmpty) {
    return Response.json(statusCode: 404, body: {'error': 'Not found'});
  }

  final order = result.first.toColumnMap();
  order['order_time'] = (order['order_time'] as DateTime).toIso8601String();

  return Response.json(body: order);
}
