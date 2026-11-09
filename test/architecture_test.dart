import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// Enforces the Clean Architecture dependency rule by reading imports.
///
/// Dependencies point inward only:
///
///     routes, presentation  →  application  →  domain
///                       infrastructure  →  domain
///
/// `lib/di/` is the composition root and the one place allowed to see
/// everything. These checks are textual, so they run without a database and
/// fail the build the moment a forbidden import is added.
void main() {
  group('dependency rule', () {
    test('domain is plain Dart: no framework, I/O or outer layers', () {
      expectNoImports(
        layerFiles('domain'),
        forbidden: [
          'dart:io',
          'package:dart_frog/',
          'package:postgres/',
          '/application/',
          '/infrastructure/',
          '/presentation/',
          'package:yumyum_backend/core/',
          'package:yumyum_backend/di/',
        ],
      );
    });

    test('application depends only on domain and other use cases', () {
      expectNoImports(
        layerFiles('application'),
        forbidden: [
          'dart:io',
          'package:dart_frog/',
          'package:postgres/',
          '/infrastructure/',
          '/presentation/',
          'package:yumyum_backend/core/',
          'package:yumyum_backend/di/',
        ],
      );
    });

    test('infrastructure implements domain ports, never use cases or HTTP', () {
      expectNoImports(
        layerFiles('infrastructure'),
        forbidden: [
          'package:dart_frog/',
          '/application/',
          '/presentation/',
          'package:yumyum_backend/di/',
        ],
      );
    });

    test('presentation never reaches infrastructure', () {
      expectNoImports(
        layerFiles('presentation'),
        forbidden: [
          'package:postgres/',
          '/infrastructure/',
          'package:yumyum_backend/core/db/',
          'package:yumyum_backend/di/',
        ],
      );
    });

    test('routes never reach infrastructure or the database', () {
      final routes = dartFiles('routes').where(
        (f) => p.normalize(f.path) != p.join('routes', '_middleware.dart'),
      );
      expectNoImports(
        routes,
        forbidden: [
          'package:postgres/',
          '/infrastructure/',
          'package:yumyum_backend/core/db/',
          'package:yumyum_backend/di/',
        ],
      );
    });

    test('core is feature-agnostic', () {
      expectNoImports(
        dartFiles(p.join('lib', 'core')),
        forbidden: ['package:yumyum_backend/features/'],
      );
    });
  });
}

Iterable<File> dartFiles(String directory) => Directory(directory)
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'));

/// Every Dart file in a `<layer>/` directory under any feature.
Iterable<File> layerFiles(String layer) {
  final files = dartFiles(p.join('lib', 'features'))
      .where((f) => p.split(f.path).contains(layer))
      .toList();
  // Guards against the check silently passing because a layer was renamed.
  expect(files, isNotEmpty, reason: 'no $layer files found');
  return files;
}

final _import = RegExp(r'''^\s*(?:import|export)\s+['"]([^'"]+)['"]''');

void expectNoImports(
  Iterable<File> files, {
  required List<String> forbidden,
}) {
  final violations = <String>[];
  for (final file in files) {
    final lines = file.readAsLinesSync();
    for (var i = 0; i < lines.length; i++) {
      final uri = _import.firstMatch(lines[i])?.group(1);
      if (uri == null) continue;
      for (final pattern in forbidden) {
        if (uri.contains(pattern)) {
          violations.add('${file.path}:${i + 1} imports $uri');
        }
      }
    }
  }
  expect(violations, isEmpty, reason: violations.join('\n'));
}
