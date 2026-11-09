import 'dart:convert';
import 'dart:io';

import 'package:dart_frog/dart_frog.dart';

/// Prefix of the files served from `public/assets/`.
///
/// The database stores asset links as host-relative paths (`/assets/...`)
/// rather than full URLs, so the same data works against production, a local
/// server, or an emulator reaching the host machine.
const assetPathPrefix = '/assets/';

/// Rewrites every `/assets/...` string in a JSON response into an absolute
/// URL on the host the client used to make the request.
///
/// The origin comes from `request.uri`, which honours `X-Forwarded-Proto` and
/// `X-Forwarded-Host`, so behind Fly's proxy it is `https://<app>.fly.dev` and
/// locally it is e.g. `http://localhost:8080` or `http://10.0.2.2:8080`.
///
/// Values that are already absolute URLs (external images, order snapshots
/// taken before paths were relative) are left untouched, as is any response
/// that is not JSON.
Middleware assetUrls() {
  return (handler) {
    return (context) async {
      final response = await handler(context);

      final contentType = response.headers[HttpHeaders.contentTypeHeader];
      if (contentType == null || !contentType.contains('application/json')) {
        return response;
      }

      final body = await response.body();
      final rewritten = body.contains('"$assetPathPrefix')
          ? jsonEncode(resolveAssetUrls(jsonDecode(body), context.request.uri))
          : body;

      // Reading the body consumes it, so always hand on a fresh response.
      // `content-length` is dropped because a rewritten body is longer.
      return Response(
        statusCode: response.statusCode,
        headers: {
          for (final MapEntry(:key, :value) in response.headers.entries)
            if (key.toLowerCase() != HttpHeaders.contentLengthHeader)
              key: value,
        },
        body: rewritten,
      );
    };
  };
}

/// Returns [json] with every string starting with [assetPathPrefix] resolved
/// against [origin] (any URL on the target host; its path and query are
/// replaced). Maps and lists are walked recursively.
Object? resolveAssetUrls(Object? json, Uri origin) {
  return switch (json) {
    final String s when s.startsWith(assetPathPrefix) =>
      origin.resolve(s).toString(),
    final Map<String, dynamic> map => {
        for (final MapEntry(:key, :value) in map.entries)
          key: resolveAssetUrls(value, origin),
      },
    final List<dynamic> list => [
        for (final value in list) resolveAssetUrls(value, origin),
      ],
    _ => json,
  };
}
