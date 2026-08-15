import 'package:dart_frog/dart_frog.dart';
import 'package:delmer_backend/auth/authenticated_user.dart';

/// Every route under /api/v1/orders requires a valid access token.
///
/// Before this existed, anyone could create orders and `GET /api/v1/orders`
/// returned every order in the system to any caller.
Handler middleware(Handler handler) => handler.use(authMiddleware());
