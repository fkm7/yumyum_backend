import 'package:dart_frog/dart_frog.dart';

import 'package:yumyum_backend/auth/bcrypt_password_hasher.dart';
import 'package:yumyum_backend/auth/password_hasher.dart';
import 'package:yumyum_backend/auth/token_service.dart';
import 'package:yumyum_backend/db/database_service.dart';
import 'package:yumyum_backend/middleware/error_handler.dart';
import 'package:yumyum_backend/repositories/address_repository.dart';
import 'package:yumyum_backend/repositories/category_repository.dart';
import 'package:yumyum_backend/repositories/cuisine_repository.dart';
import 'package:yumyum_backend/repositories/favorite_repository.dart';
import 'package:yumyum_backend/repositories/order_repository.dart';
import 'package:yumyum_backend/repositories/payment_repository.dart';
import 'package:yumyum_backend/repositories/postgres/postgres_address_repository.dart';
import 'package:yumyum_backend/repositories/postgres/postgres_category_repository.dart';
import 'package:yumyum_backend/repositories/postgres/postgres_cuisine_repository.dart';
import 'package:yumyum_backend/repositories/postgres/postgres_favorite_repository.dart';
import 'package:yumyum_backend/repositories/postgres/postgres_order_repository.dart';
import 'package:yumyum_backend/repositories/postgres/postgres_payment_repository.dart';
import 'package:yumyum_backend/repositories/postgres/postgres_product_repository.dart';
import 'package:yumyum_backend/repositories/postgres/postgres_refresh_token_repository.dart';
import 'package:yumyum_backend/repositories/postgres/postgres_restaurant_category_repository.dart';
import 'package:yumyum_backend/repositories/postgres/postgres_restaurant_repository.dart';
import 'package:yumyum_backend/repositories/postgres/postgres_user_repository.dart';
import 'package:yumyum_backend/repositories/product_repository.dart';
import 'package:yumyum_backend/repositories/refresh_token_repository.dart';
import 'package:yumyum_backend/repositories/restaurant_category_repository.dart';
import 'package:yumyum_backend/repositories/restaurant_repository.dart';
import 'package:yumyum_backend/repositories/user_repository.dart';
import 'package:yumyum_backend/services/session_service.dart';

// `middleware` runs once when the pipeline is built, so these are constructed
// a single time and shared. The repositories are stateless wrappers around the
// shared connection future, not connections themselves.
final _database = DatabaseService.instance;
final _tokens = TokenService.fromEnvironment();
final _passwordHasher = BcryptPasswordHasher.fromEnvironment();
final _users = PostgresUserRepository(_database);
final _categories = PostgresCategoryRepository(_database);
final _cuisines = PostgresCuisineRepository(_database);
final _restaurantCategories = PostgresRestaurantCategoryRepository(_database);
final _restaurants = PostgresRestaurantRepository(_database);
final _products = PostgresProductRepository(_database);
final _orders = PostgresOrderRepository(_database);
final _favorites = PostgresFavoriteRepository(_database);
final _addresses = PostgresAddressRepository(_database);
final _payments = PostgresPaymentRepository(_database);
final _refreshTokens = PostgresRefreshTokenRepository(_database);
final _sessions = SessionService(
  tokenService: _tokens,
  refreshTokenRepository: _refreshTokens,
  userRepository: _users,
);

Handler middleware(Handler handler) {
  // `.use` wraps, so the last one applied is the outermost: errorHandler sees
  // exceptions thrown anywhere below it, including inside other middleware.
  return handler
      .use(provider<DatabaseService>((_) => _database))
      .use(provider<TokenService>((_) => _tokens))
      .use(provider<PasswordHasher>((_) => _passwordHasher))
      .use(provider<UserRepository>((_) => _users))
      .use(provider<CategoryRepository>((_) => _categories))
      .use(provider<CuisineRepository>((_) => _cuisines))
      .use(provider<RestaurantCategoryRepository>((_) => _restaurantCategories))
      .use(provider<RestaurantRepository>((_) => _restaurants))
      .use(provider<ProductRepository>((_) => _products))
      .use(provider<OrderRepository>((_) => _orders))
      .use(provider<FavoriteRepository>((_) => _favorites))
      .use(provider<AddressRepository>((_) => _addresses))
      .use(provider<PaymentRepository>((_) => _payments))
      .use(provider<RefreshTokenRepository>((_) => _refreshTokens))
      .use(provider<SessionService>((_) => _sessions))
      .use(requestLogger())
      .use(errorHandler());
}
