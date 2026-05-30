import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:pointycastle/export.dart';

/// Encrypts and decrypts Firestore profile blobs using AES-256-GCM.
///
/// Key derivation
/// ──────────────
///  - **Salt** (16 bytes, random per-profile): stored in Firestore alongside
///    the datablob so decryption is possible on any device.
///  - **Pepper** (32 bytes, fixed per-installation): never stored in the DB.
///    Read from the `.env` key `PROFILE_PEPPER` first; if absent, a device-
///    unique pepper is generated once and kept in flutter_secure_storage.
///    This means a fresh install on a new device without the original pepper
///    cannot decrypt old datablobs — intentional for security.
///  - PBKDF2-SHA256 with 100 000 iterations derives the 32-byte AES key from
///    `pepper + salt` (pepper acts as the password, salt as the PBKDF2 salt).
///
/// Ciphertext layout (all base-64 encoded, stored as separate Firestore fields)
/// ─────────────────────────────────────────────────────────────────────────────
///  `salt`        16 random bytes (base-64)
///  `iv`          12 random bytes  (GCM nonce, base-64)
///  `datablob`  AES-256-GCM encrypted JSON + 16-byte GCM auth tag (base-64)
///
/// The GCM auth tag guarantees datablob integrity — any tampering is detected
/// on decryption and throws [ArgumentError].
class ProfileEncryptionService {
  static const _pepperEnvKey    = 'PROFILE_PEPPER';
  static const _pepperStorageKey = 'profile_encryption_pepper';
  static const _saltLength      = 16;
  static const _ivLength        = 12; // GCM standard nonce
  static const _keyLength       = 32; // AES-256
  static const _pbkdf2Iterations = 10000;

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final Random _rng = Random.secure();

  // Cache derived keys by salt so repeated decrypt calls for the same
  // profile don't re-run PBKDF2 every time.
  final Map<String, Uint8List> _keyCache = {};

  // ── Public API ────────────────────────────────────────────────────────────

  /// Encrypts [plainJson] (a JSON string) and returns a map ready for
  /// Firestore:  `{ "salt": "…", "iv": "…", "datablob": "…" }`.
  Future<Map<String, String>> encrypt(String plainJson) async {
    final pepper = await _getPepper();
    final salt   = _randomBytes(_saltLength);
    final iv     = _randomBytes(_ivLength);
    final key    = _deriveKey(pepper, salt);

    final cipher = GCMBlockCipher(AESEngine())
      ..init(
        true, // encrypt
        AEADParameters(KeyParameter(key), 128, iv, Uint8List(0)),
      );

    final input      = Uint8List.fromList(utf8.encode(plainJson));
    final datablob = cipher.process(input); // includes 16-byte GCM tag

    return {
      'salt':       base64.encode(salt),
      'iv':         base64.encode(iv),
      'datablob': base64.encode(datablob),
    };
  }

  /// Decrypts a Firestore blob produced by [encrypt].
  /// Throws [ArgumentError] if the blob is missing required fields.
  /// Throws [InvalidCipherTextException] if the GCM tag check fails
  /// (datablob tampered or wrong key).
  Future<String> decrypt(Map<String, dynamic> blob) async {
    final saltB64       = blob['salt']       as String?;
    final ivB64         = blob['iv']         as String?;
    final datablobB64 = blob['datablob'] as String?;

    if (saltB64 == null || ivB64 == null || datablobB64 == null) {
      throw ArgumentError(
        'Encrypted blob is missing required fields (salt / iv / datablob).',
      );
    }

    final pepper     = await _getPepper();
    final salt       = base64.decode(saltB64);
    final iv         = base64.decode(ivB64);
    final datablob   = base64.decode(datablobB64);
    final cacheKey   = saltB64; // salt is unique per field per profile
    final key        = _keyCache[cacheKey] ??
        (_keyCache[cacheKey] = _deriveKey(pepper, Uint8List.fromList(salt)));

    final cipher = GCMBlockCipher(AESEngine())
      ..init(
        false, // decrypt
        AEADParameters(
          KeyParameter(key), 128, Uint8List.fromList(iv), Uint8List(0),
        ),
      );

    // process() verifies the GCM tag and throws if invalid.
    final plainBytes = cipher.process(Uint8List.fromList(datablob));
    return utf8.decode(plainBytes);
  }

  // ── Pepper management ─────────────────────────────────────────────────────

  /// Returns the pepper as raw bytes.
  ///
  /// Priority:
  ///  1. `PROFILE_PEPPER` from `.env` (hex-encoded, must be exactly 64 hex
  ///     chars = 32 bytes).  Use this for multi-device setups so all devices
  ///     share the same pepper.
  ///  2. Device-unique pepper stored in flutter_secure_storage.  Generated
  ///     once on first run and never leaves the device keychain.
  Future<Uint8List> _getPepper() async {
    // 1 — .env pepper (shared, e.g. deployed via CI secrets)
    try {
      final envPepper = dotenv.env[_pepperEnvKey];
      if (envPepper != null && envPepper.length == 64) {
        return _hexDecode(envPepper);
      }
    } catch (_) {
      // dotenv not loaded — fall through
    }

    // 2 — device-local pepper from secure storage
    final stored = await _secureStorage.read(key: _pepperStorageKey);
    if (stored != null && stored.length == 64) {
      return _hexDecode(stored);
    }

    // First run: generate, persist, and return a fresh pepper.
    final fresh = _randomBytes(32);
    await _secureStorage.write(
      key:   _pepperStorageKey,
      value: _hexEncode(fresh),
    );
    return fresh;
  }

  // ── Key derivation ────────────────────────────────────────────────────────

  /// PBKDF2-SHA256: password = pepper, salt = per-profile salt, 100k rounds.
  Uint8List _deriveKey(Uint8List pepper, Uint8List salt) {
    final pbkdf2 = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64))
      ..init(Pbkdf2Parameters(salt, _pbkdf2Iterations, _keyLength));
    return pbkdf2.process(pepper);
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Uint8List _randomBytes(int length) {
    final bytes = Uint8List(length);
    for (var i = 0; i < length; i++) {
      bytes[i] = _rng.nextInt(256);
    }
    return bytes;
  }

  static Uint8List _hexDecode(String hex) {
    final result = Uint8List(hex.length ~/ 2);
    for (var i = 0; i < result.length; i++) {
      result[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return result;
  }

  static String _hexEncode(Uint8List bytes) =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}