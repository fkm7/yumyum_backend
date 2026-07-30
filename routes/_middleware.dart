import 'package:dart_frog/dart_frog.dart';
import 'package:delmer_backend/db/database_service.dart';

Handler middleware(Handler handler) {
  return handler
      .use(requestLogger())
      .use(provider<DatabaseService>((_) => DatabaseService.instance));
}
