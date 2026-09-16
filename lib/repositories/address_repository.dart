import 'package:delmer_backend/models/address.dart';

/// Read and write access to the `addresses` table.
abstract class AddressRepository {
  /// Returns the addresses saved by the given user, newest first.
  Future<List<Address>> findByUser(String userId);

  /// Returns the address with the given id, or null when absent.
  ///
  /// Ownership is not checked here; the caller compares [Address.userId],
  /// matching the pattern used by `OrderRepository.findById`.
  Future<Address?> findById(String id);

  /// Creates an address and returns it.
  ///
  /// When [isDefault] is true, any existing default address for [userId] is
  /// unset in the same transaction, so at most one default ever exists.
  Future<Address> create({
    required String userId,
    required String type,
    String? label,
    required String street,
    required String city,
    required String country,
    double? latitude,
    double? longitude,
    required bool isDefault,
  });

  /// Updates the address with the given id, applying only the non-null
  /// fields, and returns the updated address, or null when no such address
  /// exists.
  ///
  /// When [isDefault] is set to true, any other default address for the same
  /// user is unset in the same transaction.
  Future<Address?> update(
    String id, {
    String? type,
    String? label,
    String? street,
    String? city,
    String? country,
    double? latitude,
    double? longitude,
    bool? isDefault,
  });

  /// Deletes the address with the given id.
  ///
  /// A no-op when no such address exists.
  Future<void> delete(String id);
}
