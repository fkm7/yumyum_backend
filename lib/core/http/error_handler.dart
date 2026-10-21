import 'dart:io';

import 'package:dart_frog/dart_frog.dart';

/// Converts an uncaught exception into a JSON 500 response.
///
/// Without this, a thrown database error produces an empty body that does not
/// match the `{"error": ...}` shape every other response uses, and the client
/// sees a bare 500 with no parseable payload.
///
/// The exception itself is logged but never returned: internal messages can
/// carry table names, SQL, or connection strings.
Middleware errorHandler() {
  return (handler) {
    return (context) async {
      try {
        return await handler(context);
      } catch (error, stackTrace) {
        stderr
          ..writeln('Unhandled error on ${context.request.uri}: $error')
          ..writeln(stackTrace);
        return Response.json(
          statusCode: 500,
          body: {'error': 'Internal Server Error'},
        );
      }
    };
  };
}
