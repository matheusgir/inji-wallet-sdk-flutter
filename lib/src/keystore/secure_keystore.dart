import 'package:flutter/services.dart';

/// Client for secure key management operations.
///
/// Communicates with the native secure-keystore library via platform
/// channels to generate key pairs, sign data, and manage cryptographic keys
/// stored in the device's hardware-backed keystore.
class SecureKeystore {
  static const _channel = MethodChannel('io.mosip.inji/keystore');

  /// Generates a new key pair in the device keystore.
  ///
  /// Parameters:
  /// - [alias]: A unique identifier for the key pair.
  /// - [type]: The key type (e.g., 'EC', 'RSA').
  /// - [biometric]: Whether to require biometric authentication to use
  ///   the key (defaults to false).
  ///
  /// Returns the public key as a base64-encoded string.
  Future<String> generateKeyPair(
    String alias,
    String type, {
    bool biometric = false,
  }) async {
    final result = await _channel.invokeMethod<String>('generateKeyPair', {
      'alias': alias,
      'type': type,
      'biometric': biometric,
    });
    return result ?? '';
  }

  /// Signs data using a key stored in the device keystore.
  ///
  /// Parameters:
  /// - [alias]: The alias of the key to use for signing.
  /// - [data]: The raw bytes to sign.
  /// - [algorithm]: The signing algorithm (e.g., 'SHA256withECDSA').
  ///
  /// Returns the signature as raw bytes.
  Future<Uint8List> sign(
    String alias,
    Uint8List data,
    String algorithm,
  ) async {
    final result = await _channel.invokeMethod<Uint8List>('sign', {
      'alias': alias,
      'data': data,
      'algorithm': algorithm,
    });
    return result ?? Uint8List(0);
  }

  /// Checks whether a key with the given [alias] exists in the keystore.
  ///
  /// Returns true if the key exists, false otherwise.
  Future<bool> hasAlias(String alias) async {
    final result = await _channel.invokeMethod<bool>('hasAlias', {
      'alias': alias,
    });
    return result ?? false;
  }

  /// Deletes the key pair identified by [alias] from the keystore.
  ///
  /// Returns true if the key was successfully deleted, false otherwise.
  Future<bool> deleteKey(String alias) async {
    final result = await _channel.invokeMethod<bool>('deleteKey', {
      'alias': alias,
    });
    return result ?? false;
  }

  /// Retrieves the public key for the given [alias].
  ///
  /// Returns the public key as a base64-encoded string.
  Future<String> getPublicKey(String alias) async {
    final result = await _channel.invokeMethod<String>('getPublicKey', {
      'alias': alias,
    });
    return result ?? '';
  }
}
