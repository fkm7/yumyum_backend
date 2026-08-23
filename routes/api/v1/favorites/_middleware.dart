import 'package:dart_frog/dart_frog.dart';
import 'package:delmer_backend/auth/authenticated_user.dart';

/// Every route under /api/v1/favorites requires a valid access token:
/// favorites belong to a specific user.
Handler middleware(Handler handler) => handler.use(authMiddleware());
