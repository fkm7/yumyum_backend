import 'package:dart_frog/dart_frog.dart';

import 'package:yumyum_backend/core/http/error_handler.dart';
import 'package:yumyum_backend/di/providers.dart';

Handler middleware(Handler handler) {
  // `.use` wraps, so the last one applied is the outermost: errorHandler sees
  // exceptions thrown anywhere below it, including inside other middleware.
  return handler.use(appProviders()).use(requestLogger()).use(errorHandler());
}
