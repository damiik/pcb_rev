import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;



// ============================================================================
// Extension: AI Integration Service
// ============================================================================

class AIAnalysisService {
  final String apiEndpoint;
  final String apiKey;
  final http.Client httpClient;
  
  AIAnalysisService({
    required this.apiEndpoint,
    required this.apiKey,
    http.Client? httpClient,
  }) : httpClient = httpClient ?? http.Client();
  
  Future<Map<String, dynamic>> analyzeImage({
    required Uint8List imageData,
    required Map<String, dynamic> context,
    Map<String, dynamic>? options,
  }) async {
    final request = {
      'image': base64Encode(imageData),
      'context': context,
      'options': options ?? {},
      'timestamp': DateTime.now().toIso8601String(),
    };
    
    final response = await httpClient.post(
      Uri.parse('$apiEndpoint/analyze'),
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(request),
    );
    
    if (response.statusCode != 200) {
      throw Exception('AI Analysis failed: ${response.statusCode} - ${response.body}');
    }
    
    return jsonDecode(response.body);
  }
  
  Future<List<Map<String, dynamic>>> batchAnalyze({
    required List<Uint8List> images,
    required Map<String, dynamic> context,
  }) async {
    final futures = images.map((image) => analyzeImage(
          imageData: image,
          context: context,
        ));
    
    return Future.wait(futures);
  }
  
  void dispose() {
    httpClient.close();
  }
}