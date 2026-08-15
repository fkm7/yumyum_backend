/// A model class representing a user.
class User {
  /// Constructs a [User] instance with the given properties.
  const User({
    required this.uid,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.photoUrl,
    this.passwordHash,
  });

  /// Builds a [User] from a database column map.
  ///
  /// [passwordHash] is only populated when the query selected it; endpoints
  /// that never need the credential simply omit the column.
  factory User.fromRow(Map<String, dynamic> row) {
    return User(
      uid: row['uid'] as String,
      firstName: row['first_name'] as String,
      lastName: row['last_name'] as String,
      email: row['email'] as String,
      photoUrl: (row['photo_url'] as String?) ?? '',
      passwordHash: row['password_hash'] as String?,
    );
  }

  /// User identifier.
  final String uid;

  /// User's first name.
  final String firstName;

  /// User's last name.
  final String lastName;

  /// User's email address.
  final String email;

  /// URL to the user's profile photo.
  final String photoUrl;

  /// The stored password digest, when loaded.
  ///
  /// Deliberately excluded from [toJson] so it cannot leak into a response.
  final String? passwordHash;

  /// The public JSON representation of this user.
  ///
  /// Keys are snake_case to match the rest of the API and the database.
  Map<String, dynamic> toJson() => {
        'uid': uid,
        'first_name': firstName,
        'last_name': lastName,
        'email': email,
        'photo_url': photoUrl,
      };
}
