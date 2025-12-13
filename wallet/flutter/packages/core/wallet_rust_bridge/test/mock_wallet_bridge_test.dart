import 'package:test/test.dart';
import 'package:wallet_domain/wallet_domain.dart';
import 'package:wallet_rust_bridge/src/mock/mock_wallet_bridge.dart';

void main() {
  test('MockWalletBridge.getReceiveAddress returns parsable Address', () async {
    final bridge = MockWalletBridge();

    final account = await bridge.createAccount(
      walletId: 'wallet_1',
      name: 'test',
      kind: AccountKind.bip32,
    );

    final addr = await bridge.getReceiveAddress(accountId: account.id);
    expect(addr.value, isNotEmpty);
    expect(addr.type, isA<AddressType>());
  });
}
