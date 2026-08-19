import 'dart:async';

import 'package:dart_frog/dart_frog.dart';
import 'package:delmer_backend/repositories/cuisine_repository.dart';

FutureOr<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.get) {
    return Response(statusCode: 405);
  }

  final cuisines = await context.read<CuisineRepository>().findAll();
  return Response.json(body: cuisines.map((c) => c.toJson()).toList());
}
