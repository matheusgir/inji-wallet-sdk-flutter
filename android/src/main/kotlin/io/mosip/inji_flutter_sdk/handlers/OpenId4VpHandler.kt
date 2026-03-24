package io.mosip.inji_flutter_sdk.handlers

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.mosip.openID4VP.OpenID4VP
import io.mosip.openID4VP.authorizationRequest.Verifier
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import org.json.JSONArray
import org.json.JSONObject
import java.util.UUID

class OpenId4VpHandler : MethodChannel.MethodCallHandler {

    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    private val mainHandler = Handler(Looper.getMainLooper())
    private val mutex = Mutex()

    @Volatile private var openId4VP = OpenID4VP("flutter-sdk")
    @Volatile private var lastUnsignedVpJson: JSONObject? = null
    @Volatile private var lastProofJson: JSONObject? = null
    @Volatile private var lastFormatTypes: List<String> = emptyList()

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "authenticateVerifier" -> {
                val encodedRequest = call.argument<String>("encodedRequest")
                    ?: return result.error("invalid_args", "encodedRequest is required", null)

                val trustedVerifiersRaw = call.argument<List<Map<String, Any>>>("trustedVerifiers") ?: emptyList()
                val trustedVerifiers = trustedVerifiersRaw.mapNotNull { map ->
                    val clientId = map["clientId"] as? String ?: map["client_id"] as? String ?: return@mapNotNull null
                    val redirectUri = map["redirectUri"] as? String
                        ?: (map["redirect_uris"] as? List<*>)?.firstOrNull() as? String
                        ?: (map["response_uris"] as? List<*>)?.firstOrNull() as? String
                        ?: clientId
                    Verifier(clientId, listOf(redirectUri))
                }

                scope.launch {
                    mutex.withLock {
                        try {
                            openId4VP = OpenID4VP("flutter-sdk")
                            lastUnsignedVpJson = null
                            lastProofJson = null
                            lastFormatTypes = emptyList()

                            val authRequest = openId4VP.authenticateVerifier(encodedRequest, trustedVerifiers)
                            val resultMap = mapOf(
                                "clientId" to (authRequest.clientId ?: ""),
                                "clientIdScheme" to (authRequest.clientIdScheme ?: ""),
                                "responseUri" to (authRequest.responseUri ?: ""),
                                "redirectUri" to authRequest.redirectUri,
                                "responseMode" to (authRequest.responseMode ?: ""),
                                "responseType" to (authRequest.responseType ?: ""),
                                "nonce" to (authRequest.nonce ?: ""),
                                "state" to (authRequest.state ?: ""),
                                "presentationDefinition" to mapOf(
                                    "id" to (authRequest.presentationDefinition?.id ?: ""),
                                    "inputDescriptors" to (authRequest.presentationDefinition?.inputDescriptors?.map { desc ->
                                        mapOf("id" to desc.id, "name" to desc.name, "purpose" to desc.purpose)
                                    } ?: emptyList<Any>())
                                ),
                                "clientMetadata" to mapOf(
                                    "clientName" to authRequest.clientMetadata?.clientName,
                                    "logoUri" to authRequest.clientMetadata?.logoUri
                                )
                            )
                            mainHandler.post { result.success(resultMap) }
                        } catch (e: Exception) {
                            mainHandler.post { result.error("openid4vp_error", e.message, null) }
                        }
                    }
                }
            }

            "constructUnsignedVPToken" -> {
                val credentialsRaw = call.argument<Map<String, Any>>("credentials")
                    ?: return result.error("invalid_args", "credentials is required", null)
                val holderId = call.argument<String>("holderId") ?: ""
                val signatureSuite = call.argument<String>("signatureSuite") ?: "Ed25519Signature2020"
                val nonce = call.argument<String>("nonce") ?: ""
                val clientId = call.argument<String>("clientId") ?: ""

                scope.launch {
                    mutex.withLock {
                        try {
                            val credStrings = mutableListOf<String>()
                            for ((_, formatMapRaw) in credentialsRaw) {
                                val formatMap = formatMapRaw as? Map<*, *> ?: continue
                                for ((_, creds) in formatMap) {
                                    val credList = creds as? List<*> ?: continue
                                    for (cred in credList) {
                                        when (cred) {
                                            is String -> credStrings.add(cred)
                                            is Map<*, *> -> credStrings.add(JSONObject(cred as Map<String, Any>).toString())
                                            else -> {}
                                        }
                                    }
                                }
                            }

                            val authReq = openId4VP.authorizationRequest
                            val effectiveNonce = nonce.ifEmpty { authReq?.nonce ?: "" }
                            val effectiveClientId = clientId.ifEmpty { authReq?.clientId ?: "" }
                            val effectiveHolder = holderId.ifEmpty { effectiveClientId }

                            // Cada elemento deve ser uma STRING (não objeto)
                            // O verifier faz: (String) verifiableCredential → new JSONObject(str)
                            val vcArray = JSONArray().apply {
                                credStrings.forEach { put(it) }
                            }

                            // VP sem proof — é isso que será assinado
                            val vpJson = JSONObject().apply {
                                put("@context", JSONArray().apply {
                                    put("https://www.w3.org/2018/credentials/v1")
                                })
                                put("type", JSONArray().apply {
                                    put("VerifiablePresentation")
                                })
                                put("verifiableCredential", vcArray)
                                put("holder", effectiveHolder)
                            }

                            // Proof sem jws — será completado em sendVPResponseToVerifier
                            val proofJson = JSONObject().apply {
                                put("type", signatureSuite)
                                put("challenge", effectiveNonce)
                                put("domain", effectiveClientId)
                                put("proofPurpose", "authentication")
                                put("verificationMethod", effectiveHolder)
                            }

                            lastUnsignedVpJson = vpJson
                            lastProofJson = proofJson
                            lastFormatTypes = listOf("ldp_vc")

                            // dataToSign = VP JSON sem proof em base64
                            val dataToSign = android.util.Base64.encodeToString(
                                vpJson.toString().toByteArray(Charsets.UTF_8),
                                android.util.Base64.NO_WRAP
                            )

                            mainHandler.post {
                                result.success(mapOf(
                                    "dataToSign" to dataToSign,
                                    "formatTypes" to lastFormatTypes,
                                    "formats" to mapOf("ldp_vc" to mapOf("dataToSign" to dataToSign))
                                ))
                            }
                        } catch (e: Exception) {
                            mainHandler.post {
                                result.error("openid4vp_error", "${e.javaClass.simpleName}: ${e.message}", e.stackTraceToString())
                            }
                        }
                    }
                }
            }

            "sendVPResponseToVerifier" -> {
                val jws = call.argument<String>("jws")
                    ?: return result.error("invalid_args", "jws is required", null)
                val responseUriParam = call.argument<String>("responseUri") ?: ""
                val stateParam = call.argument<String>("state") ?: ""
                val descriptorIdParam = call.argument<String>("descriptorId") ?: "ECACredential"
                val definitionIdParam = call.argument<String>("definitionId") ?: "eca-age-check"

                scope.launch {
                    mutex.withLock {
                        try {
                            val responseUri = responseUriParam.ifEmpty {
                                openId4VP.authorizationRequest?.responseUri
                                    ?: throw Exception("responseUri is null")
                            }
                            val effectiveState = stateParam.ifEmpty {
                                openId4VP.authorizationRequest?.state ?: ""
                            }

                            val vpJson = lastUnsignedVpJson
                                ?: throw Exception("constructUnsignedVPToken not called")
                            val proofJson = lastProofJson ?: JSONObject()
                            proofJson.put("jws", jws)

                            // VP final = VP sem proof + proof com jws
                            val vpFinal = JSONObject(vpJson.toString())
                            vpFinal.put("proof", proofJson)

                            val vcCount = vpJson.getJSONArray("verifiableCredential").length()
                            val submission = JSONObject().apply {
                                put("id", UUID.randomUUID().toString())
                                put("definition_id", definitionIdParam)
                                put("descriptor_map", JSONArray().apply {
                                    for (i in 0 until vcCount) {
                                        put(JSONObject().apply {
                                            put("id", descriptorIdParam)
                                            put("format", "ldp_vc")
                                            put("path", "$.verifiableCredential[$i]")
                                        })
                                    }
                                })
                            }

                            val formData = buildString {
                                append("vp_token=")
                                append(java.net.URLEncoder.encode(vpFinal.toString(), "UTF-8"))
                                append("&presentation_submission=")
                                append(java.net.URLEncoder.encode(submission.toString(), "UTF-8"))
                                if (effectiveState.isNotEmpty()) {
                                    append("&state=")
                                    append(java.net.URLEncoder.encode(effectiveState, "UTF-8"))
                                }
                            }

                            android.util.Log.d("OpenId4VpHandler", "POST $responseUri state=$effectiveState")
                            android.util.Log.d("OpenId4VpHandler", "VP_FINAL: $vpFinal")

                            val url = java.net.URL(responseUri)
                            val conn = url.openConnection() as javax.net.ssl.HttpsURLConnection
                            conn.requestMethod = "POST"
                            conn.setRequestProperty("Content-Type", "application/x-www-form-urlencoded")
                            conn.doOutput = true
                            conn.outputStream.use { it.write(formData.toByteArray(Charsets.UTF_8)) }
                            val respCode = conn.responseCode
                            val respBody = try {
                                conn.inputStream.bufferedReader().readText()
                            } catch (e: Exception) {
                                conn.errorStream?.bufferedReader()?.readText() ?: ""
                            }
                            android.util.Log.d("OpenId4VpHandler", "  -> $respCode: $respBody")

                            if (respCode in 200..299) {
                                mainHandler.post { result.success(mapOf("body" to respBody, "statusCode" to respCode)) }
                            } else {
                                throw Exception("HTTP $respCode: $respBody")
                            }
                        } catch (e: Exception) {
                            mainHandler.post { result.error("openid4vp_error", e.message ?: "Failed to send VP response", null) }
                        }
                    }
                }
            }

            "sharePresentation" -> {
                val signedVpToken = call.argument<String>("signedVpToken")
                    ?: return result.error("invalid_args", "signedVpToken is required", null)

                scope.launch {
                    mutex.withLock {
                        try {
                            val authReq = openId4VP.authorizationRequest
                                ?: throw Exception("authenticateVerifier not called")
                            val responseUri = authReq.responseUri
                                ?: throw Exception("responseUri is null")
                            val stateParam = authReq.state ?: call.argument<String>("requestId") ?: ""
                            val descriptorId = call.argument<String>("descriptorId")
                                ?: authReq.presentationDefinition?.inputDescriptors?.firstOrNull()?.id
                                ?: ""
                            val definitionId = call.argument<String>("definitionId")
                                ?: authReq.presentationDefinition?.id
                                ?: ""
                            val inputDescriptors = authReq.presentationDefinition?.inputDescriptors ?: emptyList()

                            val submission = JSONObject().apply {
                                put("id", UUID.randomUUID().toString())
                                put("definition_id", definitionId)
                                put("descriptor_map", JSONArray().apply {
                                    inputDescriptors.forEachIndexed { i, desc ->
                                        put(JSONObject().apply {
                                            put("id", desc.id)
                                            put("format", "ldp_vc")
                                            put("path", "$.verifiableCredential[$i]")
                                        })
                                    }
                                })
                            }

                            val formData = buildString {
                                append("vp_token=")
                                append(java.net.URLEncoder.encode(signedVpToken, "UTF-8"))
                                append("&presentation_submission=")
                                append(java.net.URLEncoder.encode(submission.toString(), "UTF-8"))
                                if (stateParam.isNotEmpty()) {
                                    append("&state=")
                                    append(java.net.URLEncoder.encode(stateParam, "UTF-8"))
                                }
                            }

                            val url = java.net.URL(responseUri)
                            val conn = url.openConnection() as javax.net.ssl.HttpsURLConnection
                            conn.requestMethod = "POST"
                            conn.setRequestProperty("Content-Type", "application/x-www-form-urlencoded")
                            conn.doOutput = true
                            conn.outputStream.use { it.write(formData.toByteArray(Charsets.UTF_8)) }
                            val respCode = conn.responseCode
                            val respBody = try {
                                conn.inputStream.bufferedReader().readText()
                            } catch (e: Exception) {
                                conn.errorStream?.bufferedReader()?.readText() ?: ""
                            }
                            if (respCode in 200..299) {
                                mainHandler.post { result.success(mapOf("response" to respBody)) }
                            } else {
                                throw Exception("HTTP $respCode: $respBody")
                            }
                        } catch (e: Exception) {
                            mainHandler.post { result.error("openid4vp_error", e.message ?: "Failed to share presentation", null) }
                        }
                    }
                }
            }

            "sendErrorToVerifier" -> {
                scope.launch {
                    try {
                        val errorCode = call.argument<String>("errorCode") ?: "UNKNOWN_ERROR"
                        val errorMessage = call.argument<String>("errorMessage") ?: ""
                        openId4VP.sendErrorToVerifier(Exception("$errorCode: $errorMessage"))
                        mainHandler.post { result.success(null) }
                    } catch (e: Exception) {
                        mainHandler.post { result.success(null) }
                    }
                }
            }

            else -> result.notImplemented()
        }
    }
}
