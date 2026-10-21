import 'dart:io';

import 'package:test/test.dart';
import 'package:yumyum_backend/core/db/migrator.dart';

void main() {
  group('parseMigrations', () {
    test('orders by numeric version, not by map order', () {
      final migrations = parseMigrations({
        '010_later.sql': 'b',
        '002_second.sql': 'a',
        '001_first.sql': 'c',
      });

      expect(
        migrations.map((m) => m.toString()),
        equals(['001_first', '002_second', '010_later']),
      );
    });

    test('rejects a file name without a version prefix', () {
      expect(
        () => parseMigrations({'schema.sql': ''}),
        throwsFormatException,
      );
    });

    test('rejects two files with the same version', () {
      expect(
        () => parseMigrations({'001_a.sql': '', '001_b.sql': ''}),
        throwsFormatException,
      );
    });
  });

  test('pendingMigrations skips versions already applied', () {
    final all = parseMigrations({
      '001_a.sql': '',
      '002_b.sql': '',
      '003_c.sql': '',
    });

    expect(
      pendingMigrations(all, {'001', '003'}).map((m) => m.version),
      equals(['002']),
    );
  });

  // Guards the real directory, so a misnamed file fails here rather than at
  // deploy time.
  test('db/migrations parses cleanly', () async {
    final migrations = parseMigrations(
      await readSqlFiles(Directory('db/migrations')),
    );

    expect(migrations, isNotEmpty);
    expect(migrations.first.version, equals('001'));
  });
}
