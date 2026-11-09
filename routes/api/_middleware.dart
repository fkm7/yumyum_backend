import 'package:dart_frog/dart_frog.dart';
import 'package:yumyum_backend/core/http/asset_urls.dart';

/// Every API response gets `/assets/...` paths turned into absolute URLs on
/// the requesting host, so catalog images resolve against whichever server
/// the client is talking to.
Handler middleware(Handler handler) => handler.use(assetUrls());
