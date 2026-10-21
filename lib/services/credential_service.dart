import 'package:yumyum_backend/auth/password_hasher.dart';
import 'package:yumyum_backend/models/user.dart';
import 'package:yumyum_backend/repositories/auth_repository.dart';

/// Creates, checks and changes password credentials.
///
/// The single place that combines [PasswordHasher] with stored digests, so
/// the timing-equalisation and rehash-on-login rules cannot drift apart
/// between login, password change and account deletion.
class CredentialService {
  /// Constructs a [CredentialService].
  const CredentialService({
    required AuthRepository credentials,
    required PasswordHasher hasher,
  })  : _credentials = credentials,
        _hasher = hasher;

  final AuthRepository _credentials;
  final PasswordHasher _hasher;

  /// Registers a new account, or returns null when [email] is taken.
  Future<User?> register({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
  }) {
    return _credentials.createAccount(
      firstName: firstName,
      lastName: lastName,
      email: email,
      passwordHash: _hasher.hash(password),
    );
  }

  /// Returns the uid of the account registered to [email] when [password]
  /// matches it, otherwise null.
  ///
  /// An unknown email and a wrong password are indistinguishable to the
  /// caller, in both result and time taken.
  Future<String?> verifyByEmail(String email, String password) async {
    final credential = await _credentials.findByEmail(email);
    if (credential == null) {
      // Hash anyway. bcrypt is deliberately slow, so returning here without
      // doing the work would make an unregistered address measurably faster
      // to reject than a registered one with the wrong password.
      _hasher.verifyAbsentUser(password);
      return null;
    }
    return await _verify(credential.uid, credential.passwordHash, password)
        ? credential.uid
        : null;
  }

  /// Whether [password] matches the account [uid].
  Future<bool> verifyByUid(String uid, String password) async {
    final credential = await _credentials.findByUid(uid);
    if (credential == null) {
      _hasher.verifyAbsentUser(password);
      return false;
    }
    return _verify(uid, credential.passwordHash, password);
  }

  /// Replaces the password for [uid] with [newPassword].
  Future<void> setPassword(String uid, String newPassword) =>
      _credentials.updatePasswordHash(uid, _hasher.hash(newPassword));

  Future<bool> _verify(String uid, String storedHash, String password) async {
    if (!_hasher.verify(password, storedHash)) return false;

    // A successful check is the only point where the plaintext is available,
    // so it is the only chance to move a legacy digest onto the current
    // algorithm.
    if (_hasher.needsRehash(storedHash)) {
      await setPassword(uid, password);
    }
    return true;
  }
}
