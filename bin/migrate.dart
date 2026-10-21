import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yumyum_backend/core/db/database_service.dart';
import 'package:yumyum_backend/core/db/migrator.dart';

/// Applies pending database migrations from `db/migrations/`.
///
///     dart run bin/migrate.dart           # migrations only
///     dart run bin/migrate.dart --seed    # then load db/seeds/ (dev, CI)
///
/// Connects with the same `DATABASE_URL` / `DB_*` variables as the server.
/// `DB_DIR` overrides where `migrations/` and `seeds/` are read from, for the
/// compiled binary in the Docker image.
Future<void> main(List<String> args) async {
  final unknown = args.where((a) => a != '--seed');
  if (unknown.isNotEmpty) {
    stderr.writeln('Unknown arguments: ${unknown.join(' ')}\n'
        'Usage: migrate [--seed]');
    exit(64);
  }

  final dbDir = Platform.environment['DB_DIR'] ?? 'db';
  final connection = await DatabaseService.instance.connection;
  final migrator = Migrator(connection);

  try {
    final migrations = parseMigrations(
      await readSqlFiles(Directory(p.join(dbDir, 'migrations'))),
    );
    final applied = await migrator.migrate(migrations);
    stdout.writeln(
      applied.isEmpty
          ? 'Database is up to date (${migrations.length} migrations).'
          : 'Applied: ${applied.join(', ')}',
    );

    if (args.contains('--seed')) {
      final seeds = await readSqlFiles(Directory(p.join(dbDir, 'seeds')));
      final names = seeds.keys.toList()..sort();
      await migrator.seed([for (final name in names) seeds[name]!]);
      stdout.writeln('Seeded: ${names.join(', ')}');
    }
  } finally {
    await connection.close();
  }
}
