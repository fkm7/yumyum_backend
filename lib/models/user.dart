/// A model class representing a user.
class User {
  /// Constructs a [User] instance with the given properties.
  const User({
    required this.uid,
    required this.firstName,
    required this.lastName,
    required this.email,
    this.photoUrl,
  });

  /// Builds a [User] from a database column map.
  ///
  /// A profile never carries the password digest — see `Credential`.
  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      uid: map['uid'] as String,
      firstName: map['first_name'] as String,
      lastName: map['last_name'] as String,
      email: map['email'] as String,
      photoUrl: (map['photo_url'] as String?) ?? '',
    );
  }

  /// Creates a copy of this [User] with the given properties replaced.
  User copyWith({
    String? firstName,
    String? lastName,
    String? email,
    String? photoUrl,
  }) {
    return User(
      uid: uid,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      photoUrl: photoUrl ?? this.photoUrl,
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
  final String? photoUrl;

  /// The public JSON representation of this user.
  ///
  /// Keys are snake_case to match the rest of the API and the database.
  Map<String, dynamic> toMap() => {
        'uid': uid,
        'first_name': firstName,
        'last_name': lastName,
        'email': email,
        'photo_url': photoUrl,
      };
}
