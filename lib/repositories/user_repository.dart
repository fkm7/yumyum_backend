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
}
