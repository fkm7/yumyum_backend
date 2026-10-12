import 'dart:async';

import 'package:dart_frog/dart_frog.dart';
import 'package:yumyum_backend/auth/authenticated_user.dart';
import 'package:yumyum_backend/repositories/address_repository.dart';

FutureOr<Response> onRequest(RequestContext context) async {
  return switch (context.request.method) {
    HttpMethod.get => await _list(context),
    HttpMethod.post => await _create(context),
    _ => Response(statusCode: 405),
  };
}

Future<Response> _list(RequestContext context) async {
  final user = context.read<AuthenticatedUser>();
  final addresses =
      await context.read<AddressRepository>().findByUser(user.uid);
  return Response.json(body: addresses.map((a) => a.toJson()).toList());
}

Future<Response> _create(RequestContext context) async {
  final Map<String, dynamic> body;
  try {
    body = await context.request.json() as Map<String, dynamic>;
  } catch (_) {
    return Response.json(statusCode: 400, body: {'error': 'Invalid JSON'});
  }

  final street = body['street'];
  final city = body['city'];
  final country = body['country'];
  if (street is! String ||
      street.isEmpty ||
      city is! String ||
      city.isEmpty ||
      country is! String ||
      country.isEmpty) {
    return Response.json(
      statusCode: 422,
      body: {'error': 'street, city and country are required'},
    );
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

  final rawType = body['type'];
  if (rawType != null && rawType is! String) {
    return Response.json(
      statusCode: 422,
      body: {'error': 'type must be a string'},
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
  final address = await context.read<AddressRepository>().create(
        userId: user.uid,
        type: (rawType as String?) ?? 'other',
        label: body['label'] as String?,
        street: street,
        city: city,
        country: country,
        latitude: (rawLatitude as num?)?.toDouble(),
        longitude: (rawLongitude as num?)?.toDouble(),
        isDefault: (rawIsDefault as bool?) ?? false,
      );

  return Response.json(statusCode: 201, body: address.toJson());
}
