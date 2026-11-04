import 'dart:async';

import 'package:dart_frog/dart_frog.dart';
import 'package:yumyum_backend/features/addresses/application/address_service.dart';
import 'package:yumyum_backend/features/auth/presentation/authenticated_user.dart';

FutureOr<Response> onRequest(RequestContext context, String id) async {
  return switch (context.request.method) {
    HttpMethod.get => await _get(context, id),
    HttpMethod.patch => await _update(context, id),
    HttpMethod.delete => await _delete(context, id),
    _ => Response(statusCode: 405),
  };
}

Future<Response> _get(RequestContext context, String id) async {
  final address = await context.read<AddressService>().find(_uid(context), id);
  if (address == null) {
    return Response.json(statusCode: 404, body: {'error': 'Not found'});
  }
  return Response.json(body: address.toJson());
}

Future<Response> _update(RequestContext context, String id) async {
  final Map<String, dynamic> body;
  try {
    body = await context.request.json() as Map<String, dynamic>;
  } catch (_) {
    return Response.json(statusCode: 400, body: {'error': 'Invalid JSON'});
  }

  final rawLatitude = body['latitude'];
  final rawLongitude = body['longitude'];
  if ((rawLatitude != null && rawLatitude is! num) ||
      (rawLongitude != null && rawLongitude is! num)) {
    return Response.json(
      statusCode: 422,
      body: {'error': 'latitude and longitude must be numbers'},
    );
  }

  final rawIsDefault = body['isDefault'];
  if (rawIsDefault != null && rawIsDefault is! bool) {
    return Response.json(
      statusCode: 422,
      body: {'error': 'isDefault must be a boolean'},
    );
  }

  final updated = await context.read<AddressService>().update(
        _uid(context),
        id,
        type: body['type'] as String?,
        label: body['label'] as String?,
        street: body['street'] as String?,
        city: body['city'] as String?,
        country: body['country'] as String?,
        latitude: (rawLatitude as num?)?.toDouble(),
        longitude: (rawLongitude as num?)?.toDouble(),
        isDefault: rawIsDefault as bool?,
      );

  if (updated == null) {
    return Response.json(statusCode: 404, body: {'error': 'Not found'});
  }
  return Response.json(body: updated.toJson());
}

Future<Response> _delete(RequestContext context, String id) async {
  final deleted =
      await context.read<AddressService>().delete(_uid(context), id);
  if (!deleted) {
    return Response.json(statusCode: 404, body: {'error': 'Not found'});
  }
  return Response(statusCode: 204);
}

String _uid(RequestContext context) => context.read<AuthenticatedUser>().uid;
