/// A model class representing a user.
class User {
  /// Constructs a [User] instance with the given properties.
  const User({
    required this.uid,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.photoUrl,
  });

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
}
