import 'package:yumyum_backend/repositories/user_repository.dart';
import 'package:yumyum_backend/services/credential_service.dart';

/// The outcome of a password-confirmed account deletion.
sealed class AccountDeletionResult {
  const AccountDeletionResult();
}

/// The password matched and the account was deleted.
class AccountDeleted extends AccountDeletionResult {
  /// Constructs an [AccountDeleted].
  const AccountDeleted();
}

/// The account is unknown or the password is wrong.
///
/// Deliberately one variant for both reasons, like an unknown vs.
/// wrong-password login: a caller should not be able to tell which emails
/// have accounts.
class AccountCredentialsRejected extends AccountDeletionResult {
  /// Constructs an [AccountCredentialsRejected].
  const AccountCredentialsRejected();
}

/// Deletes an account once its password has been confirmed.
///
/// Shared by the in-app `DELETE /auth/delete_account` endpoint and the public
/// `/delete_account` web page, so both enforce exactly the same check.
class AccountDeletionService {
  /// Constructs an [AccountDeletionService].
  const AccountDeletionService({
    required UserRepository users,
    required CredentialService credentials,
  })  : _users = users,
        _credentials = credentials;

  final UserRepository _users;
  final CredentialService _credentials;

  /// Deletes the account registered to [email] if [password] matches it.
  Future<AccountDeletionResult> deleteByEmail({
    required String email,
    required String password,
  }) async {
    final uid = await _credentials.verifyByEmail(email, password);
    if (uid == null) return const AccountCredentialsRejected();
    await _users.delete(uid);
    return const AccountDeleted();
  }

  /// Deletes the account [uid] if [password] matches it.
  Future<AccountDeletionResult> deleteByUid({
    required String uid,
    required String password,
  }) async {
    if (!await _credentials.verifyByUid(uid, password)) {
      return const AccountCredentialsRejected();
    }
    await _users.delete(uid);
    return const AccountDeleted();
  }
}
