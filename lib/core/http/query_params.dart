import 'package:dart_frog/dart_frog.dart';

/// Reads query parameter [name] of [context] as an optional integer.
///
/// Returns `(value, null)` — `value` being null when the parameter is absent —
/// or `(null, error)` with a 400 to return when it is present but not an
/// integer. `?category=abc` must not be treated as absent, which would quietly
/// return unfiltered results for a typo.
(int?, Response?) intQueryParam(RequestContext context, String name) {
  final raw = context.request.uri.queryParameters[name];
  if (raw == null) return (null, null);
  final value = int.tryParse(raw);
  if (value == null) {
    return (
      null,
      Response.json(
        statusCode: 400,
        body: {'error': '$name must be an integer'},
      ),
    );
  }
  return (value, null);
}
