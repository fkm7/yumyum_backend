import 'package:dart_frog/dart_frog.dart';

import 'package:yumyum_backend/features/account/domain/user_repository.dart';
import 'package:yumyum_backend/features/auth/domain/token_service.dart';
import 'package:yumyum_backend/features/auth/presentation/authenticated_user.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.post) {
    return Response(statusCode: 405);
  }
  // This route cannot sit behind authMiddleware: it shares a directory with
  // /auth/login and /auth/register, which must stay public.
  final uid = bearerUid(context, context.read<TokenService>());
  if (uid == null) {
    return Response.json(statusCode: 401, body: {'error': 'Unauthorized'});
  }
  final userRepository = context.read<UserRepository>();
  final user = await userRepository.findByUid(uid);
  return Response(body: 'ok');
}
