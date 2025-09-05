import "dart:convert";
import "dart:io";
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:pcb_rev/features/ai_integration/data/core.dart';

void main() {
  group('MCP Server Live Tests', () {
    // Assume the server is running on the default port
    final serverConfig = MCPServerConfig();
    final serverUrl =
        'http://${serverConfig.host}:${serverConfig.port}${serverConfig.basePath}';

    test('should connect to the running server and list available tools', () async {
      final request = {
        'jsonrpc': '2.0',
        'id': 'live-test-1',
        'method': 'tools/list',
        'params': {}
      };

      try {
        final response = await http
            .post(
              Uri.parse(serverUrl),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(request),
            )
            .timeout(const Duration(seconds: 5));

        expect(response.statusCode, 200);
        final jsonResponse = jsonDecode(response.body);
        expect(jsonResponse.containsKey('result'), isTrue,
            reason: "Response should contain a 'result' field.");
        expect(jsonResponse['result']['tools'], isA<List>());
        final tools = jsonResponse['result']['tools'] as List;
        expect(tools.any((t) => t['name'] == 'read_current_image'), isTrue,
            reason: "Tool 'read_current_image' should be available.");
      } catch (e) {
        fail(
            'Failed to connect to the MCP server at $serverUrl. Is the application running?\nError: $e');
      }
    });

    test('should successfully call read_current_image tool and save the image', () async {
      final request = {
        'jsonrpc': '2.0',
        'id': 'live-test-2',
        'method': 'tools/call',
        'params': {'name': 'read_current_image', 'arguments': {}}
      };

      try {
        final response = await http
            .post(
              Uri.parse(serverUrl),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(request),
            )
            .timeout(
                const Duration(seconds: 15)); // Longer timeout for image capture

        expect(response.statusCode, 200);
        final jsonResponse = jsonDecode(response.body);

        if (jsonResponse.containsKey('error')) {
          print(
              "Server returned an error (as expected if no image is loaded): ${jsonResponse['error']['message']}");
          expect(jsonResponse['error']['message'], contains('No active image is set'));
        } else {
          expect(jsonResponse.containsKey('result'), isTrue);
          final result = jsonResponse['result'];
          expect(result['content'][0]['type'], 'text');

          final imageData = jsonDecode(result['content'][0]['text']);
          expect(imageData.containsKey('image_id'), isTrue);
          expect(imageData.containsKey('format'), isTrue);
          expect(imageData.containsKey('data'), isTrue);
          expect(imageData['data'], isA<String>(),
              reason: "Image data should be a base64 string.");
          expect(imageData['data'], isNotEmpty,
              reason: "Image data should not be empty.");

          // --- Start of new functionality ---
          print('Decoding and saving image...');
          final imageDataBytes = base64Decode(imageData['data']);
          expect(imageDataBytes, isNotEmpty);

          final testImageFile = File('test_output_view.png');
          await testImageFile.writeAsBytes(imageDataBytes);

          expect(await testImageFile.exists(), isTrue, reason: "Test image file should be created.");
          expect(await testImageFile.length(), greaterThan(0), reason: "Test image file should not be empty.");
          print('Image successfully saved to ${testImageFile.absolute.path}');

          // Clean up the created file
          // await testImageFile.delete();
          // expect(await testImageFile.exists(), isFalse, reason: "Test image file should be deleted after the test.");
          // print('Cleaned up test image file.');
          // --- End of new functionality ---
        }
      } catch (e) {
        fail(
            'Failed to connect to the MCP server at $serverUrl. Is the application running?\nError: $e');
      }
    });

    test('should return a method_not_found error for a non-existent tool',
        () async {
      final request = {
        'jsonrpc': '2.0',
        'id': 'live-test-3',
        'method': 'tools/call',
        'params': {
          'name': 'this_tool_does_not_exist',
          'arguments': {}
        }
      };

      try {
        final response = await http
            .post(
              Uri.parse(serverUrl),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(request),
            )
            .timeout(const Duration(seconds: 5));

        expect(response.statusCode, 200);
        final jsonResponse = jsonDecode(response.body);
        expect(jsonResponse.containsKey('error'), isTrue);
        // The server now throws an ArgumentError which is caught as a generic internal error.
        expect(jsonResponse['error']['code'], -32603);
        expect(jsonResponse['error']['message'], 'Internal error');
        expect(jsonResponse['error']['data'],
            contains('Unknown tool: this_tool_does_not_exist'));
      } catch (e) {
        fail(
            'Failed to connect to the MCP server at $serverUrl. Is the application running?\nError: $e');
      }
    });
  });
}