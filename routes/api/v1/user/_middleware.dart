import 'package:dart_frog/dart_frog.dart';
import 'package:yumyum_backend/auth/authenticated_user.dart';

/// Every route under /api/v1/user requires a valid access token: orders,
/// addresses, payment methods and favorites all belong to a specific user.
///
/// Replaces the separate `_middleware.dart` files that used to live under
/// `orders/` and `favorites/` individually — one auth gate now covers all
/// four sub-features.
Handler middleware(Handler handler) => handler.use(authMiddleware());
