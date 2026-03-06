import 'package:flutter/services.dart';

/// Client for Verifiable Credential Issuance (VCI) operations.
///
/// Communicates with the native inji-vci-client-aar library via
/// platform channels to fetch issuer metadata and request credentials.
class VciClient {
  static const _channel = MethodChannel('io.mosip.inji/vci');

  /// Retrieves the OpenID credential issuer metadata from the given [issuerUri].
  ///
  /// Returns a map containing the issuer's metadata including supported
  /// credential types, formats, and endpoints.
  Future<Map<String, dynamic>> getIssuerMetadata(String issuerUri) async {
    final result = await _channel.invokeMethod<Map>('getIssuerMetadata', {
      'issuerUri': issuerUri,
    });
    return Map<String, dynamic>.from(result ?? {});
  }

  /// Retrieves the supported credential configurations from the issuer.
  Future<Map<String, dynamic>> getCredentialConfigurations(
      String issuerUri) async {
    final result =
        await _channel.invokeMethod<Map>('getCredentialConfigurations', {
      'issuerUri': issuerUri,
    });
    return Map<String, dynamic>.from(result ?? {});
  }

  /// Requests a verifiable credential from the issuer.
  ///
  /// Parameters:
  /// - [credentialEndpoint]: The issuer's credential endpoint URL.
  /// - [accessToken]: A valid OAuth2 access token for authentication.
  /// - [format]: The desired credential format (e.g., 'ldp_vc', 'jwt_vc_json').
  /// - [proof]: The proof of possession (e.g., a signed JWT).
  /// - [credentialDefinition]: Optional credential definition specifying types
  ///   and other parameters.
  ///
  /// Returns a map containing the issued credential and related metadata.
  Future<Map<String, dynamic>> requestCredential({
    required String credentialEndpoint,
    required String accessToken,
    required String format,
    required String proof,
    Map<String, dynamic>? credentialDefinition,
    String? doctype,
    String? issuerId,
  }) async {
    final result = await _channel.invokeMethod<Map>('requestCredential', {
      'credentialEndpoint': credentialEndpoint,
      'accessToken': accessToken,
      'format': format,
      'proof': proof,
      if (credentialDefinition != null) // ignore: use_null_aware_elements
        'credentialDefinition': credentialDefinition,
      if (doctype != null) 'doctype': doctype, // ignore: use_null_aware_elements
      if (issuerId != null) 'issuerId': issuerId, // ignore: use_null_aware_elements
    });
    return Map<String, dynamic>.from(result ?? {});
  }
}
