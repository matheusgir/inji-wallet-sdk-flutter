import 'package:dio/dio.dart';

/// Client for communicating with the Mimoto backend service.
class MimotoClient {
  final Dio _dio;
  final String baseUrl;

  MimotoClient({required this.baseUrl, Dio? dio})
      : _dio = dio ?? Dio(BaseOptions(baseUrl: baseUrl));

  /// Retrieves the list of configured credential issuers.
  Future<List<Map<String, dynamic>>> getIssuers() async {
    final response = await _dio.get('/v1/mimoto/issuers');
    final data = response.data;

    // Handle nested response: {"response": {"issuers": [...]}, "errors": []}
    if (data is Map) {
      final responseObj = data['response'];
      if (responseObj is Map && responseObj.containsKey('issuers')) {
        final issuers = responseObj['issuers'] as List;
        return issuers
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      }
      if (data.containsKey('issuers')) {
        final issuers = data['issuers'] as List;
        return issuers
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      }
    }

    if (data is List) {
      return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }

    return [];
  }

  /// Retrieves the detailed configuration for a specific issuer.
  Future<Map<String, dynamic>> getIssuerConfiguration(String issuerId) async {
    final response = await _dio.get('/v1/mimoto/issuers/$issuerId');
    final data = response.data;

    // Handle nested response: {"response": {...}, "errors": []}
    if (data is Map && data.containsKey('response') && data['response'] is Map) {
      return Map<String, dynamic>.from(data['response'] as Map);
    }
    return Map<String, dynamic>.from(data as Map);
  }

  /// Fetches OpenID credential issuer metadata from the well-known endpoint.
  Future<Map<String, dynamic>> getWellKnownMetadata(
      String wellknownEndpoint) async {
    final response = await Dio().get(wellknownEndpoint);
    return Map<String, dynamic>.from(response.data as Map);
  }

  /// Retrieves all application properties from the Mimoto backend.
  Future<Map<String, dynamic>> getAllProperties() async {
    final response = await _dio.get('/v1/mimoto/allProperties');
    final data = response.data;
    if (data is Map && data.containsKey('response') && data['response'] is Map) {
      return Map<String, dynamic>.from(data['response'] as Map);
    }
    return Map<String, dynamic>.from(data as Map);
  }
}
