package io.mosip.inji_flutter_sdk

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodChannel
import io.mosip.inji_flutter_sdk.handlers.KeystoreHandler
import io.mosip.inji_flutter_sdk.handlers.OpenId4VpHandler
import io.mosip.inji_flutter_sdk.handlers.VciHandler
import io.mosip.inji_flutter_sdk.handlers.VerifierHandler

/**
 * InjiFlutterSdkPlugin registers platform channels for the Inji Flutter SDK.
 *
 * Channels:
 *  - io.mosip.inji/vci         → VCI credential issuance
 *  - io.mosip.inji/openid4vp   → OpenID4VP presentation sharing
 *  - io.mosip.inji/verifier    → Credential / VP verification
 *  - io.mosip.inji/keystore    → Secure key management
 */
class InjiFlutterSdkPlugin : FlutterPlugin {

    private lateinit var vciChannel: MethodChannel
    private lateinit var openId4VpChannel: MethodChannel
    private lateinit var verifierChannel: MethodChannel
    private lateinit var keystoreChannel: MethodChannel

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        val messenger = flutterPluginBinding.binaryMessenger

        vciChannel = MethodChannel(messenger, "io.mosip.inji/vci")
        vciChannel.setMethodCallHandler(VciHandler())

        openId4VpChannel = MethodChannel(messenger, "io.mosip.inji/openid4vp")
        openId4VpChannel.setMethodCallHandler(OpenId4VpHandler())

        verifierChannel = MethodChannel(messenger, "io.mosip.inji/verifier")
        verifierChannel.setMethodCallHandler(VerifierHandler())

        keystoreChannel = MethodChannel(messenger, "io.mosip.inji/keystore")
        keystoreChannel.setMethodCallHandler(KeystoreHandler())
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        vciChannel.setMethodCallHandler(null)
        openId4VpChannel.setMethodCallHandler(null)
        verifierChannel.setMethodCallHandler(null)
        keystoreChannel.setMethodCallHandler(null)
    }
}
