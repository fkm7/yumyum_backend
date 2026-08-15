import 'dart:convert';
import 'dart:io';

import 'package:bcrypt/bcrypt.dart';
import 'package:crypto/crypto.dart';
import 'package:delmer_backend/auth/password_hasher.dart';

/// The digest format used before bcrypt: unsalted, single-round SHA-256.
///
/// Kept only so that credentials created under the old scheme can still be
/// verified and then upgraded. Never use it to store a new password.
String legacySha256Digest(String password) =>
    sha256.convert(utf8.encode(password)).toString();

final _legacyPattern = RegExp(r'^[0-9a-f]{64}$');
final _bcryptCostPattern = RegExp(r'^\$2[abxy]\$(\d{2})\$');

/// A [PasswordHasher] backed by bcrypt, accepting legacy SHA-256 digests for
/// verification only.
class BcryptPasswordHasher implements PasswordHasher {
  /// Constructs a hasher at the given [rounds] cost factor.
  ///
  /// Cost is logarithmic: each extra round doubles the work. 12 is a
  /// reasonable production default; tests should pass something near the
  /// minimum of 4 so the suite stays fast.
  BcryptPasswordHasher({this.rounds = defaultRounds})
      : assert(
          rounds >= 4 && rounds <= 31,
          'bcrypt cost must be between 4 and 31',
        );

  /// Reads the cost factor from `BCRYPT_ROUNDS`, falling back to
  /// [defaultRounds].
  factory BcryptPasswordHasher.fromEnvironment() => BcryptPasswordHasher(
        rounds: parseRounds(Platform.environment['BCRYPT_ROUNDS']),
      );

  /// The cost factor used for newly created digests.
  static const defaultRounds = 12;

  /// Interprets a `BCRYPT_ROUNDS` value, falling back to [defaultRounds].
  ///
  /// A missing, unparseable, or out-of-range value falls back rather than
  /// throwing: a typo in the environment should not stop the server booting,
  /// and must never silently weaken hashing below the default.
  static int parseRounds(String? raw) {
    final parsed = raw == null ? null : int.tryParse(raw);
    if (parsed == null || parsed < defaultRounds || parsed > 31) {
      return defaultRounds;
    }
    return parsed;
  }

  /// The bcrypt cost factor applied by [hash].
  final int rounds;

  /// A digest to compare against when no user was found.
  ///
  /// Computed once on first use so that [verifyAbsentUser] costs the same as a
  /// real verification without paying for it at startup.
  late final String _absentUserDigest = hash('absent-user-placeholder');

  @override
  String hash(String password) =>
      BCrypt.hashpw(_prepare(password), BCrypt.gensalt(logRounds: rounds));

  @override
  bool verify(String password, String storedHash) {
    if (storedHash.isEmpty) return false;

    if (_legacyPattern.hasMatch(storedHash)) {
      return _constantTimeEquals(legacySha256Digest(password), storedHash);
    }

    try {
      // Re-hashing with the stored digest as the salt reproduces it when the
      // password matches. Compared here rather than via BCrypt.checkpw, whose
      // String.compareTo returns early on the first differing byte.
      return _constantTimeEquals(
        BCrypt.hashpw(_prepare(password), storedHash),
        storedHash,
      );
    } catch (_) {
      // A malformed digest is a bad credential, not a server error.
      return false;
    }
  }

  @override
  bool needsRehash(String storedHash) {
    if (_legacyPattern.hasMatch(storedHash)) return true;

    final cost = _bcryptCostPattern.firstMatch(storedHash)?.group(1);
    if (cost == null) return true;

    return int.parse(cost) != rounds;
  }

  @override
  void verifyAbsentUser(String password) {
    verify(password, _absentUserDigest);
  }

  /// Reduces [password] to a fixed-width token before bcrypt sees it.
  ///
  /// bcrypt rejects inputs longer than 72 bytes outright, so a long passphrase
  /// would otherwise throw. Hashing first keeps the full entropy of the
  /// password, and base64 is used rather than raw digest bytes because bcrypt
  /// truncates at the first NUL.
  String _prepare(String password) =>
      base64.encode(sha256.convert(utf8.encode(password)).bytes);

  /// Compares two strings in time that depends on their length, not contents.
  bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var difference = 0;
    for (var i = 0; i < a.length; i++) {
      difference |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return difference == 0;
  }
}
