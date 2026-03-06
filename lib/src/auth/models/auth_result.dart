/// Represents the result of a successful OAuth2 token exchange.
///
/// Contains the access token and optionally a refresh token, ID token,
/// and expiration information returned by the token endpoint.
class AuthResult {
  /// The access token issued by the authorization server.
  final String accessToken;

  /// The refresh token, if issued. Can be used to obtain new access
  /// tokens without requiring the user to re-authenticate.
  final String? refreshToken;

  /// The OpenID Connect ID token, if requested and issued.
  /// Contains claims about the authentication event and the user.
  final String? idToken;

  /// The lifetime of the access token in seconds, if provided.
  final int? expiresIn;

  /// The c_nonce value from the token response, used for proof generation.
  final String? cNonce;

  /// Creates an [AuthResult] instance.
  const AuthResult({
    required this.accessToken,
    this.refreshToken,
    this.idToken,
    this.expiresIn,
    this.cNonce,
  });

  /// Creates an [AuthResult] from a JSON map (typically the token
  /// endpoint response).
  factory AuthResult.fromJson(Map<String, dynamic> json) {
    return AuthResult(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String?,
      idToken: json['id_token'] as String?,
      expiresIn: json['expires_in'] as int?,
      cNonce: json['c_nonce'] as String?,
    );
  }

  /// Converts this [AuthResult] to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'access_token': accessToken,
      if (refreshToken != null) 'refresh_token': refreshToken,
      if (idToken != null) 'id_token': idToken,
      if (expiresIn != null) 'expires_in': expiresIn,
      if (cNonce != null) 'c_nonce': cNonce,
    };
  }
}
