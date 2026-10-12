import 'package:yumyum_backend/models/category.dart';

/// Read access to the `categories` table.
///
/// Deliberately an interface despite currently having a single method: it is
/// the seam route tests mock, and it will grow alongside the other
/// repositories.
// ignore: one_member_abstracts
abstract class CategoryRepository {
  /// Returns every category, ordered by id.
  Future<List<Category>> findAll();
}
