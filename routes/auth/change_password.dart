import 'package:dart_frog/dart_frog.dart';
import 'package:yumyum_backend/auth/authenticated_user.dart';
import 'package:yumyum_backend/auth/password_hasher.dart';
import 'package:yumyum_backend/auth/token_service.dart';
import 'package:yumyum_backend/repositories/user_repository.dart';

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
  final authenticatedUser = context.read<AuthenticatedUser>();
  final user = await userRepository.findByUid(authenticatedUser.uid);
  if (user == null) {
    return Response.json(statusCode: 404, body: {'error': 'User not found'});
  }
  final body = await context.request.json() as Map<String, dynamic>;
  final currentPassword = body['current_password'] as String?;
  final newPassword = body['new_password'] as String?;
  if (currentPassword == null || newPassword == null) {
    return Response.json(
      statusCode: 400,
      body: {'error': 'Missing current_password or new_password'},
    );
  }
  final isCurrentPasswordValid = context.read<PasswordHasher>().verify(
        currentPassword,
        user.passwordHash ?? '',
      );
  if (!isCurrentPasswordValid) {
    return Response.json(
      statusCode: 400,
      body: {'error': 'Current password is incorrect'},
    );
  }
  await userRepository.updatePasswordHash(
    user.uid,
    context.read<PasswordHasher>().hash(newPassword),
  );
  return Response(body: '{"message": "Password changed successfully"}');
}
