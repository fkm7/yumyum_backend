import 'dart:io';

import 'package:dart_frog/dart_frog.dart';

import 'package:yumyum_backend/core/db/database_service.dart';

import 'package:yumyum_backend/features/account/application/account_deletion_service.dart';
import 'package:yumyum_backend/features/account/application/profile_service.dart';
import 'package:yumyum_backend/features/account/infrastructure/local_photo_storage.dart';
import 'package:yumyum_backend/features/account/infrastructure/postgres_user_repository.dart';
import 'package:yumyum_backend/features/addresses/application/address_service.dart';
import 'package:yumyum_backend/features/addresses/infrastructure/postgres_address_repository.dart';
import 'package:yumyum_backend/features/auth/application/credential_service.dart';
import 'package:yumyum_backend/features/auth/application/password_reset_service.dart';
import 'package:yumyum_backend/features/auth/application/session_service.dart';
import 'package:yumyum_backend/features/auth/domain/email_service.dart';
import 'package:yumyum_backend/features/auth/domain/token_service.dart';
import 'package:yumyum_backend/features/auth/infrastructure/bcrypt_password_hasher.dart';
import 'package:yumyum_backend/features/auth/infrastructure/console_email_service.dart';
import 'package:yumyum_backend/features/auth/infrastructure/jwt_token_service.dart';
import 'package:yumyum_backend/features/auth/infrastructure/postgres_auth_repository.dart';
import 'package:yumyum_backend/features/auth/infrastructure/postgres_password_reset_token_repository.dart';
import 'package:yumyum_backend/features/auth/infrastructure/postgres_refresh_token_repository.dart';
import 'package:yumyum_backend/features/auth/infrastructure/smtp_email_service.dart';
import 'package:yumyum_backend/features/catalog/domain/category_repository.dart';
import 'package:yumyum_backend/features/catalog/domain/cuisine_repository.dart';
import 'package:yumyum_backend/features/catalog/domain/product_repository.dart';
import 'package:yumyum_backend/features/catalog/domain/restaurant_repository.dart';
import 'package:yumyum_backend/features/catalog/infrastructure/postgres_category_repository.dart';
import 'package:yumyum_backend/features/catalog/infrastructure/postgres_cuisine_repository.dart';
import 'package:yumyum_backend/features/catalog/infrastructure/postgres_product_repository.dart';
import 'package:yumyum_backend/features/catalog/infrastructure/postgres_restaurant_repository.dart';
import 'package:yumyum_backend/features/favorites/application/favorites_service.dart';
import 'package:yumyum_backend/features/favorites/infrastructure/postgres_favorite_repository.dart';
import 'package:yumyum_backend/features/orders/application/order_service.dart';
import 'package:yumyum_backend/features/orders/infrastructure/postgres_order_repository.dart';
import 'package:yumyum_backend/features/payments/application/payment_method_service.dart';
import 'package:yumyum_backend/features/payments/infrastructure/postgres_payment_repository.dart';

/// Makes the app's use cases readable from a request context.
///
/// The composition root: the only file that names concrete implementations
/// (Postgres repositories, bcrypt, JWT, SMTP, local file storage). Everything
/// else depends on domain interfaces, which is what lets tests provide fakes.
///
/// Routes get application services, plus the read-only catalog repository
/// interfaces for plain lookups that carry no business rule. Everything else
/// — the database, the user, credential, token and order repositories, the
/// hasher, the email sender, photo storage — is reachable only through the
/// service that owns it.
Middleware appProviders() {
  return (handler) => handler
      .use(provider<TokenService>((_) => _tokens))
      .use(provider<CategoryRepository>((_) => _categories))
      .use(provider<CuisineRepository>((_) => _cuisines))
      .use(provider<RestaurantRepository>((_) => _restaurants))
      .use(provider<ProductRepository>((_) => _products))
      .use(provider<ProfileService>((_) => _profiles))
      .use(provider<AddressService>((_) => _addressService))
      .use(provider<PaymentMethodService>((_) => _paymentMethods))
      .use(provider<OrderService>((_) => _orderService))
      .use(provider<FavoritesService>((_) => _favoritesService))
      .use(provider<CredentialService>((_) => _credentials))
      .use(provider<SessionService>((_) => _sessions))
      .use(provider<PasswordResetService>((_) => _passwordResets))
      .use(provider<AccountDeletionService>((_) => _accountDeletions));
}

// Top-level finals are initialised lazily, once, on first read, so each of
// these is a process-wide singleton. The repositories are stateless wrappers
// around the shared connection future, not connections themselves.
final _database = DatabaseService.instance;
final TokenService _tokens = JwtTokenService.fromEnvironment();

final _users = PostgresUserRepository(_database);
final _categories = PostgresCategoryRepository(_database);
final _cuisines = PostgresCuisineRepository(_database);
final _restaurants = PostgresRestaurantRepository(_database);
final _products = PostgresProductRepository(_database);

final _profiles = ProfileService(
  users: _users,
  photos: LocalPhotoStorage.fromEnvironment(),
);
final _addressService = AddressService(PostgresAddressRepository(_database));
final _paymentMethods =
    PaymentMethodService(PostgresPaymentRepository(_database));
final _orderService = OrderService(
  orders: PostgresOrderRepository(_database),
  restaurants: _restaurants,
  products: _products,
  addresses: _addressService,
  paymentMethods: _paymentMethods,
);
final _favoritesService = FavoritesService(
  favorites: PostgresFavoriteRepository(_database),
  products: _products,
  restaurants: _restaurants,
);

final _credentials = CredentialService(
  credentials: PostgresAuthRepository(_database),
  hasher: BcryptPasswordHasher.fromEnvironment(),
);
final _sessions = SessionService(
  tokenService: _tokens,
  refreshTokenRepository: PostgresRefreshTokenRepository(_database),
  userRepository: _users,
);
final _passwordResets = PasswordResetService(
  users: _users,
  tokens: PostgresPasswordResetTokenRepository(_database),
  emailService: _buildEmailService(),
  credentials: _credentials,
  sessions: _sessions,
  resetUrlBase: _resolvePasswordResetUrlBase(),
);
final _accountDeletions = AccountDeletionService(
  users: _users,
  credentials: _credentials,
);

/// Picks an [EmailService] based on whether SMTP is configured.
///
/// Falls back to a console logger — printing the reset link instead of
/// emailing it — the same "safe fallback with a loud warning" shape
/// [JwtTokenService.fromEnvironment] already uses for a missing `JWT_SECRET`.
/// The console fallback must never be selected in production.
EmailService _buildEmailService() {
  final host = Platform.environment['SMTP_HOST'];
  if (host == null || host.isEmpty) {
    stderr.writeln(
      'WARNING: SMTP_HOST is not set; falling back to a console logger for '
      'outgoing email. Password reset links will only be printed to '
      'stdout. Configure SMTP_* before deploying.',
    );
    return ConsoleEmailService();
  }
  return SmtpEmailService.fromEnvironment();
}

/// Reads the base URL/deep link a password-reset email points at.
///
/// Falls back to a placeholder with a loud warning, same shape as
/// [_buildEmailService] — set `PASSWORD_RESET_URL_BASE` to your real
/// reset-password page or app deep link before deploying.
String _resolvePasswordResetUrlBase() {
  final base = Platform.environment['PASSWORD_RESET_URL_BASE'];
  if (base == null || base.isEmpty) {
    stderr.writeln(
      'WARNING: PASSWORD_RESET_URL_BASE is not set; falling back to a '
      'placeholder URL. Set it to your real reset-password page or app deep '
      'link before deploying.',
    );
    return 'https://app.delmer.example/reset-password';
  }
  return base;
}
