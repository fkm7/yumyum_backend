import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Returns a hashed version of the password using SHA-256.
///
/// NOTE: this is an unsalted fast hash and is **not** suitable for production
/// credential storage — it is vulnerable to rainbow-table and brute-force
/// attacks. It is kept as-is here so existing `users.password_hash` rows stay
/// valid; migrating to bcrypt/argon2 means changing this single function and
/// re-hashing on next successful login.
String hashPassword(String password) {
  final bytes = utf8.encode(password);
  return sha256.convert(bytes).toString();
}
