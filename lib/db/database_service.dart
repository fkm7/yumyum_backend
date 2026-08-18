import 'dart:io';

import 'package:postgres/postgres.dart';

/// A singleton service for managing the database connection.
class DatabaseService {
  DatabaseService._();

  /// The singleton instance of the DatabaseService.
  static final DatabaseService instance = DatabaseService._();

  /// The PostgreSQL connection instance.
  late final Future<Connection> connection = Connection.open(
    Endpoint(
      host: Platform.environment['DB_HOST'] ?? 'localhost',
      port: int.parse(Platform.environment['DB_PORT'] ?? '5432'),
      database: Platform.environment['DB_NAME'] ?? 'delmer',
      username: Platform.environment['DB_USER'] ?? 'farrukh',
      password: Platform.environment['DB_PASS'] ?? '1997',
    ),
    settings: const ConnectionSettings(sslMode: SslMode.disable),
  );
}
