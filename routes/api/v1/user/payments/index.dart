import 'dart:async';

import 'package:dart_frog/dart_frog.dart';
import 'package:yumyum_backend/features/auth/presentation/authenticated_user.dart';
import 'package:yumyum_backend/features/payments/application/payment_method_service.dart';

FutureOr<Response> onRequest(RequestContext context) async {
  return switch (context.request.method) {
    HttpMethod.get => await _list(context),
    HttpMethod.post => await _create(context),
    _ => Response(statusCode: 405),
  };
}

Future<Response> _list(RequestContext context) async {
  final user = context.read<AuthenticatedUser>();
  final methods = await context.read<PaymentMethodService>().list(user.uid);
  return Response.json(body: methods.map((m) => m.toJson()).toList());
}

Future<Response> _create(RequestContext context) async {
  final Map<String, dynamic> body;
  try {
    body = await context.request.json() as Map<String, dynamic>;
  } catch (_) {
    return Response.json(statusCode: 400, body: {'error': 'Invalid JSON'});
  }

  final type = body['type'];
  if (type is! String || type.isEmpty) {
    return Response.json(
      statusCode: 422,
      body: {'error': 'type is required'},
    );
  }

  // Never accepts a full card number or CVV — only display-safe fields; see
  // PaymentMethodService.
  final last4 = body['last4'];
  if (last4 != null && (last4 is! String || last4.length != 4)) {
    return Response.json(
      statusCode: 422,
      body: {'error': 'last4 must be a 4-digit string'},
    );
  }

  final expiryMonth = body['expiryMonth'];
  final expiryYear = body['expiryYear'];
  if ((expiryMonth != null && expiryMonth is! int) ||
      (expiryYear != null && expiryYear is! int)) {
    return Response.json(
      statusCode: 422,
      body: {'error': 'expiryMonth and expiryYear must be integers'},
    );
  }

  final rawIsDefault = body['isDefault'];
  if (rawIsDefault != null && rawIsDefault is! bool) {
    return Response.json(
      statusCode: 422,
      body: {'error': 'isDefault must be a boolean'},
    );
  }

  final user = context.read<AuthenticatedUser>();
  final method = await context.read<PaymentMethodService>().create(
        user.uid,
        type: type,
        brand: body['brand'] as String?,
        last4: last4 as String?,
        expiryMonth: expiryMonth as int?,
        expiryYear: expiryYear as int?,
        isDefault: (rawIsDefault as bool?) ?? false,
      );

  return Response.json(statusCode: 201, body: method.toJson());
}
