<<<<<<<< HEAD:lib/features/catalog/domain/product_category_repository.dart
import 'package:yumyum_backend/features/catalog/domain/product_category.dart';
========
import 'package:yumyum_backend/features/catalog/domain/category.dart';
>>>>>>>> adf68415a1ab04b9a2c3ca1d923eb705057061eb:lib/features/catalog/domain/category_repository.dart

/// Read access to the `product_categories` table.
///
/// Deliberately an interface despite currently having a single method: it is
/// the seam route tests mock, and it will grow alongside the other
/// repositories.
// ignore: one_member_abstracts
abstract class CategoryRepository {
  /// Returns every category, ordered by id.
  Future<List<ProductCategory>> findAll();
}
