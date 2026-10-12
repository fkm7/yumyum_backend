import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dart_frog/dart_frog.dart';

FutureOr<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.post) {
    return Response(statusCode: 405);
  }
  final Map<String, dynamic> body;
  try {
    body = await context.request.body() as Map<String, dynamic>;
  } catch (_) {
    return Response.json(statusCode: 400, body: {'error': 'Invalid JSON'});
  }
  final fullname = body['fullname'];
  final email = body['email'];
  final phone = body['phone_number'];
  final photo = body['photo_url'];
  return Response(
    body: json.encode({
      'status': 'Success',
      'message': 'Profile has been updated.',
    }),
  );
}
