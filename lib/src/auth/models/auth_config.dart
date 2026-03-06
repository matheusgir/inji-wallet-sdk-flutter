/// Configuration for OAuth2/OpenID Connect authentication.
///
/// Holds the endpoints and client parameters needed to perform
/// authorization code flow with PKCE.
class AuthConfig {
  /// The authorization endpoint URL where the user is redirected
  /// to authenticate and grant consent.
  final String authorizationEndpoint;

  /// The token endpoint URL used to exchange authorization codes
  /// for access tokens and to refresh tokens.
  final String tokenEndpoint;

  /// Optional user info endpoint URL for retrieving user profile data.
  final String? userInfoEndpoint;

  /// The OAuth2 client identifier registered with the authorization server.
  final String clientId;

  /// The redirect URI registered with the authorization server.
  /// The authorization server will redirect back to this URI after
  /// authentication.
  final String redirectUri;

  /// The list of OAuth2 scopes to request during authorization.
  final List<String> scopes;

  /// Optional HTTP Basic Authentication header value for the token
  /// endpoint. Used by some providers (e.g., Gov.br) that require
  /// client credentials via Basic Auth instead of client_id in the body.
  ///
  /// Format: `Basic <base64(clientId:clientSecret)>`
  final String? basicAuthHeader;

  /// Creates an [AuthConfig] instance.
  ///
  /// [authorizationEndpoint] and [tokenEndpoint] are required.
  /// [clientId] and [redirectUri] must be registered with the provider.
  /// [scopes] defaults to ['openid'] if not specified.
  const AuthConfig({
    required this.authorizationEndpoint,
    required this.tokenEndpoint,
    this.userInfoEndpoint,
    required this.clientId,
    required this.redirectUri,
    this.scopes = const ['openid'],
    this.basicAuthHeader,
  });
}
