import 'package:yumyum_backend/features/addresses/domain/address.dart';
import 'package:yumyum_backend/features/catalog/domain/product_category.dart';
import 'package:yumyum_backend/features/catalog/domain/cuisine.dart';
import 'package:yumyum_backend/features/catalog/domain/product.dart';
import 'package:yumyum_backend/features/catalog/domain/restaurant.dart';
import 'package:yumyum_backend/features/catalog/domain/restaurant_category.dart';
import 'package:yumyum_backend/features/payments/domain/payment_method.dart';

/// Minimal valid entities for use-case tests. Only the fields a test cares
/// about are parameters; everything else is a fixed, plausible value.

const _category = ProductCategory(
  id: 1,
  titleEn: 'Burgers',
  titleRu: 'Бургеры',
  titleUz: 'Burgerlar',
  icon: null,
);

/// A [Restaurant] with the given [id] and opening state.
Restaurant testRestaurant({int id = 1, bool isOpen = true}) => Restaurant(
      id: id,
      name: 'Burger House',
      isOpen: isOpen,
      rating: 4.5,
      logo: null,
      address: const {'city': 'Tashkent'},
      image: null,
      cuisine: const Cuisine(
        id: 1,
        titleEn: 'American',
        titleRu: 'Американская',
        titleUz: 'Amerika oshxonasi',
        icon: null,
      ),
      category: const RestaurantCategory(
        id: 1,
        titleEn: 'Burgers',
        titleRu: 'Бургеры',
        titleUz: 'Burgerlar',
        icon: null,
      ),
      startTime: '09:00',
      endTime: '23:00',
      description: null,
      phoneNumber: null,
      deliveryCost: 5000,
      minDeliveryTime: 20,
      maxDeliveryTime: 40,
      freeDeliveryFrom: 50000,
      productCategories: const [_category],
    );

/// An available [Product] with the given [id], sold by [restaurantId].
Product testProduct({int id = 1, int restaurantId = 1}) => Product(
      id: id,
      restaurantId: restaurantId,
      category: _category,
      price: 10000,
      status: 'available',
      titleEn: 'Product $id',
      titleRu: null,
      titleUz: null,
      image: null,
      description: null,
      unit: null,
    );

/// An [Address] with the given [id], owned by [userId].
Address testAddress({String id = 'address-1', String userId = 'user-1'}) =>
    Address(
      id: id,
      userId: userId,
      type: 'home',
      street: '1 Test Way',
      city: 'Tashkent',
      country: 'Uzbekistan',
      isDefault: true,
    );

/// A [PaymentMethod] with the given [id], owned by [userId].
PaymentMethod testPaymentMethod({
  String id = 'card-1',
  String userId = 'user-1',
}) =>
    PaymentMethod(
      id: id,
      userId: userId,
      type: 'card',
      isDefault: true,
      brand: 'visa',
      last4: '4242',
    );
