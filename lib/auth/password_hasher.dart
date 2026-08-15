/// Hashes and verifies user passwords.
///
/// Verification is separated from hashing so that the stored digest carries its
/// own parameters (algorithm, cost, salt). That is what lets the stored format
/// change without invalidating existing credentials.
abstract class PasswordHasher {
  /// Returns a digest of [password] suitable for storage.
  ///
  /// Two calls with the same password return different digests, because the
  /// salt is generated per call.
  String hash(String password);

  /// Whether [password] matches [storedHash].
  ///
  /// Returns false rather than throwing for a malformed or unrecognised
  /// [storedHash].
  bool verify(String password, String storedHash);

  /// Whether [storedHash] was produced by an outdated algorithm or cost and
  /// should be replaced next time the plaintext is available.
  bool needsRehash(String storedHash);

  /// Performs the same work as [verify] against a throwaway digest.
  ///
  /// Call this when no user matched, so that the time taken to answer does not
  /// reveal whether the address is registered.
  void verifyAbsentUser(String password);
}
