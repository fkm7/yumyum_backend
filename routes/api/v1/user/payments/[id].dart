import 'dart:async';

import 'package:dart_frog/dart_frog.dart';
import 'package:yumyum_backend/auth/authenticated_user.dart';
import 'package:yumyum_backend/models/payment_method.dart';
import 'package:yumyum_backend/repositories/payment_repository.dart';

FutureOr<Response> onRequest(RequestContext context, String id) async {
  return switch (context.request.method) {
    HttpMethod.get => await _get(context, id),
    HttpMethod.delete => await _delete(context, id),
    _ => Response(statusCode: 405),
  };
}

Future<Response> _get(RequestContext context, String id) async {
  final method = await _owned(context, id);
  if (method == null) {
    return Response.json(statusCode: 404, body: {'error': 'Not found'});
  }
  return Response.json(body: method.toJson());
}

Future<Response> _delete(RequestContext context, String id) async {
  final method = await _owned(context, id);
  if (method == null) {
    return Response.json(statusCode: 404, body: {'error': 'Not found'});
  }
  await context.read<PaymentRepository>().delete(id);
  return Response(statusCode: 204);
}

/// Loads the payment method, treating one owned by another user the same as
/// one that does not exist — matching the pattern used for orders/addresses.
Future<PaymentMethod?> _owned(RequestContext context, String id) async {
  final method = await context.read<PaymentRepository>().findById(id);
  final user = context.read<AuthenticatedUser>();
  if (method == null || method.userId != user.uid) return null;
  return method;
}
