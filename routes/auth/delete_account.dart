import 'package:dart_frog/dart_frog.dart';

import 'package:yumyum_backend/auth/authenticated_user.dart';
import 'package:yumyum_backend/auth/token_service.dart';
import 'package:yumyum_backend/repositories/user_repository.dart';
import 'package:yumyum_backend/services/account_deletion_service.dart';

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

  final account = await context.read<UserRepository>().findByUid(uid);
  if (account == null) {
    // Already gone (e.g. a retried request, or deleted via the web page in
    // another tab) — deletion is idempotent from the caller's perspective.
    return Response(statusCode: 204);
  }

  final result = await context
      .read<AccountDeletionService>()
      .deleteByUid(uid: uid, password: password);

  return switch (result) {
    AccountDeleted() => Response(statusCode: 204),
    AccountCredentialsRejected() => Response.json(
        statusCode: 401,
        body: {'error': 'Incorrect password'},
      ),
  };
}
