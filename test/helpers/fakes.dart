import 'dart:core';

import 'package:uuid/uuid.dart';

import 'package:yumyum_backend/models/credential.dart';
import 'package:yumyum_backend/models/refresh_token_record.dart';
import 'package:yumyum_backend/models/user.dart';
import 'package:yumyum_backend/repositories/auth_repository.dart';
import 'package:yumyum_backend/repositories/refresh_token_repository.dart';
import 'package:yumyum_backend/repositories/user_repository.dart';

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

  @override
  Future<void> revokeAllRefreshTokensForUser(
    String uid, {
    required DateTime revokedAt,
  }) async {
    for (final record in records.values.toList()) {
      await revoke(record.id, revokedAt: revokedAt);
    }
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
  Future<User?> updateProfile({
    required String uid,
    String? phoneNumber,
    String? firstName,
    String? lastName,
    String? email,
  }) async =>
      User(
        uid: uid,
        firstName: firstName ?? user?.firstName ?? '',
        lastName: lastName ?? user?.lastName ?? '',
        email: email ?? user?.email ?? '',
      );

  @override
  Future<String?> getPhotoUri({required String uid}) async {
    return null;
  }

  @override
  Future<void> updatePhotoUri({
    required String uid,
    required String photoUrl,
  }) async {}

  @override
  Future<void> delete(String uid) async {}
}

/// A [AuthRepository] holding at most one [credential], which every
/// lookup returns and [updatePasswordHash] rewrites in place.
class StubCredentialRepository implements AuthRepository {
  /// Constructs a [StubCredentialRepository] holding [credential].
  StubCredentialRepository([this.credential]);

  final Uuid _uuid = const Uuid();

  /// The stored credential; null means "no such account".
  Credential? credential;

  /// Every digest written through [updatePasswordHash], in order.
  final List<String> writtenHashes = [];

  @override
  Future<User?> createAccount({
    required String firstName,
    required String lastName,
    required String email,
    required String passwordHash,
  }) async {
    final uid = _uuid.v4();
    credential = Credential(uid: uid, passwordHash: passwordHash);
    return User(
      uid: uid,
      firstName: firstName,
      lastName: lastName,
      email: email,
      photoUrl: '',
    );
  }

  @override
  Future<Credential?> findByEmail(String email) async => credential;

  @override
  Future<Credential?> findByUid(String uid) async => credential;

  @override
  Future<void> updatePasswordHash(String uid, String passwordHash) async {
    writtenHashes.add(passwordHash);
    credential = Credential(uid: uid, passwordHash: passwordHash);
  }
}
