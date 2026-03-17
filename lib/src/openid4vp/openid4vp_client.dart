import 'package:flutter/services.dart';

/// Client for OpenID for Verifiable Presentations (OpenID4VP) operations.
///
/// Communicates with the native inji-openid4vp-aar library via platform
/// channels to authenticate verifiers, construct VP tokens, and share
/// presentations.
class OpenId4VpClient {
  static const _channel = MethodChannel('io.mosip.inji/openid4vp');

  /// Authenticates a verifier from an encoded authorization request.
  ///
  /// Parameters:
  /// - [encodedRequest]: The encoded OpenID4VP authorization request
  ///   (typically a URI or QR code payload).
  /// - [trustedVerifiers]: A list of trusted verifier configurations, each
  ///   containing at minimum a 'clientId' and 'redirectUri'.
  ///
  /// Returns a map containing the parsed and validated authorization request
  /// details, including the requested credentials and verifier information.
  Future<Map<String, dynamic>> authenticateVerifier(
    String encodedRequest,
    List<Map<String, dynamic>> trustedVerifiers,
  ) async {
    final result = await _channel.invokeMethod<Map>('authenticateVerifier', {
      'encodedRequest': encodedRequest,
      'trustedVerifiers': trustedVerifiers,
    });
    return Map<String, dynamic>.from(result ?? {});
  }

  /// Constructs an unsigned Verifiable Presentation (VP) token.
  ///
  /// Parameters:
  /// - [credentials]: A map of credential identifiers to credential data
  ///   that should be included in the VP token.
  /// - [holderId]: The DID or identifier of the credential holder.
  ///
  /// Returns a map containing the unsigned VP token and presentation
  /// submission descriptor.
  Future<Map<String, dynamic>> constructUnsignedVPToken(
    Map<String, dynamic> credentials,
    String holderId,
  ) async {
    final result =
        await _channel.invokeMethod<Map>('constructUnsignedVPToken', {
      'credentials': credentials,
      'holderId': holderId,
    });
    return Map<String, dynamic>.from(result ?? {});
  }

  /// Shares a signed VP token with the verifier.
  ///
  /// Parameters:
  /// - [signedVpToken]: The signed VP token string.
  /// - [presentationSubmission]: The presentation submission descriptor
  ///   mapping requested credentials to their location in the VP token.
  /// - [responseUri]: The verifier's response endpoint URI.
  ///
  /// Returns a map containing the sharing result, including any redirect
  /// URI or status from the verifier.
  Future<Map<String, dynamic>> sharePresentation(
    String signedVpToken,
    Map<String, dynamic> presentationSubmission,
    String responseUri,
  ) async {
    final result = await _channel.invokeMethod<Map>('sharePresentation', {
      'signedVpToken': signedVpToken,
      'presentationSubmission': presentationSubmission,
      'responseUri': responseUri,
    });
    return Map<String, dynamic>.from(result ?? {});
  }

  /// Sends an error response to the verifier when the VP flow fails or
  /// the user declines to share credentials.
  ///
  /// Parameters:
  /// - [errorCode]: The error code, e.g. 'ACCESS_DENIED',
  ///   'INVALID_TRANSACTION_DATA'.
  /// - [errorMessage]: A human-readable description of the error.
  /// - [source]: The source of the error (default: 'wallet').
  ///
  /// This is a fire-and-forget operation; errors during sending are silently
  /// ignored so the app can still navigate away cleanly.
  Future<void> sendErrorToVerifier(
    String errorCode,
    String errorMessage, {
    String source = 'wallet',
  }) async {
    try {
      await _channel.invokeMethod('sendErrorToVerifier', {
        'errorCode': errorCode,
        'errorMessage': errorMessage,
        'source': source,
      });
    } catch (_) {
      // Fire-and-forget: don't propagate errors from error reporting
    }
  }
}
