import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:postgres/postgres.dart';

/// One versioned SQL file from `db/migrations/`.
class Migration {
  /// Constructs a [Migration].
  const Migration({
    required this.version,
    required this.name,
    required this.sql,
  });

  /// The numeric prefix, kept as written (`001`), which is what is recorded
  /// in `schema_migrations`.
  final String version;

  /// The rest of the file name, for logs (`initial_schema`).
  final String name;

  /// The statements to run.
  final String sql;

  @override
  String toString() => '${version}_$name';
}

final _fileName = RegExp(r'^(\d{3,})_([a-z0-9_]+)\.sql$');

/// Turns `{fileName: sql}` into migrations ordered by version.
///
/// Throws a [FormatException] for a file that does not follow
/// `NNN_snake_case_name.sql`, or for two files sharing a version — both
/// mistakes would otherwise silently reorder or skip a migration.
List<Migration> parseMigrations(Map<String, String> files) {
  final byVersion = <int, Migration>{};
  for (final entry in files.entries) {
    final match = _fileName.firstMatch(entry.key);
    if (match == null) {
      throw FormatException(
        'Migration file names must look like 001_snake_case_name.sql',
        entry.key,
      );
    }
    final number = int.parse(match.group(1)!);
    final existing = byVersion[number];
    if (existing != null) {
      throw FormatException(
        'Two migrations share version ${match.group(1)}: '
        '$existing and ${entry.key}',
      );
    }
    byVersion[number] = Migration(
      version: match.group(1)!,
      name: match.group(2)!,
      sql: entry.value,
    );
  }
  final versions = byVersion.keys.toList()..sort();
  return [for (final v in versions) byVersion[v]!];
}

/// The migrations from [all] whose version is not in [applied], in order.
List<Migration> pendingMigrations(
  List<Migration> all,
  Set<String> applied,
) =>
    all.where((m) => !applied.contains(m.version)).toList();

/// Reads every `.sql` file in [directory], keyed by file name.
Future<Map<String, String>> readSqlFiles(Directory directory) async {
  final files = <String, String>{};
  await for (final entity in directory.list()) {
    if (entity is File && entity.path.endsWith('.sql')) {
      files[p.basename(entity.path)] = await entity.readAsString();
    }
  }
  return files;
}

/// Applies pending migrations and records them in `schema_migrations`.
class Migrator {
  /// Constructs a [Migrator] over [connection].
  const Migrator(this.connection);

  /// The connection migrations run on. The advisory lock is per session, so
  /// this must be a single connection, not a pool.
  final Connection connection;

  /// Arbitrary, fixed key for `pg_advisory_lock`, so two deploys starting at
  /// once apply migrations one after the other instead of interleaving.
  static const _lockKey = 7253100;

  /// Applies every migration in [all] that has not been applied yet, each in
  /// its own transaction, and returns the ones it applied.
  ///
  /// A failing migration rolls back on its own and stops the run; the ones
  /// before it stay applied and recorded.
  Future<List<Migration>> migrate(List<Migration> all) async {
    await connection.execute('''
      CREATE TABLE IF NOT EXISTS schema_migrations (
        version TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        applied_at TIMESTAMPTZ NOT NULL DEFAULT now()
      )
    ''');

    await connection.execute('SELECT pg_advisory_lock($_lockKey)');
    try {
      final rows = await connection.execute(
        'SELECT version FROM schema_migrations',
      );
      final applied = {for (final row in rows) row[0]! as String};

      final pending = pendingMigrations(all, applied);
      for (final migration in pending) {
        await connection.runTx((tx) async {
          // Simple query mode is what allows a file of several statements.
          await tx.execute(migration.sql, queryMode: QueryMode.simple);
          await tx.execute(
            Sql.named(
              'INSERT INTO schema_migrations (version, name) '
              'VALUES (@version, @name)',
            ),
            parameters: {'version': migration.version, 'name': migration.name},
          );
        });
      }
      return pending;
    } finally {
      await connection.execute('SELECT pg_advisory_unlock($_lockKey)');
    }
  }

  /// Runs each seed script in order. Seeds are not recorded, so they must be
  /// idempotent.
  Future<void> seed(Iterable<String> scripts) async {
    for (final sql in scripts) {
      await connection.runTx(
        (tx) => tx.execute(sql, queryMode: QueryMode.simple),
      );
    }
  }
}
