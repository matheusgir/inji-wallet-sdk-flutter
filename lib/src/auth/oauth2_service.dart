import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';

import 'models/auth_config.dart';
import 'models/auth_result.dart';

/// OAuth2 service implementing Authorization Code Flow with PKCE.
///
/// Provides methods for the complete OAuth2 flow:
/// 1. Generate PKCE code verifier and challenge
/// 2. Build the authorization URL for user redirection
/// 3. Exchange the authorization code for tokens
/// 4. Refresh expired access tokens
/// 5. Fetch user info from the userinfo endpoint
///
/// Supports Basic Auth on the token endpoint for providers like Gov.br
/// that require client credentials via HTTP Basic Authentication.
class OAuth2Service {
  /// The OAuth2/OIDC configuration for this service instance.
  final AuthConfig config;

  final Dio _dio;

  /// Characters allowed in a PKCE code verifier per RFC 7636 section 4.1.
  /// Unreserved characters: [A-Z] [a-z] [0-9] - . _ ~
  static const _unreservedChars =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';

  /// Creates an [OAuth2Service] with the given [config].
  ///
  /// An optional [dio] instance can be provided for testing. If not
  /// provided, a default Dio instance is created.
  OAuth2Service(this.config, {Dio? dio}) : _dio = dio ?? Dio();

  /// Generates a cryptographically random PKCE code verifier.
  ///
  /// The verifier is a string of 128 unreserved characters as defined
  /// in RFC 7636 section 4.1. The minimum length per spec is 43 characters
  /// and maximum is 128.
  ///
  /// Returns a random string suitable for use as a PKCE code verifier.
  String generateCodeVerifier() {
    final random = Random.secure();
    const length = 128;
    return List.generate(
      length,
      (_) => _unreservedChars[random.nextInt(_unreservedChars.length)],
    ).join();
  }

  /// Generates a PKCE code challenge from the given [verifier].
  ///
  /// Uses the S256 method as defined in RFC 7636 section 4.2:
  /// code_challenge = BASE64URL(SHA256(code_verifier))
  ///
  /// The result is base64url-encoded without padding, as required by the spec.
  String generateCodeChallenge(String verifier) {
    final bytes = utf8.encode(verifier);
    final digest = sha256.convert(bytes);
    return base64Url.encode(digest.bytes).replaceAll('=', '');
  }

  /// Builds the authorization URL for redirecting the user to the
  /// authorization server.
  ///
  /// Parameters:
  /// - [codeChallenge]: The PKCE code challenge derived from the code verifier.
  /// - [state]: Optional opaque state parameter for CSRF protection.
  /// - [nonce]: Optional nonce for OpenID Connect replay protection.
  ///
  /// Returns a [Uri] that the user should be redirected to in order to
  /// authenticate and authorize the application.
  Uri buildAuthorizationUrl({
    required String codeChallenge,
    String? state,
    String? nonce,
  }) {
    final params = <String, String>{
      'response_type': 'code',
      'client_id': config.clientId,
      'redirect_uri': config.redirectUri,
      'scope': config.scopes.join(' '),
      'code_challenge': codeChallenge,
      'code_challenge_method': 'S256',
    };

    if (state != null) {
      params['state'] = state;
    }
    if (nonce != null) {
      params['nonce'] = nonce;
    }

    final base = Uri.parse(config.authorizationEndpoint);
    return base.replace(
      queryParameters: {
        ...base.queryParameters,
        ...params,
      },
    );
  }

  /// Exchanges an authorization code for tokens.
  ///
  /// Parameters:
  /// - [code]: The authorization code received from the authorization server
  ///   via the redirect URI.
  /// - [codeVerifier]: The PKCE code verifier that was used to generate the
  ///   code challenge sent in the authorization request.
  ///
  /// Returns an [AuthResult] containing the access token and optionally
  /// a refresh token, ID token, and expiration info.
  ///
  /// Throws a [DioException] if the token request fails.
  Future<AuthResult> exchangeCode(String code, String codeVerifier) async {
    final headers = <String, dynamic>{
      'Content-Type': 'application/x-www-form-urlencoded',
    };

    if (config.basicAuthHeader != null) {
      headers['Authorization'] = config.basicAuthHeader;
    }

    final response = await _dio.post(
      config.tokenEndpoint,
      data: {
        'grant_type': 'authorization_code',
        'code': code,
        'redirect_uri': config.redirectUri,
        'client_id': config.clientId,
        'code_verifier': codeVerifier,
      },
      options: Options(
        headers: headers,
        contentType: Headers.formUrlEncodedContentType,
      ),
    );

    return AuthResult.fromJson(Map<String, dynamic>.from(response.data));
  }

  /// Refreshes an expired access token using a refresh token.
  ///
  /// Parameters:
  /// - [refreshToken]: The refresh token obtained from a previous token
  ///   exchange or refresh.
  ///
  /// Returns a new [AuthResult] containing the fresh access token and
  /// potentially a new refresh token.
  ///
  /// Throws a [DioException] if the refresh request fails.
  Future<AuthResult> refreshToken(String refreshToken) async {
    final headers = <String, dynamic>{
      'Content-Type': 'application/x-www-form-urlencoded',
    };

    if (config.basicAuthHeader != null) {
      headers['Authorization'] = config.basicAuthHeader;
    }

    final response = await _dio.post(
      config.tokenEndpoint,
      data: {
        'grant_type': 'refresh_token',
        'refresh_token': refreshToken,
        'client_id': config.clientId,
      },
      options: Options(
        headers: headers,
        contentType: Headers.formUrlEncodedContentType,
      ),
    );

    return AuthResult.fromJson(Map<String, dynamic>.from(response.data));
  }

  /// Fetches the user's profile information from the userinfo endpoint.
  ///
  /// Parameters:
  /// - [accessToken]: A valid access token with the appropriate scopes
  ///   (typically 'openid profile').
  ///
  /// Returns a map of user claims as defined by the OpenID Connect
  /// specification (e.g., 'sub', 'name', 'email').
  ///
  /// Throws a [StateError] if no userinfo endpoint is configured.
  /// Throws a [DioException] if the request fails.
  Future<Map<String, dynamic>> getUserInfo(String accessToken) async {
    if (config.userInfoEndpoint == null) {
      throw StateError(
        'UserInfo endpoint is not configured in AuthConfig.',
      );
    }

    final response = await _dio.get(
      config.userInfoEndpoint!,
      options: Options(
        headers: {
          'Authorization': 'Bearer $accessToken',
        },
      ),
    );

    return Map<String, dynamic>.from(response.data);
  }
}
