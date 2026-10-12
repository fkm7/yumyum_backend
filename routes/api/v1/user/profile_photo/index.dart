import 'package:dart_frog/dart_frog.dart';

Future<Response> _getProfilePhoto(RequestContext context) async {
  final userId = context.request.uri.queryParameters['user_id'];
  if (userId == null) {
    return Response.json(
      statusCode: 400,
      body: {'error': 'Missing user_id parameter'},
    );
  }

  // Here you would typically fetch the profile photo from your database or storage
  // For demonstration purposes, we'll just return a placeholder response
  final profilePhotoUrl = 'https://example.com/profile_photos/$userId.jpg';

  return Response.json(body: {'profile_photo_url': profilePhotoUrl});
}

Future<Response> _updateProfilePhoto(RequestContext context) async {
  final userId = context.request.uri.queryParameters['user_id'];
  if (userId == null) {
    return Response.json(
      statusCode: 400,
      body: {'error': 'Missing user_id parameter'},
    );
  }

  // Here you would typically handle the file upload and update the profile photo
  // For demonstration purposes, we'll just return a placeholder response
  final newProfilePhotoUrl = 'https://example.com/profile_photos/$userId.jpg';

  return Response.json(body: {'profile_photo_url': newProfilePhotoUrl});
}

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method == HttpMethod.get) {
    return _getProfilePhoto(context);
  }
  if (context.request.method == HttpMethod.post) {
    return _updateProfilePhoto(context);
  }
  final userId = context.request.uri.queryParameters['user_id'];
  if (userId == null) {
    return Response.json(
      statusCode: 400,
      body: {'error': 'Missing user_id parameter'},
    );
  }

  // Here you would typically fetch the profile photo from your database or storage
  // For demonstration purposes, we'll just return a placeholder response
  final profilePhotoUrl = 'https://example.com/profile_photos/$userId.jpg';

  return Response.json(body: {'profile_photo_url': profilePhotoUrl});
}
