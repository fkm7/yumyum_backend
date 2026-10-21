import 'dart:async';
import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:path/path.dart' as p;

import 'package:yumyum_backend/auth/authenticated_user.dart';
import 'package:yumyum_backend/auth/token_service.dart';
import 'package:yumyum_backend/repositories/user_repository.dart';

const _maxBytes = 5 * 1024 * 1024;
const _extByMime = {
  'image/jpeg': 'jpg',
  'image/png': 'png',
  'image/webp': 'webp',
};
const _mimeByExt = {
  '.jpg': 'image/jpeg',
  '.png': 'image/png',
  '.webp': 'image/webp',
};

final _avatarDir = p.join(
  Platform.environment['UPLOADS_DIR'] ?? 'uploads',
  'avatars',
);

Future<Response> onRequest(RequestContext context) async {
  final uid = bearerUid(context, context.read<TokenService>());
  if (uid == null) {
    return Response.json(
      statusCode: HttpStatus.unauthorized,
      body: {
        'error': 'Unauthorized',
      },
    );
  }

  final user = await context.read<UserRepository>().findByUid(uid);
  if (user == null) {
    return Response.json(
      statusCode: HttpStatus.notFound,
      body: {
        'error': 'User not found',
      },
    );
  }

  return switch (context.request.method) {
    HttpMethod.get => _get(context),
    HttpMethod.post || HttpMethod.put => _upload(context),
    _ => Future.value(Response(statusCode: HttpStatus.methodNotAllowed)),
  };
}

Future<Response> _get(RequestContext context) async {
  final user = context.read<AuthenticatedUser>(); // from your auth middleware
  final userRepository = context.read<UserRepository>();

  // Stored in DB as just the file name, e.g. "42-1760340000000.jpg"
  final fileName = await userRepository.getPhotoUri(uid: user.uid);
  if (fileName == null || fileName.isEmpty) {
    return Response.json(
      statusCode: HttpStatus.notFound,
      body: {
        'error': 'User has not uploaded photo',
      },
    );
  }

  final file = File(p.join(_avatarDir, p.basename(fileName)));
  final mime = _mimeByExt[p.extension(fileName).toLowerCase()];
  if (mime == null || !file.existsSync()) {
    return Response.json(
      statusCode: HttpStatus.notFound,
      body: {
        'error': "User's photo file has been lost.",
      },
    );
  }

  final lastModified = file.lastModifiedSync();
  return Response.stream(
    body: file.openRead(),
    headers: {
      HttpHeaders.contentTypeHeader: mime,
      HttpHeaders.cacheControlHeader: 'private, no-cache',
      HttpHeaders.etagHeader: '"${lastModified.millisecondsSinceEpoch}"',
    },
  );
}

Future<Response> _upload(RequestContext context) async {
  final user = context.read<AuthenticatedUser>();
  final userRepository = context.read<UserRepository>();

  final formData = await context.request.formData();

  final photo = formData.files['file'];

  if (photo == null) {
    return Response.json(
      statusCode: HttpStatus.badRequest,
      body: {
        'error': 'Field "file" is required',
      },
    );
  }
  if (!_mimeByExt.containsValue(photo.contentType.mimeType)) {
    return Response(statusCode: HttpStatus.badRequest);
  }

  final ext = _extByMime[photo.contentType.mimeType];
  if (ext == null) {
    return Response.json(
      statusCode: HttpStatus.unsupportedMediaType,
      body: {
        'error': 'Only jpeg, png, or webp allowed',
      },
    );
  }

  final bytes = await photo.readAsBytes();
  if (bytes.length > _maxBytes) {
    return Response.json(
      statusCode: HttpStatus.requestEntityTooLarge,
      body: {
        'error': 'Max size is 5 MB',
      },
    );
  }

  Directory(_avatarDir).createSync(recursive: true);
  final newName = '${user.uid}-${DateTime.now().millisecondsSinceEpoch}.$ext';
  await File(p.join(_avatarDir, newName)).writeAsBytes(bytes);

  // Remove the previous file so old photos don't pile up.
  final oldName = await userRepository.getPhotoUri(uid: user.uid);
  await userRepository.updatePhotoUri(uid: user.uid, photoUrl: newName);
  if (oldName != null) {
    final old = File(p.join(_avatarDir, p.basename(oldName)));
    if (old.existsSync()) await old.delete();
  }

  return Response.json(
    body: {
      'message': 'Photo updated',
    },
  );
}
