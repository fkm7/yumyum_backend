import 'dart:async';

import 'package:dart_frog/dart_frog.dart';
import 'package:yumyum_backend/auth/authenticated_user.dart';
import 'package:yumyum_backend/models/address.dart';
import 'package:yumyum_backend/repositories/address_repository.dart';

FutureOr<Response> onRequest(RequestContext context, String id) async {
  return switch (context.request.method) {
    HttpMethod.get => await _get(context, id),
    HttpMethod.patch => await _update(context, id),
    HttpMethod.delete => await _delete(context, id),
    _ => Response(statusCode: 405),
  };
}

Future<Response> _get(RequestContext context, String id) async {
  final address = await _owned(context, id);
  if (address == null) {
    return Response.json(statusCode: 404, body: {'error': 'Not found'});
  }
  return Response.json(body: address.toJson());
}

Future<Response> _update(RequestContext context, String id) async {
  final existing = await _owned(context, id);
  if (existing == null) {
    return Response.json(statusCode: 404, body: {'error': 'Not found'});
  }

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

  // existing was already confirmed to belong to this user by _owned, and
  // AddressRepository.update only applies the fields supplied, so the
  // update stays scoped to a row this caller is allowed to touch.
  final updated = await context.read<AddressRepository>().update(
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

  return Response.json(body: updated!.toJson());
}

Future<Response> _delete(RequestContext context, String id) async {
  final existing = await _owned(context, id);
  if (existing == null) {
    return Response.json(statusCode: 404, body: {'error': 'Not found'});
  }
  await context.read<AddressRepository>().delete(id);
  return Response(statusCode: 204);
}

/// Loads the address, treating one owned by another user the same as one
/// that does not exist — matching the ownership-check pattern used by
/// `GET /api/v1/user/orders/[id]`.
Future<Address?> _owned(RequestContext context, String id) async {
  final address = await context.read<AddressRepository>().findById(id);
  final user = context.read<AuthenticatedUser>();
  if (address == null || address.userId != user.uid) return null;
  return address;
}
