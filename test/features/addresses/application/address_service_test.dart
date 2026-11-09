import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';
import 'package:yumyum_backend/features/addresses/application/address_service.dart';
import 'package:yumyum_backend/features/addresses/domain/address_repository.dart';

import '../../../helpers/entities.dart';

class _MockAddressRepository extends Mock implements AddressRepository {}

void main() {
  late _MockAddressRepository repository;
  late AddressService service;

  setUp(() {
    repository = _MockAddressRepository();
    when(() => repository.findById('mine'))
        .thenAnswer((_) async => testAddress(id: 'mine'));
    when(() => repository.findById('theirs')).thenAnswer(
      (_) async => testAddress(id: 'theirs', userId: 'someone-else'),
    );
    when(() => repository.findById('missing')).thenAnswer((_) async => null);
    when(() => repository.delete(any())).thenAnswer((_) async {});
    when(() => repository.update(any(), city: any(named: 'city')))
        .thenAnswer((_) async => testAddress(id: 'mine'));
    service = AddressService(repository);
  });

  test('find returns only the caller’s own address', () async {
    expect(await service.find('user-1', 'mine'), isNotNull);
    expect(await service.find('user-1', 'theirs'), isNull);
    expect(await service.find('user-1', 'missing'), isNull);
  });

  test("never updates another user's address", () async {
    expect(await service.update('user-1', 'theirs', city: 'X'), isNull);
    verifyNever(() => repository.update(any(), city: any(named: 'city')));

    expect(await service.update('user-1', 'mine', city: 'X'), isNotNull);
  });

  test("never deletes another user's address", () async {
    expect(await service.delete('user-1', 'theirs'), isFalse);
    verifyNever(() => repository.delete(any()));

    expect(await service.delete('user-1', 'mine'), isTrue);
    verify(() => repository.delete('mine')).called(1);
  });
}
