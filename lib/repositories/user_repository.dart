import 'package:yumyum_backend/models/user.dart';

/// Read and write access to user profiles in the `users` table.
///
/// Credentials are out of scope: account creation and the password digest
/// belong to `CredentialRepository`.
abstract class UserRepository {
  /// Returns the user with the given email, or null when no such user exists.
  Future<User?> findByEmail(String email);

  /// Returns the user with the given uid, or null when no such user exists.
  Future<User?> findByUid(String uid);

  /// Updates the profile photo URL for [uid], or does nothing when no such user
  /// exists.
  Future<void> updatePhotoUri({
    required String uid,
    required String photoUrl,
  });

  /// Returns the current profile photo URL for [uid], or null when no such user
  /// exists or the user has no photo.
  Future<String?> getPhotoUri({required String uid});

  /// Updates the given profile fields for [uid], applying only the non-null
  /// ones, and returns the updated user, or null when no such user exists.
  ///
  /// Email is deliberately not editable here: changing it interacts with the
  /// unique constraint and would need re-verification, which is out of
  /// scope for a plain profile edit.
  Future<User?> updateProfile({
    required String uid,
    String? firstName,
    String? lastName,
    String? email,
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
