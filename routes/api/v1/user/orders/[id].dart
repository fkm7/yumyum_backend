import 'dart:async';

import 'package:dart_frog/dart_frog.dart';
import 'package:yumyum_backend/features/auth/presentation/authenticated_user.dart';
import 'package:yumyum_backend/features/orders/application/order_service.dart';

FutureOr<Response> onRequest(RequestContext context, String id) async {
  if (context.request.method != HttpMethod.get) {
    return Response(statusCode: 405);
  }

  final uid = context.read<AuthenticatedUser>().uid;
  final order = await context.read<OrderService>().find(uid, id);
  if (order == null) {
    return Response.json(statusCode: 404, body: {'error': 'Not found'});
  }

  return Response.json(body: order.toJson());
}
