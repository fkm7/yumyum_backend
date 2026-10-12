import 'package:yumyum_backend/auth/token_service.dart';
import 'package:yumyum_backend/models/refresh_token_record.dart';
import 'package:yumyum_backend/repositories/refresh_token_repository.dart';
import 'package:yumyum_backend/repositories/user_repository.dart';
import 'package:uuid/uuid.dart';

/// A freshly issued access/refresh pair.
class TokenPair {
  /// Constructs a [TokenPair].
  const TokenPair({
    required this.accessToken,
    required this.refreshToken,
    required this.accessTokenExpiresAt,
    required this.refreshTokenExpiresAt,
  });

  /// The short-lived token used to authenticate API requests.
  final String accessToken;

  /// The long-lived token used to obtain the next pair.
  final String refreshToken;

  /// When [accessToken] expires.
  final DateTime accessTokenExpiresAt;

  /// When [refreshToken] expires.
  final DateTime refreshTokenExpiresAt;

  /// The JSON representation of this pair.
  Map<String, dynamic> toJson() => {
        'access_token': accessToken,
        'access_token_expires_at':
            accessTokenExpiresAt.millisecondsSinceEpoch ~/ 1000,
        'refresh_token': refreshToken,
        'refresh_token_expires_at':
            refreshTokenExpiresAt.millisecondsSinceEpoch ~/ 1000,
      };
}

/// The outcome of exchanging a refresh token.
sealed class RefreshResult {
  const RefreshResult();
}

/// The token was valid and has been rotated for [tokens].
class RefreshSucceeded extends RefreshResult {
  /// Constructs a [RefreshSucceeded].
  const RefreshSucceeded(this.tokens);

  /// The newly issued pair. The presented token is now revoked.
  final TokenPair tokens;
}

/// The token was malformed, expired, unknown, or already revoked by a logout.
class RefreshRejected extends RefreshResult {
  /// Constructs a [RefreshRejected].
  const RefreshRejected();
}

/// A token that had already been rotated was presented again.
///
/// The legitimate holder would have discarded it, so either it leaked or the
/// chain was replayed. The whole family is revoked in response.
class RefreshReuseDetected extends RefreshResult {
  /// Constructs a [RefreshReuseDetected] for the revoked [familyId].
  const RefreshReuseDetected(this.familyId);

  /// The family that was revoked.
  final String familyId;
}

/// The token verified but its user no longer exists.
class RefreshUserMissing extends RefreshResult {
  /// Constructs a [RefreshUserMissing].
  const RefreshUserMissing();
}

/// Issues, rotates and revokes login sessions.
class SessionService {
  /// Constructs a [SessionService].
  ///
  /// [now] is injectable so that expiry behaviour is testable without waiting.
  SessionService({
    required TokenService tokenService,
    required RefreshTokenRepository refreshTokenRepository,
    required UserRepository userRepository,
    Uuid uuid = const Uuid(),
    DateTime Function() now = DateTime.now,
  })  : _tokens = tokenService,
        _refreshTokenRepository = refreshTokenRepository,
        _users = userRepository,
        _uuid = uuid,
        _now = now;

  final TokenService _tokens;
  final RefreshTokenRepository _refreshTokenRepository;
  final UserRepository _users;
  final Uuid _uuid;
  final DateTime Function() _now;

  /// Starts a new session for [uid], beginning a fresh rotation family.
  Future<TokenPair> start(String uid) => _issue(uid, familyId: _uuid.v4());

  /// Exchanges [presentedToken] for a new pair, revoking the one presented.
  Future<RefreshResult> rotate(String presentedToken) async {
    final claims = _tokens.verifyRefreshToken(presentedToken);
    if (claims == null) return const RefreshRejected();

    final record = await _refreshTokenRepository.findById(claims.tokenId);
    if (record == null) return const RefreshRejected();

    // The signature proves the server issued the token, but not that it was
    // issued to this user — check the record rather than trusting the claim.
    if (record.userId != claims.uid) return const RefreshRejected();

    final now = _now();

    if (record.isRevoked) {
      // Rotation means the rightful holder already exchanged this token and
      // dropped it. Seeing it again means a copy is in circulation, so the
      // successor tokens go too.
      await _refreshTokenRepository.revokeFamily(record.familyId,
          revokedAt: now);
      return RefreshReuseDetected(record.familyId);
    }

    if (record.hasExpired(now)) return const RefreshRejected();

    if (await _users.findByUid(claims.uid) == null) {
      return const RefreshUserMissing();
    }

    final pair = await _issue(
      claims.uid,
      familyId: record.familyId,
      replaces: record.id,
    );
    return RefreshSucceeded(pair);
  }

  /// Revokes the session [presentedToken] belongs to.
  ///
  /// Silently does nothing for a token that is unknown, malformed or already
  /// revoked, so a caller cannot use logout to probe which tokens exist.
  Future<void> revoke(String presentedToken) async {
    final claims = _tokens.verifyRefreshToken(presentedToken);
    if (claims == null) return;

    final record = await _refreshTokenRepository.findById(claims.tokenId);
    if (record == null || record.userId != claims.uid) return;

    // The whole family, not just this token: logging out should not leave a
    // rotated successor usable.
    await _refreshTokenRepository.revokeFamily(record.familyId,
        revokedAt: _now());
  }

  /// Revokes every existing session for [uid] and starts a fresh one.
  ///
  /// Used after a password change or a password-reset confirmation: anyone
  /// else holding a refresh token for this account — a stolen device, a
  /// leaked token — is signed out, and the caller gets a working pair back
  /// so their own session isn't broken by the same sweep.
  Future<TokenPair> restartAllSessions(String uid) async {
    await _refreshTokens.revokeAllForUser(uid, revokedAt: _now());
    return start(uid);
  }

  Future<TokenPair> _issue(
    String uid, {
    required String familyId,
    String? replaces,
  }) async {
    final now = _now();
    final tokenId = _uuid.v4();
    final refreshTokenExpiresAt = now.add(_tokens.refreshTokenExpiresIn);

    await _refreshTokenRepository.issue(
      RefreshTokenRecord(
        id: tokenId,
        userId: uid,
        familyId: familyId,
        issuedAt: now,
        expiresAt: refreshTokenExpiresAt,
      ),
    );

    // Revoked after the successor is stored: if issuing fails, the caller
    // keeps a working token rather than being locked out.
    if (replaces != null) {
      await _refreshTokenRepository.revoke(
        replaces,
        revokedAt: now,
        replacedBy: tokenId,
      );
    }

    return TokenPair(
      accessToken: _tokens.generateAccessToken(uid),
      refreshToken: _tokens.generateRefreshToken(uid, tokenId: tokenId),
      accessTokenExpiresAt: now.add(_tokens.accessTokenExpiresIn),
      refreshTokenExpiresAt: refreshTokenExpiresAt,
    );
  }

  /// Revokes all reset tokens for the user with [uid].
  Future<void> revokeAllResetTokens(String uid) async {
    final now = _now();
    await _refreshTokenRepository.revokeAllRefreshTokensForUser(
      uid,
      revokedAt: now,
    );
  }
}
