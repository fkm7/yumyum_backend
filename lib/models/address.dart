import 'package:yumyum_backend/models/order.dart' show Order;

/// A model class representing a user's saved delivery address.
class Address {
  /// Constructs an [Address] with the given properties.
  const Address({
    required this.id,
    required this.userId,
    required this.type,
    required this.street,
    required this.city,
    required this.country,
    required this.isDefault,
    this.label,
    this.latitude,
    this.longitude,
  });

  /// Builds an [Address] from a database column map.
  factory Address.fromRow(Map<String, dynamic> row) {
    return Address(
      id: row['id'] as String,
      userId: row['user_id'] as String,
      type: row['type'] as String,
      label: row['label'] as String?,
      street: row['street'] as String,
      city: row['city'] as String,
      country: row['country'] as String,
      latitude: (row['latitude'] as num?)?.toDouble(),
      longitude: (row['longitude'] as num?)?.toDouble(),
      isDefault: row['is_default'] as bool,
    );
  }

  /// Address identifier.
  final String id;

  /// Identifier of the user this address belongs to.
  ///
  /// Deliberately excluded from [toJson]: the address is always read in a
  /// context scoped to the authenticated user, matching [Order].
  final String userId;

  /// Free-form kind, e.g. "home", "work", "other".
  final String type;

  /// Optional user-facing label, e.g. "Mom's place".
  final String? label;

  /// Street line.
  final String street;

  /// City.
  final String city;

  /// Country.
  final String country;

  /// Latitude, if the address was pinned on a map.
  final double? latitude;

  /// Longitude, if the address was pinned on a map.
  final double? longitude;

  /// Whether this is the user's default address.
  ///
  /// At most one address per user has this set; the database enforces it
  /// with a partial unique index, and the repository clears the previous
  /// default in the same transaction that sets a new one.
  final bool isDefault;

  /// The JSON representation of this address.
  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'label': label,
        'street': street,
        'city': city,
        'country': country,
        'latitude': latitude,
        'longitude': longitude,
        'is_default': isDefault,
      };
}
