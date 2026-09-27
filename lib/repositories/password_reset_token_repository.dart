import 'package:delmer_backend/models/password_reset_token.dart';

/// Read and write access to the `password_reset_tokens` table.
abstract class PasswordResetTokenRepository {
  /// Stores a newly issued token.
  Future<void> issue(PasswordResetToken token);

  /// Returns the record whose [PasswordResetToken.tokenHash] matches
  /// [tokenHash], or null when no such record exists.
  ///
  /// The caller still has to check [PasswordResetToken.isUsed] and
  /// [PasswordResetToken.hasExpired] — a hash matching a row does not by
  /// itself mean the token is still valid.
  Future<PasswordResetToken?> findByTokenHash(String tokenHash);

  /// Marks [id] used at [usedAt], so it cannot be replayed.
  Future<void> markUsed(String id, {required DateTime usedAt});

  /// Deletes every unused token belonging to [userId].
  ///
  /// Called before issuing a new token, so a user only ever has one
  /// outstanding, valid reset link at a time.
  Future<void> deleteUnusedForUser(String userId);
}
