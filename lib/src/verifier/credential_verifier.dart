import 'package:flutter/services.dart';

/// Client for verifiable credential and presentation verification.
///
/// Communicates with the native vcverifier-aar library via platform
/// channels to verify credentials, presentations, and check credential status.
class CredentialVerifier {
  static const _channel = MethodChannel('io.mosip.inji/verifier');

  /// Verifies a verifiable credential.
  ///
  /// Parameters:
  /// - [credential]: The credential string (JSON-LD or JWT depending on format).
  /// - [format]: The credential format (e.g., 'ldp_vc', 'jwt_vc_json').
  ///
  /// Returns a map containing the verification result, including:
  /// - 'isValid': Whether the credential is valid.
  /// - 'errors': Any validation errors encountered.
  Future<Map<String, dynamic>> verifyCredential(
    String credential,
    String format,
  ) async {
    final result = await _channel.invokeMethod<Map>('verifyCredential', {
      'credential': credential,
      'format': format,
    });
    return Map<String, dynamic>.from(result ?? {});
  }

  /// Verifies a Verifiable Presentation (VP) token.
  ///
  /// Parameters:
  /// - [vpToken]: The VP token string to verify.
  ///
  /// Returns a map containing the verification result, including:
  /// - 'isValid': Whether the presentation is valid.
  /// - 'credentials': The verified credentials within the presentation.
  /// - 'errors': Any validation errors encountered.
  Future<Map<String, dynamic>> verifyPresentation(String vpToken) async {
    final result = await _channel.invokeMethod<Map>('verifyPresentation', {
      'vpToken': vpToken,
    });
    return Map<String, dynamic>.from(result ?? {});
  }

  /// Checks the revocation/suspension status of a credential.
  ///
  /// Parameters:
  /// - [credential]: The credential string to check.
  /// - [format]: The credential format (e.g., 'ldp_vc', 'jwt_vc_json').
  ///
  /// Returns a map containing the status result, including:
  /// - 'status': The credential status (e.g., 'active', 'revoked', 'suspended').
  /// - 'details': Additional status details if available.
  Future<Map<String, dynamic>> getCredentialStatus(
    String credential,
    String format,
  ) async {
    final result = await _channel.invokeMethod<Map>('getCredentialStatus', {
      'credential': credential,
      'format': format,
    });
    return Map<String, dynamic>.from(result ?? {});
  }
}
