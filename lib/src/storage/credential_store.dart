import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Secure storage for verifiable credentials.
///
/// Uses [FlutterSecureStorage] to persist credentials in the platform's
/// secure enclave (Android Keystore / iOS Keychain). Each credential is
/// stored as a JSON-encoded string, and a separate index key tracks all
/// stored credential IDs for enumeration.
class CredentialStore {
  final FlutterSecureStorage _storage;

  /// Prefix applied to all credential storage keys to avoid collisions
  /// with other data stored in secure storage.
  static const _prefix = 'vc_';

  /// Key used to store the JSON-encoded list of credential IDs.
  static const _listKey = 'vc_ids';

  /// Creates a [CredentialStore] instance.
  ///
  /// An optional [storage] instance can be provided for testing.
  /// If not provided, a default [FlutterSecureStorage] is created.
  CredentialStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  /// Saves a credential to secure storage.
  ///
  /// Parameters:
  /// - [id]: A unique identifier for the credential (e.g., a UUID or hash).
  /// - [credential]: The credential data as a map, which will be
  ///   JSON-encoded before storage.
  ///
  /// If a credential with the same [id] already exists, it will be
  /// overwritten. The credential ID is also added to the ID index.
  Future<void> save(String id, Map<String, dynamic> credential) async {
    final key = '$_prefix$id';
    final jsonString = jsonEncode(credential);
    await _storage.write(key: key, value: jsonString);

    // Update the list of credential IDs
    final ids = await _getIds();
    if (!ids.contains(id)) {
      ids.add(id);
      await _saveIds(ids);
    }
  }

  /// Retrieves a credential by its [id].
  ///
  /// Returns the credential data as a map, or null if no credential
  /// with the given [id] exists.
  Future<Map<String, dynamic>?> get(String id) async {
    final key = '$_prefix$id';
    final jsonString = await _storage.read(key: key);
    if (jsonString == null) return null;
    return Map<String, dynamic>.from(jsonDecode(jsonString) as Map);
  }

  /// Retrieves all stored credentials.
  ///
  /// Returns a list of credential data maps. Credentials whose data
  /// cannot be read (e.g., corrupted storage) are silently skipped.
  Future<List<Map<String, dynamic>>> getAll() async {
    final ids = await _getIds();
    final results = <Map<String, dynamic>>[];

    for (final id in ids) {
      final credential = await get(id);
      if (credential != null) {
        results.add(credential);
      }
    }

    return results;
  }

  /// Deletes a credential by its [id].
  ///
  /// Removes both the credential data and its entry from the ID index.
  /// If no credential with the given [id] exists, this is a no-op.
  Future<void> delete(String id) async {
    final key = '$_prefix$id';
    await _storage.delete(key: key);

    final ids = await _getIds();
    ids.remove(id);
    await _saveIds(ids);
  }

  /// Reads the current list of credential IDs from secure storage.
  Future<List<String>> _getIds() async {
    final raw = await _storage.read(key: _listKey);
    if (raw == null || raw.isEmpty) return [];
    final decoded = jsonDecode(raw);
    if (decoded is List) {
      return decoded.cast<String>();
    }
    return [];
  }

  /// Persists the list of credential IDs to secure storage.
  Future<void> _saveIds(List<String> ids) async {
    await _storage.write(key: _listKey, value: jsonEncode(ids));
  }
}
