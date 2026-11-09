import 'package:yumyum_backend/features/catalog/domain/category.dart';

/// Read access to the `categories` table.
// ignore: one_member_abstracts
abstract class CategoryRepository {
  /// Returns every category, ordered by id.
  Future<List<Category>> findAll();
}
