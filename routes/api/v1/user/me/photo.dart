import 'dart:async';
import 'dart:io';

import 'package:dart_frog/dart_frog.dart';

import 'package:yumyum_backend/features/account/application/profile_service.dart';
import 'package:yumyum_backend/features/auth/presentation/authenticated_user.dart';

FutureOr<Response> onRequest(RequestContext context) async {
  return switch (context.request.method) {
    HttpMethod.get => await _get(context),
    HttpMethod.post || HttpMethod.put => await _upload(context),
    _ => Response(statusCode: HttpStatus.methodNotAllowed),
  };
}

Future<Response> _get(RequestContext context) async {
  final uid = context.read<AuthenticatedUser>().uid;
  final lookup = await context.read<ProfileService>().photo(uid);

  return switch (lookup) {
    PhotoFound(:final file, :final mimeType) => Response.stream(
        body: file.content(),
        headers: {
          HttpHeaders.contentTypeHeader: mimeType,
          HttpHeaders.cacheControlHeader: 'private, no-cache',
          HttpHeaders.etagHeader:
              '"${file.lastModified.millisecondsSinceEpoch}"',
        },
      ),
    NoPhoto() => Response.json(
        statusCode: HttpStatus.notFound,
        body: {'error': 'User has not uploaded photo'},
      ),
    PhotoMissing() => Response.json(
        statusCode: HttpStatus.notFound,
        body: {'error': "User's photo file has been lost."},
      ),
  };
}

Future<Response> _upload(RequestContext context) async {
  final formData = await context.request.formData();
  final photo = formData.files['file'];
  if (photo == null) {
    return Response.json(
      statusCode: HttpStatus.badRequest,
      body: {'error': 'Field "file" is required'},
    );
  }

  final uid = context.read<AuthenticatedUser>().uid;
  final result = await context.read<ProfileService>().uploadPhoto(
        uid,
        bytes: await photo.readAsBytes(),
        mimeType: photo.contentType.mimeType,
      );

  return switch (result) {
    PhotoUploaded() => Response.json(body: {'message': 'Photo updated'}),
    PhotoTypeNotAllowed() => Response.json(
        statusCode: HttpStatus.unsupportedMediaType,
        body: {'error': 'Only jpeg, png, or webp allowed'},
      ),
    PhotoTooLarge() => Response.json(
        statusCode: HttpStatus.requestEntityTooLarge,
        body: {'error': 'Max size is 5 MB'},
      ),
  };
}
