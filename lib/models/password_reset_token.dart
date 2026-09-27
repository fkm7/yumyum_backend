/// The stored counterpart of an issued password-reset token.
///
/// Mirrors [RefreshTokenRecord]'s shape: the raw token that goes out in an
/// email is never stored, only its hash, and possession of a valid,
/// unexpired, unused record is what makes a reset link honoured.
class PasswordResetToken {
  /// Constructs a [PasswordResetToken].
  const PasswordResetToken({
    required this.id,
    required this.userId,
    required this.tokenHash,
    required this.expiresAt,
    this.usedAt,
  });

  /// Builds a [PasswordResetToken] from a database column map.
  factory PasswordResetToken.fromRow(Map<String, dynamic> row) {
    return PasswordResetToken(
      id: row['id'] as String,
      userId: row['user_id'] as String,
      tokenHash: row['token_hash'] as String,
      expiresAt: row['expires_at'] as DateTime,
      usedAt: row['used_at'] as DateTime?,
    );
  }

  /// Record identifier.
  final String id;

  /// The user this token was issued for.
  final String userId;

  /// SHA-256 hash of the raw token. The raw value itself is never stored.
  final String tokenHash;

  /// When this token stops being accepted.
  final DateTime expiresAt;

  /// When this token was consumed, if it has been.
  final DateTime? usedAt;

  /// Whether this token has already been used to reset a password.
  bool get isUsed => usedAt != null;

  /// Whether this token has passed its expiry as of [now].
  ///
  /// The boundary counts as expired: a token is usable strictly before the
  /// instant it expires.
  bool hasExpired(DateTime now) => !expiresAt.isAfter(now);
}
