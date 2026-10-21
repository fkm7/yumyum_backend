import 'package:yumyum_backend/models/credential.dart';
import 'package:yumyum_backend/models/user.dart';

/// Read and write access to account credentials.
///
/// The only repository that touches `users.password_hash`; `UserRepository`
/// deliberately never selects or writes it.
abstract class AuthRepository {
  /// Creates an account with the given profile and [passwordHash], and
  /// returns its profile, or returns null when [email] is already registered.
  ///
  /// Uniqueness is enforced by the database rather than by a preceding SELECT,
  /// so two concurrent registrations of the same address cannot both succeed.
  Future<User?> createAccount({
    required String firstName,
    required String lastName,
    required String email,
    required String passwordHash,
  });

  /// Returns the credential for [email], or null when no such account exists.
  Future<Credential?> findByEmail(String email);

  /// Returns the credential for [uid], or null when no such account exists.
  Future<Credential?> findByUid(String uid);

  /// Replaces the stored password digest for [uid].
  Future<void> updatePasswordHash(String uid, String passwordHash);
}
