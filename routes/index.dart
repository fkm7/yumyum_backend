import 'dart:async';
import 'dart:io';

import 'package:dart_frog/dart_frog.dart';

FutureOr<Response> onRequest(RequestContext context) async {
  final html = await File('public/index.html').readAsString();
  return Response(
    body: html,
    headers: {HttpHeaders.contentTypeHeader: 'text/html; charset=UTF-8'},
  );
}
