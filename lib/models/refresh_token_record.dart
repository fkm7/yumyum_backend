/// The stored counterpart of an issued refresh token.
///
/// A refresh token is only usable while a matching, unrevoked, unexpired
/// record exists. Verification of the JWT alone is not enough — that is what
/// makes revocation possible.
class RefreshTokenRecord {
  /// Constructs a [RefreshTokenRecord].
  const RefreshTokenRecord({
    required this.id,
    required this.userId,
    required this.familyId,
    required this.issuedAt,
    required this.expiresAt,
    this.revokedAt,
    this.replacedBy,
  });

  /// Builds a [RefreshTokenRecord] from a database column map.
  factory RefreshTokenRecord.fromRow(Map<String, dynamic> row) {
    return RefreshTokenRecord(
      id: row['id'] as String,
      userId: row['user_id'] as String,
      familyId: row['family_id'] as String,
      issuedAt: row['issued_at'] as DateTime,
      expiresAt: row['expires_at'] as DateTime,
      revokedAt: row['revoked_at'] as DateTime?,
      replacedBy: row['replaced_by'] as String?,
    );
  }

  /// The token's `jti`.
  final String id;

  /// The user the token was issued to.
  final String userId;

  /// Identifier shared by every token in this rotation chain.
  final String familyId;

  /// When the token was issued.
  final DateTime issuedAt;

  /// When the token stops being accepted.
  final DateTime expiresAt;

  /// When the token was revoked, if it has been.
  final DateTime? revokedAt;

  /// The id of the token that superseded this one, if it was rotated.
  final String? replacedBy;

  /// Whether this token has been revoked, whether by rotation or by logout.
  bool get isRevoked => revokedAt != null;

  /// Whether this token has passed its expiry as of [now].
  ///
  /// The boundary counts as expired: a token is usable strictly before the
  /// instant it expires.
  bool hasExpired(DateTime now) => !expiresAt.isAfter(now);
}
