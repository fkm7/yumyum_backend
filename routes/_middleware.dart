import 'package:dart_frog/dart_frog.dart';
import 'package:delmer_backend/auth/bcrypt_password_hasher.dart';
import 'package:delmer_backend/auth/password_hasher.dart';
import 'package:delmer_backend/auth/token_service.dart';
import 'package:delmer_backend/db/database_service.dart';
import 'package:delmer_backend/middleware/error_handler.dart';
import 'package:delmer_backend/repositories/category_repository.dart';
import 'package:delmer_backend/repositories/order_repository.dart';
import 'package:delmer_backend/repositories/postgres/postgres_category_repository.dart';
import 'package:delmer_backend/repositories/postgres/postgres_order_repository.dart';
import 'package:delmer_backend/repositories/postgres/postgres_product_repository.dart';
import 'package:delmer_backend/repositories/postgres/postgres_refresh_token_repository.dart';
import 'package:delmer_backend/repositories/postgres/postgres_restaurant_repository.dart';
import 'package:delmer_backend/repositories/postgres/postgres_user_repository.dart';
import 'package:delmer_backend/repositories/product_repository.dart';
import 'package:delmer_backend/repositories/refresh_token_repository.dart';
import 'package:delmer_backend/repositories/restaurant_repository.dart';
import 'package:delmer_backend/repositories/user_repository.dart';
import 'package:delmer_backend/services/session_service.dart';

// `middleware` runs once when the pipeline is built, so these are constructed
// a single time and shared. The repositories are stateless wrappers around the
// shared connection future, not connections themselves.
final _database = DatabaseService.instance;
final _tokens = TokenService.fromEnvironment();
final _passwordHasher = BcryptPasswordHasher.fromEnvironment();
final _users = PostgresUserRepository(_database);
final _categories = PostgresCategoryRepository(_database);
final _restaurants = PostgresRestaurantRepository(_database);
final _products = PostgresProductRepository(_database);
final _orders = PostgresOrderRepository(_database);
final _refreshTokens = PostgresRefreshTokenRepository(_database);
final _sessions = SessionService(
  tokens: _tokens,
  refreshTokens: _refreshTokens,
  users: _users,
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
      .use(provider<RestaurantRepository>((_) => _restaurants))
      .use(provider<ProductRepository>((_) => _products))
      .use(provider<OrderRepository>((_) => _orders))
      .use(provider<RefreshTokenRepository>((_) => _refreshTokens))
      .use(provider<SessionService>((_) => _sessions))
      .use(requestLogger())
      .use(errorHandler());
}
