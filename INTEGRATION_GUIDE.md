# Inji Flutter SDK — Integration Guide

Complete guide to integrate the Inji Flutter SDK into your Flutter app for digital credential management.

---

## Table of Contents

1. [Installation](#1-installation)
2. [Project Setup](#2-project-setup)
3. [Architecture Overview](#3-architecture-overview)
4. [Module Reference](#4-module-reference)
   - [4.1 OAuth2 Authentication](#41-oauth2-authentication)
   - [4.2 Mimoto Backend Client](#42-mimoto-backend-client)
   - [4.3 Secure Keystore](#43-secure-keystore)
   - [4.4 VCI Client (Credential Issuance)](#44-vci-client-credential-issuance)
   - [4.5 Credential Storage](#45-credential-storage)
   - [4.6 OpenID4VP Client (Credential Sharing)](#46-openid4vp-client-credential-sharing)
   - [4.7 Credential Verifier](#47-credential-verifier)
5. [Complete Issuance Flow](#5-complete-issuance-flow)
6. [JWT Proof of Possession](#6-jwt-proof-of-possession)
7. [State Management (Riverpod)](#7-state-management-riverpod)
8. [Configuration Reference](#8-configuration-reference)
9. [Android Configuration](#9-android-configuration)
10. [Troubleshooting](#10-troubleshooting)

---

## 1. Installation

### From GitHub (recommended)

```yaml
# pubspec.yaml
dependencies:
  inji_flutter_sdk:
    git:
      url: https://github.com/injibr/inji-wallet-sdk-flutter.git
```

### From local path

```yaml
dependencies:
  inji_flutter_sdk:
    path: ./inji_flutter_sdk
```

Then run:

```bash
flutter pub get
```

### Required additional dependencies

Your app will also need these packages:

```yaml
dependencies:
  flutter_riverpod: ^2.6.0      # State management (recommended)
  go_router: ^14.0.0             # Navigation
  flutter_secure_storage: ^9.2.0 # PKCE verifier persistence
  dio: ^5.4.0                    # HTTP client (used by SDK internally)
  webview_flutter: ^4.13.1       # In-app OAuth browser
  mobile_scanner: ^5.0.0         # QR code scanning (for OpenID4VP)
```

---

## 2. Project Setup

### Minimum Requirements

| Requirement | Version |
|------------|---------|
| Flutter    | >= 3.3.0 |
| Dart SDK   | ^3.10.4 |
| Android minSdk | 23 |
| Android compileSdk | 34 |
| Java | 17 |

### Import

```dart
import 'package:inji_flutter_sdk/inji_flutter_sdk.dart';
```

This single import gives you access to all SDK classes:
- `VciClient`
- `OpenId4VpClient`
- `CredentialVerifier`
- `SecureKeystore`
- `OAuth2Service`, `AuthConfig`, `AuthResult`
- `MimotoClient`
- `CredentialStore`

---

## 3. Architecture Overview

```
┌──────────────────────────────────────────────────┐
│                  Your Flutter App                  │
├──────────────────────────────────────────────────┤
│              inji_flutter_sdk (Dart API)           │
│  ┌──────────┐ ┌──────────┐ ┌────────────────────┐ │
│  │OAuth2    │ │Mimoto    │ │CredentialStore     │ │
│  │Service   │ │Client    │ │(flutter_secure_    │ │
│  │(Pure Dart│ │(Pure Dart│ │ storage)           │ │
│  │+ PKCE)   │ │+ Dio)    │ │                    │ │
│  └──────────┘ └──────────┘ └────────────────────┘ │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐┌────────┐ │
│  │VciClient │ │OpenId4Vp │ │Credential││Secure  │ │
│  │          │ │Client    │ │Verifier  ││Keystore│ │
│  └────┬─────┘ └────┬─────┘ └────┬─────┘└───┬────┘ │
│       │MethodChannel│           │           │      │
├───────┴─────────────┴───────────┴───────────┴──────┤
│            Android Native (Pre-compiled AAR)        │
│  ┌──────────────┐ ┌──────────────┐ ┌─────────────┐ │
│  │inji-vci-     │ │inji-openid4  │ │vcverifier-  │ │
│  │client-aar    │ │vp-aar        │ │aar          │ │
│  │(0.6.0)       │ │(0.6.0)       │ │(1.7.0)      │ │
│  └──────────────┘ └──────────────┘ └─────────────┘ │
│            Android KeyStore API (RSA/EC)            │
└──────────────────────────────────────────────────┘
```

**4 MethodChannels** connect Dart to native Android:

| Channel | Purpose |
|---------|---------|
| `io.mosip.inji/vci` | Credential issuance |
| `io.mosip.inji/openid4vp` | Verifiable presentations |
| `io.mosip.inji/verifier` | Credential verification |
| `io.mosip.inji/keystore` | Key management & signing |

**3 Pure Dart modules** (no native code):

| Module | Purpose |
|--------|---------|
| `OAuth2Service` | OAuth2 + PKCE authentication |
| `MimotoClient` | Mimoto BFF API integration |
| `CredentialStore` | Secure local storage |

---

## 4. Module Reference

### 4.1 OAuth2 Authentication

Handles OAuth2 Authorization Code Flow with PKCE (S256).

#### Configuration

```dart
final authConfig = AuthConfig(
  authorizationEndpoint: 'https://sso.staging.acesso.gov.br/authorize',
  tokenEndpoint: 'https://your-mimoto-url/v1/mimoto/get-token/ISSUER_ID',
  userInfoEndpoint: 'https://sso.staging.acesso.gov.br/userinfo',
  clientId: 'your-client-id',
  redirectUri: 'https://your-domain/redirect',
  scopes: ['openid', 'email', 'profile'],
  basicAuthHeader: 'Basic base64(clientId:clientSecret)', // optional
);

final oauth2 = OAuth2Service(authConfig);
```

#### PKCE Flow

```dart
// Step 1: Generate PKCE codes
final codeVerifier = oauth2.generateCodeVerifier();
final codeChallenge = oauth2.generateCodeChallenge(codeVerifier);

// Step 2: Build authorization URL (open in WebView)
final authUrl = oauth2.buildAuthorizationUrl(codeChallenge: codeChallenge);
// authUrl => https://sso.../authorize?response_type=code&client_id=...
//            &redirect_uri=...&scope=...&code_challenge=...
//            &code_challenge_method=S256&state=...&nonce=...

// Step 3: After user authenticates, exchange code for tokens
final result = await oauth2.exchangeCode(authCode, codeVerifier);
// result.accessToken  -> Bearer token for API calls
// result.refreshToken -> For token refresh
// result.idToken      -> OIDC identity token
// result.expiresIn    -> Token lifetime in seconds
// result.cNonce       -> Server nonce for proof generation

// Step 4: Refresh token when expired
final newResult = await oauth2.refreshToken(result.refreshToken!);

// Step 5: Get user info (optional)
final userInfo = await oauth2.getUserInfo(result.accessToken!);
```

#### AuthResult Model

```dart
class AuthResult {
  final String accessToken;
  final String? refreshToken;
  final String? idToken;
  final int? expiresIn;
  final String? cNonce;     // Critical for JWT proof generation
}
```

> **Important**: The `cNonce` returned from token exchange is required for generating JWT proofs. Always store it.

> **Important**: Persist the `codeVerifier` to `FlutterSecureStorage` before opening the WebView. The app may restart during browser auth, losing the in-memory value.

---

### 4.2 Mimoto Backend Client

Communicates with the MOSIP Mimoto BFF (Backend-for-Frontend).

```dart
final mimoto = MimotoClient(baseUrl: 'https://injiweb.credenciaisverificaveis-hml.dataprev.gov.br');
```

#### List Issuers

```dart
final issuers = await mimoto.getIssuers();
// Returns List<Map<String, dynamic>>
// Each issuer has: credential_issuer, display (name, logo), protocol, etc.

for (final issuer in issuers) {
  print(issuer['credential_issuer']); // e.g., "INCRA"
  final display = (issuer['display'] as List?)?.first;
  print(display?['name']); // e.g., "INCRA - Instituto Nacional..."
}
```

#### Get Issuer Configuration

```dart
final config = await mimoto.getIssuerConfiguration('INCRA');
// Returns Map<String, dynamic> with:
// - wellknown_endpoint: URL to fetch OpenID credential issuer metadata
// - token_endpoint: Mimoto proxy token endpoint
// - authorization_endpoint, redirect_uri, client_id, etc.
```

#### Fetch Well-Known Metadata

```dart
// The well-known URL from issuer config — note the ?issuer_id= query param
final wellKnownUrl = '${config['wellknown_endpoint']}';
// e.g., https://injicertify.../.../.well-known/openid-credential-issuer?issuer_id=INCRA

final metadata = await mimoto.getWellKnownMetadata(wellKnownUrl);
// Returns Map<String, dynamic> with:
// - credential_issuer: issuer URL (used as JWT 'aud')
// - credential_endpoint: where to POST credential requests
// - credential_configurations_supported: available credential types
```

#### Response Format

Mimoto wraps responses in `{"response": {...}, "errors": []}`. The SDK automatically unwraps this — you receive the inner `response` object directly.

---

### 4.3 Secure Keystore

Manages cryptographic keys using the Android KeyStore API.

```dart
final keystore = SecureKeystore();
```

#### Generate Key Pair

```dart
// RSA (recommended for MOSIP Certify — supports RS256/PS256)
await keystore.generateKeyPair(alias: 'my_rsa_key', algorithm: 'RSA');

// EC (P-256, uses ES256)
await keystore.generateKeyPair(alias: 'my_ec_key', algorithm: 'EC');
```

#### Sign Data

```dart
final signature = await keystore.sign(
  alias: 'my_rsa_key',
  data: 'base64url-encoded-data-to-sign',
);
// Returns base64-encoded signature
```

#### Get Public Key

```dart
final publicKeyBase64 = await keystore.getPublicKey(alias: 'my_rsa_key');
// Returns base64-encoded X.509 SubjectPublicKeyInfo
// Parse this to extract RSA (n, e) or EC (x, y) components for JWK
```

#### Check / Delete Keys

```dart
final exists = await keystore.hasAlias(alias: 'my_rsa_key'); // true/false
await keystore.deleteKey(alias: 'my_rsa_key');
```

> **Note**: Key generation includes `SIGNATURE_PADDING_RSA_PKCS1` for RSA keys. Use key alias suffix `_v2` if you encounter "Incompatible padding mode" errors with older keys.

---

### 4.4 VCI Client (Credential Issuance)

Issues verifiable credentials via OpenID4VCI Draft 13.

```dart
final vciClient = VciClient();
```

#### Get Issuer Metadata

```dart
final metadata = await vciClient.getIssuerMetadata(
  wellKnownUrl: 'https://certify-server/.well-known/openid-credential-issuer?issuer_id=INCRA',
);
```

#### Request Credential

```dart
final result = await vciClient.requestCredential(
  credentialEndpoint: 'https://certify-server/credential',
  accessToken: authResult.accessToken,
  format: 'ldp_vc',                    // or 'jwt_vc_json'
  proof: jwtProofString,               // JWT proof of possession (see Section 6)
  credentialDefinition: {
    'type': ['VerifiableCredential', 'CCIRCredential'],
    'credentialSubject': null,
    '@context': ['https://www.w3.org/2018/credentials/v1'],
  },
  doctype: 'CCIRCredential',           // Optional, required by MOSIP Certify
  issuerId: 'INCRA',                   // Optional, required for multi-tenant Certify
  claims: null,                         // Optional
);
// result => Map<String, dynamic> containing the issued credential
```

#### Required Request Body Fields (MOSIP Certify)

MOSIP Certify requires this exact structure:

```json
{
  "format": "ldp_vc",
  "credential_definition": {
    "type": ["VerifiableCredential", "CCIRCredential"],
    "credentialSubject": null,
    "@context": ["https://www.w3.org/2018/credentials/v1"]
  },
  "proof": {
    "proof_type": "jwt",
    "jwt": "eyJ...",
    "cwt": null
  },
  "doctype": "CCIRCredential",
  "claims": null,
  "issuerId": "INCRA"
}
```

---

### 4.5 Credential Storage

Stores credentials securely using `flutter_secure_storage`.

```dart
final store = CredentialStore();
```

#### Save Credential

```dart
await store.save('credential-unique-id', {
  'type': 'CCIRCredential',
  'issuer': 'INCRA',
  'credentialSubject': { ... },
  // ... full credential data
});
```

#### Retrieve Credentials

```dart
// Get single credential
final cred = await store.get('credential-unique-id');

// Get all stored credentials
final all = await store.getAll();
for (final item in all) {
  print(item['type']);
}
```

#### Delete Credential

```dart
await store.delete('credential-unique-id');
```

> **Tip**: When saving, add metadata fields with `_meta_` prefix for easy UI rendering:
> ```dart
> final enriched = {
>   ...credentialData,
>   '_meta_id': 'unique-id',
>   '_meta_issuer': 'INCRA',
>   '_meta_type': 'CCIRCredential',
>   '_meta_issuedAt': DateTime.now().toIso8601String(),
> };
> await store.save('unique-id', enriched);
> ```

---

### 4.6 OpenID4VP Client (Credential Sharing)

Handles verifiable presentation sharing via OpenID4VP.

```dart
final vpClient = OpenId4VpClient();
```

#### Authenticate Verifier Request

```dart
// After scanning QR code, parse the authorization request
final authRequest = await vpClient.authenticateVerifier(
  encodedAuthRequest: qrCodeContent,
);
// Returns Map with: client_id, redirect_uri, presentation_definition, etc.
```

#### Construct VP Token

```dart
final vpToken = await vpClient.constructUnsignedVPToken(
  credentialsJson: jsonEncode([storedCredential]),
  presentationDefinition: jsonEncode(authRequest['presentation_definition']),
);
```

#### Share Presentation

```dart
final response = await vpClient.sharePresentation(
  vpToken: signedVpToken,
  redirectUri: authRequest['redirect_uri'],
  presentationSubmission: submissionJson,
);
```

---

### 4.7 Credential Verifier

Verifies credentials and presentations.

```dart
final verifier = CredentialVerifier();
```

#### Verify Credential

```dart
final result = await verifier.verifyCredential(
  credential: jsonEncode(credentialData),
  format: 'ldp_vc',  // or 'jwt_vc_json'
);
// result => Map with 'isValid': true/false, 'errors': [...]
```

#### Verify Presentation

```dart
final result = await verifier.verifyPresentation(
  vpToken: vpTokenString,
  presentationDefinition: definitionJson,
);
```

---

## 5. Complete Issuance Flow

End-to-end credential issuance flow:

```dart
import 'package:inji_flutter_sdk/inji_flutter_sdk.dart';

// 1. Initialize SDK clients
final oauth2 = OAuth2Service(authConfig);
final mimoto = MimotoClient(baseUrl: 'https://mimoto-url');
final vciClient = VciClient();
final keystore = SecureKeystore();
final store = CredentialStore();

// 2. Authenticate with Gov.br (OAuth2 + PKCE)
final verifier = oauth2.generateCodeVerifier();
final challenge = oauth2.generateCodeChallenge(verifier);
final authUrl = oauth2.buildAuthorizationUrl(codeChallenge: challenge);
// >> Open authUrl in WebView, intercept redirect to get auth code
final authResult = await oauth2.exchangeCode(authCode, verifier);

// 3. Browse issuers
final issuers = await mimoto.getIssuers();
// User selects an issuer (e.g., INCRA)

// 4. Get issuer configuration
final issuerConfig = await mimoto.getIssuerConfiguration('INCRA');
final wellKnownUrl = issuerConfig['wellknown_endpoint'];

// 5. Fetch credential metadata
final metadata = await mimoto.getWellKnownMetadata(wellKnownUrl);
final credentialEndpoint = metadata['credential_endpoint'];
final issuerUrl = metadata['credential_issuer']; // Used as JWT 'aud'
// User selects a credential type (e.g., CCIRCredential)

// 6. Generate key pair for proof
await keystore.generateKeyPair(alias: 'inji_vci_key_RSA_v2', algorithm: 'RSA');

// 7. Generate JWT proof of possession (see Section 6)
final jwtProof = await generateProof(
  clientId: authConfig.clientId,
  issuerUrl: issuerUrl,
  cNonce: authResult.cNonce,
  algorithm: 'RS256',
);

// 8. Request credential
final credential = await vciClient.requestCredential(
  credentialEndpoint: credentialEndpoint,
  accessToken: authResult.accessToken,
  format: 'ldp_vc',
  proof: jwtProof,
  credentialDefinition: {
    'type': ['VerifiableCredential', 'CCIRCredential'],
    'credentialSubject': null,
    '@context': ['https://www.w3.org/2018/credentials/v1'],
  },
  doctype: 'CCIRCredential',
  issuerId: 'INCRA',
);

// 9. Store credential locally
await store.save('ccir-${DateTime.now().millisecondsSinceEpoch}', {
  ...credential,
  '_meta_id': 'ccir-...',
  '_meta_issuer': 'INCRA',
  '_meta_type': 'CCIRCredential',
  '_meta_issuedAt': DateTime.now().toIso8601String(),
});
```

---

## 6. JWT Proof of Possession

MOSIP Certify requires a JWT proof of possession with each credential request.

### JWT Structure

**Header:**
```json
{
  "alg": "RS256",
  "typ": "openid4vci-proof+jwt",
  "jwk": {
    "kty": "RSA",
    "n": "<base64url-modulus>",
    "e": "<base64url-exponent>"
  }
}
```

**Payload:**
```json
{
  "sub": "your-client-id",
  "aud": "https://credential-issuer-url",
  "iss": "your-client-id",
  "exp": 1700000000,
  "nonce": "c_nonce_from_token_response",
  "iat": 1699999000
}
```

### Implementation

```dart
import 'dart:convert';
import 'package:inji_flutter_sdk/inji_flutter_sdk.dart';

class ProofGenerator {
  final SecureKeystore _keystore = SecureKeystore();

  Future<String> generateProof({
    required String clientId,
    required String issuerUrl,
    String? cNonce,
    String algorithm = 'RS256',
  }) async {
    final keyType = algorithm == 'RS256' ? 'RSA' : 'EC';
    final alias = 'inji_vci_key_${keyType}_v2';

    // Ensure key exists
    final hasKey = await _keystore.hasAlias(alias: alias);
    if (!hasKey) {
      await _keystore.generateKeyPair(alias: alias, algorithm: keyType);
    }

    // Get public key and convert to JWK
    final pubKeyBase64 = await _keystore.getPublicKey(alias: alias);
    final jwk = _publicKeyToJwk(pubKeyBase64, keyType);

    // Build JWT
    final header = {
      'alg': algorithm,
      'typ': 'openid4vci-proof+jwt',
      'jwk': jwk,
    };

    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final payload = {
      'sub': clientId,
      'aud': issuerUrl,
      'iss': clientId,
      'exp': now + 300, // 5 minutes
      'iat': now,
      if (cNonce != null) 'nonce': cNonce,
    };

    final headerB64 = _base64url(jsonEncode(header));
    final payloadB64 = _base64url(jsonEncode(payload));
    final signingInput = '$headerB64.$payloadB64';

    // Sign with device keystore
    final signatureB64 = await _keystore.sign(
      alias: alias,
      data: base64Url.encode(utf8.encode(signingInput)),
    );

    final sigBytes = base64.decode(signatureB64);
    final sigB64url = base64Url.encode(sigBytes).replaceAll('=', '');

    return '$signingInput.$sigB64url';
  }

  String _base64url(String input) {
    return base64Url.encode(utf8.encode(input)).replaceAll('=', '');
  }

  Map<String, dynamic> _publicKeyToJwk(String base64Key, String keyType) {
    final bytes = base64.decode(base64Key);

    if (keyType == 'RSA') {
      // Parse X.509 SubjectPublicKeyInfo to extract n, e
      // (See demo app's proof_generator.dart for full ASN.1 DER parsing)
      return {
        'kty': 'RSA',
        'n': '<extracted-modulus-base64url>',
        'e': '<extracted-exponent-base64url>',
      };
    } else {
      // EC P-256: extract x, y from uncompressed point (04 || x || y)
      return {
        'kty': 'EC',
        'crv': 'P-256',
        'x': '<extracted-x-base64url>',
        'y': '<extracted-y-base64url>',
      };
    }
  }
}
```

> **Note**: The demo app includes a complete `ProofGenerator` class with full ASN.1 DER parsing for RSA public keys and DER-to-raw signature conversion for EC keys. Contact the SDK team for the complete reference implementation.

---

## 7. State Management (Riverpod)

Recommended provider setup with `flutter_riverpod`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inji_flutter_sdk/inji_flutter_sdk.dart';

// SDK client providers (singletons)
final secureKeystoreProvider = Provider<SecureKeystore>((_) => SecureKeystore());
final vciClientProvider = Provider<VciClient>((_) => VciClient());
final openId4VpClientProvider = Provider<OpenId4VpClient>((_) => OpenId4VpClient());
final credentialVerifierProvider = Provider<CredentialVerifier>((_) => CredentialVerifier());
final credentialStoreProvider = Provider<CredentialStore>((_) => CredentialStore());

final mimotoClientProvider = Provider<MimotoClient>((_) {
  return MimotoClient(baseUrl: 'https://your-mimoto-url');
});

final oauth2ServiceProvider = Provider<OAuth2Service>((ref) {
  return OAuth2Service(AuthConfig(
    authorizationEndpoint: '...',
    tokenEndpoint: '...',
    clientId: '...',
    redirectUri: '...',
    scopes: ['openid', 'email', 'profile'],
  ));
});

// Auth state with PKCE persistence
class AuthState {
  final bool isAuthenticated;
  final String? accessToken;
  final String? refreshToken;
  final DateTime? expiresAt;
  final String? cNonce;
  final String? codeVerifier;

  const AuthState({
    this.isAuthenticated = false,
    this.accessToken,
    this.refreshToken,
    this.expiresAt,
    this.cNonce,
    this.codeVerifier,
  });

  bool get isTokenValid =>
      isAuthenticated &&
      accessToken != null &&
      expiresAt != null &&
      DateTime.now().isBefore(expiresAt!);
}

// Credential list provider (reactive)
class StoredCredentialMeta {
  final String id;
  final String issuerName;
  final String credentialType;
  final Map<String, dynamic> data;
  final DateTime issuedAt;

  StoredCredentialMeta({
    required this.id,
    required this.issuerName,
    required this.credentialType,
    required this.data,
    required this.issuedAt,
  });
}

final credentialListProvider =
    StateNotifierProvider<CredentialListNotifier, List<StoredCredentialMeta>>((ref) {
  return CredentialListNotifier(ref.watch(credentialStoreProvider));
});

class CredentialListNotifier extends StateNotifier<List<StoredCredentialMeta>> {
  final CredentialStore _store;

  CredentialListNotifier(this._store) : super([]) {
    _load();
  }

  Future<void> _load() async {
    final all = await _store.getAll();
    state = all.map((item) => StoredCredentialMeta(
      id: item['_meta_id'] as String? ?? '',
      issuerName: item['_meta_issuer'] as String? ?? 'Unknown',
      credentialType: item['_meta_type'] as String? ?? 'Credential',
      data: item,
      issuedAt: DateTime.tryParse(item['_meta_issuedAt'] ?? '') ?? DateTime.now(),
    )).toList();
  }

  Future<void> addCredential({
    required String id,
    required String issuerName,
    required String credentialType,
    required Map<String, dynamic> data,
  }) async {
    final enriched = {
      ...data,
      '_meta_id': id,
      '_meta_issuer': issuerName,
      '_meta_type': credentialType,
      '_meta_issuedAt': DateTime.now().toIso8601String(),
    };
    await _store.save(id, enriched);
    state = [...state, StoredCredentialMeta(
      id: id, issuerName: issuerName, credentialType: credentialType,
      data: enriched, issuedAt: DateTime.now(),
    )];
  }

  Future<void> removeCredential(String id) async {
    await _store.delete(id);
    state = state.where((c) => c.id != id).toList();
  }
}
```

---

## 8. Configuration Reference

### Dataprev Brazil (Gov.br) Environment

```dart
class AppConfig {
  // Mimoto BFF
  static const mimotoBaseUrl =
      'https://injiweb.credenciaisverificaveis-hml.dataprev.gov.br';

  // Gov.br OAuth2
  static const authorizationEndpoint =
      'https://sso.staging.acesso.gov.br/authorize';
  static const tokenEndpoint =
      '$mimotoBaseUrl/v1/mimoto/get-token/ISSUER_ID';
  static const userInfoEndpoint =
      'https://sso.staging.acesso.gov.br/userinfo';

  // Client credentials
  static const clientId = 'your-client-id';
  static const redirectUri = '$mimotoBaseUrl/redirect';
  static const scopes = ['openid', 'email', 'profile', 'govbr_confiabilidades'];
  static const basicAuthHeader = 'Basic <base64(clientId:clientSecret)>';
}
```

### Available Issuers (Dataprev)

| Issuer ID | Credential Type | Format |
|-----------|----------------|--------|
| INCRA | CCIRCredential | ldp_vc |
| MGI | CARCredential | ldp_vc |
| MDA | CAFCredential | ldp_vc |

### Token Endpoint

The token endpoint is a Mimoto proxy. It follows the pattern:
```
https://mimoto-url/v1/mimoto/get-token/{ISSUER_ID}
```

---

## 9. Android Configuration

### AndroidManifest.xml

Add the HTTPS redirect intent filter for OAuth callback:

```xml
<activity android:name=".MainActivity" ...>
    <!-- Existing intent filter -->

    <!-- OAuth redirect handler -->
    <intent-filter android:autoVerify="true">
        <action android:name="android.intent.action.VIEW"/>
        <category android:name="android.intent.category.DEFAULT"/>
        <category android:name="android.intent.category.BROWSABLE"/>
        <data android:scheme="https"
              android:host="your-redirect-domain"
              android:path="/redirect"/>
    </intent-filter>
</activity>
```

### In-App WebView for OAuth

Using `webview_flutter` to intercept the OAuth redirect (recommended over external browser):

```dart
final webViewController = WebViewController()
  ..setJavaScriptMode(JavaScriptMode.unrestricted)
  ..setNavigationDelegate(
    NavigationDelegate(
      onNavigationRequest: (request) {
        final uri = Uri.parse(request.url);
        if (uri.host == 'your-redirect-domain' && uri.path == '/redirect') {
          final code = uri.queryParameters['code'];
          if (code != null) {
            handleAuthCode(code);
            return NavigationDecision.prevent;
          }
        }
        return NavigationDecision.navigate;
      },
    ),
  )
  ..loadRequest(authUrl);
```

---

## 10. Troubleshooting

### `invalid_grant` during token exchange
- **Cause**: Code verifier was lost (app restarted during auth)
- **Fix**: Persist the PKCE code verifier to `FlutterSecureStorage` before opening WebView

### `invalid_proof` from Certify server
- **Cause**: Empty or malformed JWT proof
- **Fix**: Ensure JWT includes `sub`, `aud`, `iss`, `exp`, `nonce`, `iat` fields. The `aud` must be the `credential_issuer` URL from well-known metadata.

### `unsupported_openid4vci_version`
- **Cause**: Missing required fields in credential request
- **Fix**: Include ALL fields: `credentialSubject: null`, `@context`, `doctype`, `claims: null`, `issuerId`, `cwt: null` in proof

### `Incompatible padding mode` KeyStore error
- **Cause**: Old RSA key generated without PKCS1 padding specification
- **Fix**: Delete old key and regenerate. Use alias with `_v2` suffix to force new key generation

### MOSIP Certify only accepts RS256/PS256
- **Cause**: Sending ES256 proof
- **Fix**: Use `algorithm: 'RSA'` for key generation and `'RS256'` for JWT signing

### Browser not returning to app after auth
- **Cause**: HTTPS App Links require `assetlinks.json` on server
- **Fix**: Use in-app WebView that intercepts redirect URL instead of external browser

---


