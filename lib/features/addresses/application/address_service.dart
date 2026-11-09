import 'package:yumyum_backend/features/addresses/domain/address.dart';
import 'package:yumyum_backend/features/addresses/domain/address_repository.dart';

/// A user's saved delivery addresses.
///
/// Every operation is scoped to `userId`: an address owned by someone else is
/// treated exactly like one that does not exist, so a caller cannot probe
/// for other users' address ids.
class AddressService {
  /// Constructs an [AddressService].
  const AddressService(this._addresses);

  final AddressRepository _addresses;

  /// Every address saved by [userId].
  Future<List<Address>> list(String userId) => _addresses.findByUser(userId);

  /// The address [id] if it belongs to [userId], otherwise null.
  Future<Address?> find(String userId, String id) async {
    final address = await _addresses.findById(id);
    if (address == null || address.userId != userId) return null;
    return address;
  }

  /// Saves a new address for [userId].
  Future<Address> create(
    String userId, {
    required String street,
    required String city,
    required String country,
    String type = 'other',
    String? label,
    double? latitude,
    double? longitude,
    bool isDefault = false,
  }) {
    return _addresses.create(
      userId: userId,
      type: type,
      label: label,
      street: street,
      city: city,
      country: country,
      latitude: latitude,
      longitude: longitude,
      isDefault: isDefault,
    );
  }

  /// Applies the non-null fields to address [id], or returns null when it
  /// does not belong to [userId].
  Future<Address?> update(
    String userId,
    String id, {
    String? type,
    String? label,
    String? street,
    String? city,
    String? country,
    double? latitude,
    double? longitude,
    bool? isDefault,
  }) async {
    if (await find(userId, id) == null) return null;
    return _addresses.update(
      id,
      type: type,
      label: label,
      street: street,
      city: city,
      country: country,
      latitude: latitude,
      longitude: longitude,
      isDefault: isDefault,
    );
  }

  /// Deletes address [id]; false when it does not belong to [userId].
  Future<bool> delete(String userId, String id) async {
    if (await find(userId, id) == null) return false;
    await _addresses.delete(id);
    return true;
  }
}
