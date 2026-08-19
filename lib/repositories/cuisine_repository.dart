import 'package:delmer_backend/models/cuisine.dart';

/// Read access to the `cuisines` table.
// ignore: one_member_abstracts
abstract class CuisineRepository {
  /// Returns every cuisine, ordered by id.
  Future<List<Cuisine>> findAll();
}
