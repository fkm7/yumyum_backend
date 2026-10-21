/// The stored password credential for one account.
///
/// Kept apart from `User` so profile code never loads, passes around or
/// serialises a password digest. Deliberately has no `toMap`: a credential
/// has no business in a response body.
class Credential {
  /// Constructs a [Credential].
  const Credential({required this.uid, required this.passwordHash});

  /// Builds a [Credential] from a database column map.
  factory Credential.fromMap(Map<String, dynamic> map) => Credential(
        uid: map['uid'] as String,
        passwordHash: map['password_hash'] as String,
      );

  /// The uid of the account this credential belongs to.
  final String uid;

  /// The stored password digest.
  final String passwordHash;
}
