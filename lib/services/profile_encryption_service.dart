import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pointycastle/export.dart';

class ProfileEncryptionService {
  ProfileEncryptionService();

  static const _pepperEnvKey     = 'PROFILE_PEPPER';
  static const _pepperStorageKey = 'profile_encryption_pepper';
  static const _saltLen          = 16;
  static const _ivLen            = 12;
  static const _keyLen           = 32;
  static const _iterations       = 10000;

  final _secureStorage = const FlutterSecureStorage();
  final _rng           = Random.secure();

  final Map<String, Uint8List> _keyCache = {};

  Future<Map<String, String>> encrypt(String plainText) async {
    final pepper  = await _getPepper();
    final salt    = _randomBytes(_saltLen);
    final iv      = _randomBytes(_ivLen);
    final key     = _deriveKey(pepper, salt);

    final cipher = GCMBlockCipher(AESEngine())
      ..init(true, AEADParameters(KeyParameter(key), 128, iv, Uint8List(0)));

    final datablob = cipher.process(
        Uint8List.fromList(utf8.encode(plainText)));

    return {
      'salt':     base64.encode(salt),
      'iv':       base64.encode(iv),
      'datablob': base64.encode(datablob),
    };
  }

  Future<String> decrypt(Map<String, dynamic> blob) async {
    final saltB64  = blob['salt']     as String?;
    final ivB64    = blob['iv']       as String?;
    final dataB64  = blob['datablob'] as String?;

    if (saltB64 == null || ivB64 == null || dataB64 == null) {
      throw ArgumentError('Blob is missing required fields (salt/iv/datablob).');
    }

    final pepper   = await _getPepper();
    final salt     = base64.decode(saltB64);
    final iv       = base64.decode(ivB64);
    final datablob = base64.decode(dataB64);
    final key      = _keyCache[saltB64] ??
        (_keyCache[saltB64] =
            _deriveKey(pepper, Uint8List.fromList(salt)));

    final cipher = GCMBlockCipher(AESEngine())
      ..init(
        false,
        AEADParameters(
            KeyParameter(key), 128, Uint8List.fromList(iv), Uint8List(0)),
      );

    return utf8.decode(cipher.process(Uint8List.fromList(datablob)));
  }

  Future<Uint8List> _getPepper() async {
    try {
      final env = dotenv.env[_pepperEnvKey];
      if (env != null && env.length == 64) return _hexDecode(env);
    } catch (_) {}

    final stored = await _secureStorage.read(key: _pepperStorageKey);
    if (stored != null && stored.length == 64) return _hexDecode(stored);

    final fresh = _randomBytes(32);
    await _secureStorage.write(
        key: _pepperStorageKey, value: _hexEncode(fresh));
    return fresh;
  }

  Uint8List _deriveKey(Uint8List pepper, Uint8List salt) =>
      (PBKDF2KeyDerivator(HMac(SHA256Digest(), 64))
            ..init(Pbkdf2Parameters(salt, _iterations, _keyLen)))
          .process(pepper);

  Uint8List _randomBytes(int n) =>
      Uint8List.fromList(List.generate(n, (_) => _rng.nextInt(256)));

  static Uint8List _hexDecode(String hex) => Uint8List.fromList([
        for (var i = 0; i < hex.length; i += 2)
          int.parse(hex.substring(i, i + 2), radix: 16),
      ]);

  static String _hexEncode(Uint8List b) =>
      b.map((e) => e.toRadixString(16).padLeft(2, '0')).join();
}
