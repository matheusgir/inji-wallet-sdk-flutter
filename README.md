# Inji Flutter SDK

Flutter SDK for MOSIP Inji — digital credential management (VCI, OpenID4VP, verification, secure keystore).

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  inji_flutter_sdk:
    path: ./inji_flutter_sdk  # or wherever you place this folder
```

Then run:
```bash
flutter pub get
```

## Requirements

- Flutter >= 3.3.0
- Android minSdk 23, compileSdk 34
- Java 17

## Usage

```dart
import 'package:inji_flutter_sdk/inji_flutter_sdk.dart';

// VCI - Issue credentials
final vciClient = VciClient();
final metadata = await vciClient.getIssuerMetadata(wellKnownUrl: '...');
final credential = await vciClient.requestCredential(
  credentialEndpoint: '...',
  accessToken: '...',
  format: 'ldp_vc',
  proof: '...',
  credentialDefinition: {...},
);

// Secure Keystore
final keystore = SecureKeystore();
await keystore.generateKeyPair(alias: 'my_key', algorithm: 'RSA');
final signature = await keystore.sign(alias: 'my_key', data: '...');

// OAuth2
final oauth2 = OAuth2Service(AuthConfig(
  authorizationEndpoint: '...',
  tokenEndpoint: '...',
  clientId: '...',
  redirectUri: '...',
  scopes: ['openid'],
));

// Mimoto Backend
final mimoto = MimotoClient(baseUrl: 'https://...');
final issuers = await mimoto.getIssuers();

// Credential Storage
final store = CredentialStore();
await store.save('id', {'type': 'VerifiableCredential', ...});

// OpenID4VP
final vpClient = OpenId4VpClient();

// Verification
final verifier = CredentialVerifier();
```

## Modules

| Module | Class | Description |
|--------|-------|-------------|
| VCI | `VciClient` | Verifiable Credential Issuance (OpenID4VCI) |
| OpenID4VP | `OpenId4VpClient` | Verifiable Presentations sharing |
| Verifier | `CredentialVerifier` | Credential verification |
| Keystore | `SecureKeystore` | Android Keystore key management |
| Auth | `OAuth2Service` | OAuth2 + PKCE authentication |
| Backend | `MimotoClient` | Mimoto BFF integration |
| Storage | `CredentialStore` | Secure credential storage |
