import 'package:delmer_backend/models/refresh_token_record.dart';

/// Read and write access to the `refresh_tokens` table.
abstract class RefreshTokenRepository {
  /// Stores a newly issued token.
  Future<void> issue(RefreshTokenRecord record);

  /// Returns the record for [id], or null when no such token was issued.
  Future<RefreshTokenRecord?> findById(String id);

  /// Marks [id] revoked at [revokedAt], optionally recording the token that
  /// superseded it.
  ///
  /// Revoking an already-revoked or unknown token is a no-op, so callers do
  /// not have to check first.
  Future<void> revoke(
    String id, {
    required DateTime revokedAt,
    String? replacedBy,
  });

  /// Revokes every unrevoked token in [familyId].
  ///
  /// Used when a rotated token is presented a second time: the chain is
  /// assumed compromised, so the whole family goes rather than just the token
  /// that was replayed.
  Future<void> revokeFamily(String familyId, {required DateTime revokedAt});

  /// Deletes records that expired before [now], returning how many went.
  ///
  /// Expired tokens are already refused, so this is housekeeping rather than a
  /// security control; it needs to be run periodically or the table grows
  /// without bound.
  Future<int> deleteExpired(DateTime now);
}
