import 'package:send_domain/send_domain.dart';
import 'package:test/test.dart';

// Helpers to generate Kaspa-style payload strings (40-bit checksum, 8 chars)
// matching Rust `crypto/addresses/src/bech32.rs`. These are used only in tests.
const _charset = 'qpzry9x8gf2tvdw0s3jn54khce6mua7l';

List<int> _prefixToU5(String prefix) =>
    prefix.codeUnits.map((c) => c & 0x1f).toList(growable: false);

BigInt _polymodKaspa(List<int> values) {
  final polyMask = BigInt.parse('0x07ffffffff');
  final gen0 = BigInt.parse('0x98f2bc8e61');
  final gen1 = BigInt.parse('0x79b76d99e2');
  final gen2 = BigInt.parse('0xf33e5fb3c4');
  final gen3 = BigInt.parse('0xae2eabe2a8');
  final gen4 = BigInt.parse('0x1e4f43e470');

  var c = BigInt.one;
  for (final d in values) {
    final c0 = c >> 35;
    c = ((c & polyMask) << 5) ^ BigInt.from(d);
    if ((c0 & BigInt.one) != BigInt.zero) c ^= gen0;
    if ((c0 & BigInt.from(2)) != BigInt.zero) c ^= gen1;
    if ((c0 & BigInt.from(4)) != BigInt.zero) c ^= gen2;
    if ((c0 & BigInt.from(8)) != BigInt.zero) c ^= gen3;
    if ((c0 & BigInt.from(16)) != BigInt.zero) c ^= gen4;
  }
  return c ^ BigInt.one;
}

List<int> _convert8to5(List<int> payload) {
  final padding = payload.length % 5 == 0 ? 0 : 1;
  final outLen = (payload.length * 8) ~/ 5 + padding;
  final out = List<int>.filled(outLen, 0);

  var currentIdx = 0;
  var buff = 0;
  var bits = 0;
  for (final c in payload) {
    buff = (buff << 8) | (c & 0xff);
    bits += 8;
    while (bits >= 5) {
      bits -= 5;
      out[currentIdx] = (buff >> bits) & 0x1f;
      buff &= (1 << bits) - 1;
      currentIdx += 1;
    }
  }
  if (bits > 0 && currentIdx < out.length) {
    out[currentIdx] = (buff << (5 - bits)) & 0x1f;
  }
  return out;
}

List<int> _checksumU5(String prefix, List<int> payloadU5) {
  const checksumLen = 8;
  final values = <int>[
    ..._prefixToU5(prefix),
    0,
    ...payloadU5,
    ...List<int>.filled(checksumLen, 0),
  ];
  final check = _polymodKaspa(values);
  var tmp = check;
  final checksumBytes = List<int>.filled(5, 0);
  for (var i = 4; i >= 0; i--) {
    checksumBytes[i] = (tmp & BigInt.from(0xff)).toInt();
    tmp >>= 8;
  }
  return _convert8to5(checksumBytes);
}

String _encodeAddress(String prefix, int version, List<int> payloadBytes) {
  final bytes = <int>[version, ...payloadBytes];
  final payloadU5 = _convert8to5(bytes);
  final checksumU5 = _checksumU5(prefix, payloadU5);
  final all = <int>[...payloadU5, ...checksumU5];
  final payload = String.fromCharCodes(all.map((v) => _charset.codeUnitAt(v)));
  return '$prefix:$payload';
}

void main() {
  test('accepts stealth prefixes (qs:, qstest:) with valid checksum and version', () {
    final validate = ValidateAddressUseCase();

    final qs = _encodeAddress('qs', 16, List<int>.filled(64, 7));
    final qstest = _encodeAddress('qstest', 16, List<int>.filled(64, 9));

    expect(validate(qs), isTrue);
    expect(validate(qstest), isTrue);
  });

  test('rejects stealth prefix with non-stealth version', () {
    final validate = ValidateAddressUseCase();

    final bad = _encodeAddress('qs', 0, List<int>.filled(32, 0));
    expect(validate(bad), isFalse);
  });

  test('accepts valid MLDSA addresses', () {
    final validate = ValidateAddressUseCase();

    final mldsa = _encodeAddress('kaspa', 2, List<int>.filled(1312, 0));
    expect(validate(mldsa), isTrue);
  });
}
