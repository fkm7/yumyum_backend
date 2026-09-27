import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:delmer_backend/auth/password_hasher.dart';
import 'package:delmer_backend/models/password_reset_token.dart';
import 'package:delmer_backend/models/user.dart';
import 'package:delmer_backend/repositories/password_reset_token_repository.dart';
import 'package:delmer_backend/repositories/user_repository.dart';
import 'package:delmer_backend/services/email_service.dart';
import 'package:delmer_backend/services/session_service.dart';
import 'package:uuid/uuid.dart';

/// The outcome of confirming a password reset.
sealed class PasswordResetConfirmResult {
  const PasswordResetConfirmResult();
}

/// The token was valid; the password was changed and [tokens]/[user] are
/// ready to use, logging the caller straight in.
class PasswordResetConfirmed extends PasswordResetConfirmResult {
  /// Constructs a [PasswordResetConfirmed].
  const PasswordResetConfirmed(this.tokens, this.user);

  /// A freshly issued session for the user whose password was just reset.
  final TokenPair tokens;

  /// The user whose password was reset.
  final User user;
}

/// The token was missing, already used, or expired.
///
/// Deliberately one variant for all three reasons: like an unknown vs.
/// wrong-password login, a caller should not be able to distinguish "this
/// token never existed" from "it existed but already got used".
class PasswordResetTokenRejected extends PasswordResetConfirmResult {
  /// Constructs a [PasswordResetTokenRejected].
  const PasswordResetTokenRejected();
}

/// Issues and confirms password-reset tokens, and sends the reset email.
class PasswordResetService {
  /// Constructs a [PasswordResetService].
  PasswordResetService({
    required UserRepository users,
    required PasswordResetTokenRepository tokens,
    required EmailService emailService,
    required PasswordHasher hasher,
    required SessionService sessions,
    required String resetUrlBase,
    Uuid uuid = const Uuid(),
    DateTime Function() now = DateTime.now,
    Duration tokenLifetime = const Duration(minutes: 30),
  })  : _users = users,
        _tokens = tokens,
        _emailService = emailService,
        _hasher = hasher,
        _sessions = sessions,
        _resetUrlBase = resetUrlBase,
        _uuid = uuid,
        _now = now,
        _tokenLifetime = tokenLifetime;

  final UserRepository _users;
  final PasswordResetTokenRepository _tokens;
  final EmailService _emailService;
  final PasswordHasher _hasher;
  final SessionService _sessions;
  final String _resetUrlBase;
  final Uuid _uuid;
  final DateTime Function() _now;
  final Duration _tokenLifetime;

  /// Issues a reset token for [email] and emails it, if that address is
  /// registered.
  ///
  /// Deliberately does nothing detectable when [email] is unregistered: the
  /// caller (the route) always sends the same response either way, so this
  /// endpoint cannot be used to check which emails have accounts.
  Future<void> requestReset(String email) async {
    final user = await _users.findByEmail(email);
    if (user == null) return;

    final rawToken = _uuid.v4();
    final now = _now();

    // Only one outstanding, valid link per user at a time.
    await _tokens.deleteUnusedForUser(user.uid);
    await _tokens.issue(
      PasswordResetToken(
        id: _uuid.v4(),
        userId: user.uid,
        tokenHash: _hash(rawToken),
        expiresAt: now.add(_tokenLifetime),
      ),
    );

    await _emailService.sendPasswordResetEmail(
      toEmail: user.email,
      firstName: user.firstName,
      resetUrl: '$_resetUrlBase?token=$rawToken',
    );
  }

  /// Confirms a reset: validates [rawToken], sets [newPassword], revokes
  /// every other session, and returns a fresh one for the caller.
  Future<PasswordResetConfirmResult> confirm({
    required String rawToken,
    required String newPassword,
  }) async {
    final record = await _tokens.findByTokenHash(_hash(rawToken));
    final now = _now();

    if (record == null || record.isUsed || record.hasExpired(now)) {
      return const PasswordResetTokenRejected();
    }

    final user = await _users.findByUid(record.userId);
    if (user == null) return const PasswordResetTokenRejected();

    await _users.updatePasswordHash(user.uid, _hasher.hash(newPassword));
    await _tokens.markUsed(record.id, usedAt: now);

    final tokenPair = await _sessions.restartAllSessions(user.uid);
    return PasswordResetConfirmed(tokenPair, user);
  }

  String _hash(String rawToken) =>
      sha256.convert(utf8.encode(rawToken)).toString();
}
