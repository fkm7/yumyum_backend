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
    _endpoint,
    settings: ConnectionSettings(sslMode: _sslMode),
  );

  Endpoint get _endpoint {
    final databaseUrl = Platform.environment['DATABASE_URL'];
    if (databaseUrl != null && databaseUrl.isNotEmpty) {
      final uri = Uri.parse(databaseUrl);
      final userInfo = uri.userInfo.split(':');
      return Endpoint(
        host: uri.host,
        port: uri.hasPort ? uri.port : 5432,
        database: uri.path.replaceFirst('/', ''),
        username: Uri.decodeComponent(userInfo[0]),
        password: userInfo.length > 1 ? Uri.decodeComponent(userInfo[1]) : '',
      );
    }

    return Endpoint(
      host: Platform.environment['DB_HOST'] ?? 'localhost',
      port: int.parse(Platform.environment['DB_PORT'] ?? '5432'),
      database: Platform.environment['DB_NAME'] ?? 'delmer',
      username: Platform.environment['DB_USER'] ?? 'farrukh',
      password: Platform.environment['DB_PASS'] ?? '1997',
    );
  }

  /// Fly Postgres is reached over the private 6PN network, which does not
  /// use TLS, so plain `DATABASE_URL`/`DB_*` connections stay disabled by
  /// default. Set `DB_SSL_MODE=require` for a database that sits behind
  /// public TLS (e.g. a managed provider reached over the public internet).
  SslMode get _sslMode {
    return Platform.environment['DB_SSL_MODE'] == 'require'
        ? SslMode.require
        : SslMode.disable;
  }
}
