import 'package:delmer_backend/models/refresh_token_record.dart';
import 'package:delmer_backend/models/user.dart';
import 'package:delmer_backend/repositories/refresh_token_repository.dart';
import 'package:delmer_backend/repositories/user_repository.dart';

/// An in-memory [RefreshTokenRepository].
///
/// A fake rather than a mock: rotation is about how records change across a
/// sequence of calls, which stubbed return values express badly.
class InMemoryRefreshTokenRepository implements RefreshTokenRepository {
  /// Every record issued so far, keyed by token id.
  final Map<String, RefreshTokenRecord> records = {};

  @override
  Future<void> issue(RefreshTokenRecord record) async {
    records[record.id] = record;
  }

  @override
  Future<RefreshTokenRecord?> findById(String id) async => records[id];

  @override
  Future<void> revoke(
    String id, {
    required DateTime revokedAt,
    String? replacedBy,
  }) async {
    final record = records[id];
    if (record == null || record.isRevoked) return;
    records[id] = RefreshTokenRecord(
      id: record.id,
      userId: record.userId,
      familyId: record.familyId,
      issuedAt: record.issuedAt,
      expiresAt: record.expiresAt,
      revokedAt: revokedAt,
      replacedBy: replacedBy,
    );
  }

  @override
  Future<void> revokeFamily(
    String familyId, {
    required DateTime revokedAt,
  }) async {
    for (final record in records.values.toList()) {
      if (record.familyId == familyId && !record.isRevoked) {
        await revoke(record.id, revokedAt: revokedAt);
      }
    }
  }

  @override
  Future<int> deleteExpired(DateTime now) async {
    final expired = records.values
        .where((r) => r.hasExpired(now))
        .map((r) => r.id)
        .toList();
    for (final id in expired) {
      records.remove(id);
    }
    return expired.length;
  }
}

/// A [UserRepository] that always answers with [user].
class StubUserRepository implements UserRepository {
  /// Constructs a [StubUserRepository] answering with [user].
  StubUserRepository([this.user]);

  /// The user every lookup returns; null means "no such user".
  User? user;

  @override
  Future<User?> findByUid(String uid) async => user;

  @override
  Future<User?> findByEmail(String email) async => user;

  @override
  Future<User?> create({
    required String firstName,
    required String lastName,
    required String email,
    required String passwordHash,
  }) async =>
      user;

  @override
  Future<void> updatePasswordHash(String uid, String passwordHash) async {}
}
