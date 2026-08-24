import 'dart:io';

import 'package:postgres/postgres.dart';

/// A singleton service for managing the database connection.
class DatabaseService {
  DatabaseService._();

  /// The singleton instance of the DatabaseService.
  static final DatabaseService instance = DatabaseService._();

  /// The PostgreSQL connection instance.
  ///
  /// `fly postgres attach` (and Heroku-style platforms) provision a database
  /// and expose it as a single `DATABASE_URL` secret, not as the discrete
  /// `DB_HOST`/`DB_PORT`/... vars used for local development. When present,
  /// it takes priority so an attached Fly Postgres cluster is picked up
  /// without extra configuration.
  late final Future<Connection> connection = Connection.open(
    _endpoint(),
    settings: ConnectionSettings(sslMode: _sslMode()),
  );

  /// Builds the endpoint to connect to.
  ///
  /// `DATABASE_URL`, when set, is a full `postgres://user:pass@host:port/db`
  /// connection string — how Fly Postgres and similar platforms inject
  /// credentials — and takes priority over the discrete `DB_*` variables,
  /// which remain the local / docker-compose path.
  static Endpoint _endpoint() {
    final databaseUrl = Platform.environment['DATABASE_URL'];
    if (databaseUrl == null) {
      return Endpoint(
        host: Platform.environment['DB_HOST'] ?? 'localhost',
        port: int.parse(Platform.environment['DB_PORT'] ?? '5432'),
        database: Platform.environment['DB_NAME'] ?? 'delmer',
        username: Platform.environment['DB_USER'] ?? 'farrukh',
        password: Platform.environment['DB_PASS'] ?? '1997',
      );
    }

    final uri = Uri.parse(databaseUrl);
    final userInfo = uri.userInfo.split(':');
    return Endpoint(
      host: uri.host,
      port: uri.hasPort ? uri.port : 5432,
      database: uri.path.isEmpty ? 'delmer' : uri.path.substring(1),
      username: userInfo.isNotEmpty && userInfo.first.isNotEmpty
          ? Uri.decodeComponent(userInfo.first)
          : 'farrukh',
      password: userInfo.length > 1
          ? Uri.decodeComponent(userInfo[1])
          : '1997',
    );
  }

  /// Whether to require TLS, taken from `DATABASE_URL`'s `sslmode` query
  /// parameter. Defaults to disabled, matching a private-network connection
  /// (e.g. Fly Postgres over 6PN) or a local/docker-compose database.
  static SslMode _sslMode() {
    final databaseUrl = Platform.environment['DATABASE_URL'];
    if (databaseUrl == null) return SslMode.disable;
    final sslMode = Uri.parse(databaseUrl).queryParameters['sslmode'];
    return sslMode == 'require' || sslMode == 'verify-full'
        ? SslMode.require
        : SslMode.disable;
  }
}
