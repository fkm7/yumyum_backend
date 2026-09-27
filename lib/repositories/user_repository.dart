import 'package:delmer_backend/models/user.dart';

/// Read and write access to the `users` table.
abstract class UserRepository {
  /// Returns the user with the given email, including their password digest,
  /// or null when no such user exists.
  Future<User?> findByEmail(String email);

  /// Returns the user with the given uid, or null when no such user exists.
  ///
  /// The returned [User] does not carry a password digest.
  Future<User?> findByUid(String uid);

  /// Creates a user and returns it, or returns null when [email] is already
  /// registered.
  ///
  /// Uniqueness is enforced by the database rather than by a preceding SELECT,
  /// so two concurrent registrations of the same address cannot both succeed.
  Future<User?> create({
    required String firstName,
    required String lastName,
    required String email,
    required String passwordHash,
  });

  /// Replaces the stored password digest for [uid].
  ///
  /// Used to upgrade a credential in place after a successful login against an
  /// outdated digest, which is the only moment the plaintext is available.
  Future<void> updatePasswordHash(String uid, String passwordHash);

  /// Updates the given profile fields for [uid], applying only the non-null
  /// ones, and returns the updated user, or null when no such user exists.
  ///
  /// Email is deliberately not editable here: changing it interacts with the
  /// unique constraint and would need re-verification, which is out of
  /// scope for a plain profile edit.
  Future<User?> updateProfile(
    String uid, {
    String? firstName,
    String? lastName,
    String? photoUrl,
  });

  /// Permanently deletes the user with the given [uid] and everything that
  /// belongs only to them.
  ///
  /// Favorites, saved addresses, saved payment methods and refresh tokens are
  /// removed as a side effect of the database's `ON DELETE CASCADE`
  /// constraints. Past orders are kept — `orders.user_id` uses
  /// `ON DELETE SET NULL` instead — but the delivery-address and
  /// payment-detail snapshots captured on them are scrubbed first, since the
  /// foreign key action alone does not touch those JSONB columns.
  ///
  /// A no-op when no such user exists, so callers can treat deletion as
  /// idempotent.
  Future<void> delete(String uid);
}
