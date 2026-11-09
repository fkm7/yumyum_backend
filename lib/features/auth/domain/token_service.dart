/// The claims carried by a verified refresh token.
class RefreshTokenClaims {
  /// Constructs [RefreshTokenClaims].
  const RefreshTokenClaims({required this.uid, required this.tokenId});

  /// The user the token was issued to.
  final String uid;

  /// The `jti` claim, identifying the stored record for this token.
  ///
  /// This is what makes a refresh token revocable: verification proves the
  /// token was signed by this server, and the id says which one it is.
  final String tokenId;
}

/// Issues and verifies signed access and refresh tokens.
///
/// A port: the application layer depends on this, and the token format (JWT,
/// today) is an infrastructure detail behind it.
abstract interface class TokenService {
  /// How long a freshly issued access token remains valid.
  Duration get accessTokenExpiresIn;

  /// How long a freshly issued refresh token remains valid.
  Duration get refreshTokenExpiresIn;

  /// Generates a short-lived access token for the given user ID (uid).
  String generateAccessToken(String uid);

  /// Generates a long-lived refresh token identified by [tokenId].
  ///
  /// [tokenId] must match a stored record, or the token cannot be verified.
  String generateRefreshToken(String uid, {required String tokenId});

  /// Returns the uid from a valid access token, or null if invalid/expired.
  String? verifyAccessToken(String token);

  /// Returns the claims of a valid refresh token, or null if invalid/expired.
  RefreshTokenClaims? verifyRefreshToken(String token);
}
