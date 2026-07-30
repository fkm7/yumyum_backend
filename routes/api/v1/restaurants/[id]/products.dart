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
      SELECT id, restaurant_id AS restaurant, category, price, status,
             title_en, title_ru, title_uz, image, description
      FROM products WHERE restaurant_id = @id ORDER BY id
    '''),
    parameters: {'id': restaurantId},
  );

  return Response.json(body: result.map((row) => row.toColumnMap()).toList());
}
