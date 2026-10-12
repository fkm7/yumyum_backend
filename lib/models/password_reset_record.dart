/// Represents a password reset request in the system.
class PasswordResetRecord {
  /// Creates a new instance of [PasswordResetRecord].
  const PasswordResetRecord({
    required this.id,
    required this.userId,
    required this.tokenHash,
    required this.expiresAt,
    required this.createdAt,
    this.usedAt,
  });

  /// Creates a [PasswordResetRecord] instance from a map of key-value pairs.
  factory PasswordResetRecord.fromMap(Map<String, dynamic> row) =>
      PasswordResetRecord(
        id: row['id'] as String,
        userId: row['user_id'] as String,
        tokenHash: row['token_hash'] as String,
        expiresAt: row['expires_at'] as DateTime,
        usedAt: row['used_at'] as DateTime?,
        createdAt: row['created_at'] as DateTime,
      );

  /// The unique identifier for this password reset request.
  final String id;

  /// The identifier of the user who requested the password reset.
  final String userId;

  /// The hashed token used for validating the password reset request.
  final String tokenHash;

  /// The date and time when this password reset request expires.
  final DateTime expiresAt;

  /// The date and time when this password reset request was used,
  /// if applicable.
  final DateTime? usedAt;

  /// The date and time when this password reset request was created.
  final DateTime createdAt;

  /// Returns `true` if the password reset request has expired,
  /// otherwise `false`.
  bool get isExpired => DateTime.now().toUtc().isAfter(expiresAt);

  /// Returns `true` if the password reset request has been used,
  /// otherwise `false`.
  bool get isUsed => usedAt != null;

  /// Returns `true` if the password reset request is valid
  /// (not expired and not used), otherwise `false`.
  bool get isValid => !isExpired && !isUsed;
}
