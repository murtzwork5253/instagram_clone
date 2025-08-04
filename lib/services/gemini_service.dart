import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class GeminiService {
  // This is the main function you'll call from your chat screen
  static Future<String> getResponse(String prompt) async {
    // 1. Get the API Key from your .env file
    final apiKey = dotenv.env['GEMINI_API_KEY'];

    if (apiKey == null) {
      return 'Error: API Key is not set in the .env file';
    }

    // 2. This is the endpoint for the Gemini API
    final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash-latest:generateContent?key=$apiKey');

    // 3. These are the headers for the API request
    final headers = {
      'Content-Type': 'application/json',
    };

    // 4. This is the body of the request, containing the user's prompt
    final body = jsonEncode({
      'contents': [
        {
          'parts': [
            {'text': prompt}
          ]
        }
      ]
    });

    try {
      // 5. Make the API call
      final response = await http.post(url, headers: headers, body: body);

      // 6. Check if the request was successful and parse the response
      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        // Extract the text from the complex JSON response
        return responseBody['candidates'][0]['content']['parts'][0]['text'];
      } else {
        // Handle errors
        return 'Error: ${response.statusCode}\n${response.body}';
      }
    } catch (e) {
      // Handle potential network errors
      return 'Error making API call: $e';
    }
  }
}