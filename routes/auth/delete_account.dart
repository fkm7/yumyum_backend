import 'package:dart_frog/dart_frog.dart';

import 'package:yumyum_backend/auth/authenticated_user.dart';
import 'package:yumyum_backend/auth/password_hasher.dart';
import 'package:yumyum_backend/auth/token_service.dart';
import 'package:yumyum_backend/repositories/user_repository.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.delete) {
    return Response(statusCode: 405);
  }
  // This route cannot sit behind authMiddleware: it shares a directory with
  // /auth/login and /auth/register, which must stay public.
  final uid = bearerUid(context, context.read<TokenService>());
  if (uid == null) {
    return Response.json(statusCode: 401, body: {'error': 'Unauthorized'});
  }

  final Map<String, dynamic> body;
  try {
    body = await context.request.json() as Map<String, dynamic>;
  } catch (_) {
    return Response.json(statusCode: 400, body: {'error': 'Invalid JSON'});
  }

  final password = body['password'];
  if (password is! String || password.isEmpty) {
    return Response.json(
      statusCode: 422,
      body: {'error': 'password is required to confirm account deletion'},
    );
  }

  final userRepository = context.read<UserRepository>();
  final authenticatedUser = context.read<AuthenticatedUser>();
  final hasher = context.read<PasswordHasher>();

  final account = await userRepository.findByUid(authenticatedUser.uid);
  if (account == null) {
    // Already gone (e.g. a retried request, or deleted via the web page in
    // another tab) — deletion is idempotent from the caller's perspective.
    return Response(statusCode: 204);
  }

  // findByUid deliberately omits the password hash (see UserRepository docs),
  // so it's fetched again via email, matching the pattern login.dart uses.
  final withHash = await userRepository.findByEmail(account.email);
  final storedHash = withHash?.passwordHash;
  if (storedHash == null || !hasher.verify(password, storedHash)) {
    return Response.json(
      statusCode: 401,
      body: {'error': 'Incorrect password'},
    );
  }

  await userRepository.delete(authenticatedUser.uid);

  return Response(statusCode: 204);
}
