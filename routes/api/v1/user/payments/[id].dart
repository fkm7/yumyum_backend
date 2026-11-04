import 'dart:async';

import 'package:dart_frog/dart_frog.dart';
import 'package:yumyum_backend/features/auth/presentation/authenticated_user.dart';
import 'package:yumyum_backend/features/payments/application/payment_method_service.dart';

FutureOr<Response> onRequest(RequestContext context, String id) async {
  return switch (context.request.method) {
    HttpMethod.get => await _get(context, id),
    HttpMethod.delete => await _delete(context, id),
    _ => Response(statusCode: 405),
  };
}

Future<Response> _get(RequestContext context, String id) async {
  final method =
      await context.read<PaymentMethodService>().find(_uid(context), id);
  if (method == null) return _notFound();
  return Response.json(body: method.toJson());
}

Future<Response> _delete(RequestContext context, String id) async {
  final deleted =
      await context.read<PaymentMethodService>().delete(_uid(context), id);
  if (!deleted) return _notFound();
  return Response(statusCode: 204);
}

String _uid(RequestContext context) => context.read<AuthenticatedUser>().uid;

Response _notFound() =>
    Response.json(statusCode: 404, body: {'error': 'Not found'});
