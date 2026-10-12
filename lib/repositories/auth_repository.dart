import 'package:yumyum_backend/models/password_reset_record.dart';

/// Repository for managing authentication-related data in a PostgreSQL database.
abstract class AuthRepository {
  /// Creates a new refresh token record for the given user.
  Future<void> createRefreshToken({
    required String userId,
    required String tokenHash,
    required DateTime expiresAt,
  });

  /// Marks the refresh token record with the given id as used.
  Future<void> markUsedRefreshToken(String uid);

  /// Finds a valid refresh token record by its hash.
  Future<PasswordResetRecord?> findValidRefreshToken(String hashToken);

  /// Creates a new password reset record for the given user.
  Future<void> createPasswordResetRecord({
    required String userId,
    required String tokenHash,
    required DateTime expiresAt,
  });

  /// Updates the user's password hash and
  /// marks the password reset record as used.
  Future<void> resetPassword({
    required String resetId,
    required String userId,
    required String newHash,
  });

  /// Invalidates all password reset records for the given user.
  Future<void> invalidateAllFor(String uid);

  /// Finds a valid password reset record by its hash.
  Future<PasswordResetRecord?> findValidPasswordReset(String tokenHash);

  /// Marks the password reset record with the given id as used.
  Future<void> markPasswordResetUsed(String resetId);

  /// Marks the password reset record with the given id as used.
  Future<void> markUsedResetToken(String id);
}
