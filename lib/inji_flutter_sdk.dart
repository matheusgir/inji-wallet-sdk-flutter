/// Flutter SDK for MOSIP Inji.
///
/// Provides a comprehensive set of tools for verifiable credential
/// management, including issuance (VCI), presentation (OpenID4VP),
/// verification, secure key management, OAuth2 authentication,
/// backend integration, and credential storage.
library;

// VCI - Verifiable Credential Issuance
export 'src/vci/vci_client.dart';

// OpenID4VP - Verifiable Presentations
export 'src/openid4vp/openid4vp_client.dart';

// Credential Verification
export 'src/verifier/credential_verifier.dart';

// Secure Keystore
export 'src/keystore/secure_keystore.dart';

// OAuth2 / OIDC Authentication
export 'src/auth/oauth2_service.dart';
export 'src/auth/models/auth_config.dart';
export 'src/auth/models/auth_result.dart';

// Mimoto Backend Client
export 'src/backend/mimoto_client.dart';

// Credential Storage
export 'src/storage/credential_store.dart';
