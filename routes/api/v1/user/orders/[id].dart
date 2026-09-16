import 'dart:async';

import 'package:dart_frog/dart_frog.dart';
import 'package:delmer_backend/auth/authenticated_user.dart';
import 'package:delmer_backend/repositories/order_repository.dart';

FutureOr<Response> onRequest(RequestContext context, String id) async {
  if (context.request.method != HttpMethod.get) {
    return Response(statusCode: 405);
  }

  final order = await context.read<OrderRepository>().findById(id);

  // A caller must not be able to tell someone else's order id from an
  // unused one, so a foreign order answers 404 rather than 403.
  if (order == null || order.userId != context.read<AuthenticatedUser>().uid) {
    return Response.json(statusCode: 404, body: {'error': 'Not found'});
  }

  return Response.json(body: order.toJson());
}
