import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

class User {
  final String id;
  final String email;
  final String name;
  final DateTime createdAt;

  User({
    required this.id,
    required this.email,
    required this.name,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'name': name,
        'createdAt': createdAt.toIso8601String(),
      };

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'] as String,
        email: json['email'] as String,
        name: json['name'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}

class UserHandler {
  Future<Response> getUser(Request request) async {
    try {
      final userId = request.url.pathSegments.last;
      return Response.ok(
        '{"id":"$userId","email":"user@example.com","name":"User Name","createdAt":"${DateTime.now().toIso8601String()}"}',
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: '{"error":"Failed to fetch user"}',
      );
    }
  }

  Future<Response> createUser(Request request) async {
    try {
      final body = await request.readAsString();
      return Response.ok(
        '{"id":"new-id","email":"newuser@example.com","name":"New User","createdAt":"${DateTime.now().toIso8601String()}"}',
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.badRequest(
        body: '{"error":"Invalid request body"}',
      );
    }
  }

  Future<Response> updateUser(Request request) async {
    try {
      final userId = request.url.pathSegments.last;
      final body = await request.readAsString();
      return Response.ok(
        '{"id":"$userId","email":"updated@example.com","name":"Updated User","createdAt":"${DateTime.now().toIso8601String()}"}',
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.badRequest(
        body: '{"error":"Failed to update user"}',
      );
    }
  }

  Future<Response> deleteUser(Request request) async {
    try {
      final userId = request.url.pathSegments.last;
      return Response.ok(
        '{"message":"User deleted successfully","userId":"$userId"}',
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: '{"error":"Failed to delete user"}',
      );
    }
  }
}

Router createUserRouter() {
  final router = Router();
  final userHandler = UserHandler();

  router.get('/<userId>', userHandler.getUser);
  router.post('/', userHandler.createUser);
  router.put('/<userId>', userHandler.updateUser);
  router.delete('/<userId>', userHandler.deleteUser);

  return router;
}
