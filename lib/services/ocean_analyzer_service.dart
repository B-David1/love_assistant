import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/ocean_scores.dart';

class OceanAnalyzerService {
  String get _apiKey => dotenv.env['OPENAI_API_KEY'] ?? '';

  Future<OceanScores> analyzeOceanTraits(Map<String, int> personScores) async {
    try {
      final prompt = _buildOceanPrompt(personScores);
      final response = await _callChatGPTAPI(prompt);
      
      if (response != null) {
        return _parseOceanResponse(response);
      }
    } catch (e) {
      print('Ocean analysis error: $e');
    }
    
    // Return default neutral scores if analysis fails
    return OceanScores(
      openness: 50.0,
      conscientiousness: 50.0,
      extraversion: 50.0,
      agreeableness: 50.0,
      neuroticism: 50.0,
    );
  }

  String _buildOceanPrompt(Map<String, int> personScores) {
    final buffer = StringBuffer();
    buffer.writeln('Based on how this person rates others (from 0-100, where 50 is neutral), analyze their Big Five OCEAN personality traits:');
    buffer.writeln();
    buffer.writeln('Here are their ratings of other people:');
    buffer.writeln();
    
    final sortedEntries = personScores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    for (final entry in sortedEntries.take(20)) {
      buffer.writeln('- ${entry.key}: ${entry.value}/100');
    }
    
    buffer.writeln();
    buffer.writeln('Based on these ratings, provide OCEAN scores (0-100) where:');
    buffer.writeln('- Openness: tendency to be open-minded vs conventional');
    buffer.writeln('- Conscientiousness: tendency to be organized vs careless');
    buffer.writeln('- Extraversion: tendency to be outgoing vs reserved');
    buffer.writeln('- Agreeableness: tendency to be compassionate vs detached');
    buffer.writeln('- Neuroticism: tendency to experience negative emotions vs emotional stability');
    buffer.writeln();
    buffer.writeln('Return JSON format: {"openness": 75, "conscientiousness": 60, "extraversion": 80, "agreeableness": 70, "neuroticism": 30}');
    
    return buffer.toString();
  }

  Future<String?> _callChatGPTAPI(String prompt) async {
    const apiUrl = 'https://api.openai.com/v1/chat/completions';
    
    final requestBody = {
      'model': 'gpt-4o-mini',
      'messages': [
        {
          'role': 'user',
          'content': prompt,
        }
      ],
      'max_tokens': 500,
      'temperature': 0.3,
    };
    
    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: json.encode(requestBody),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['choices'][0]['message']['content'] as String;
      }
    } catch (e) {
      print('API call error: $e');
    }
    
    return null;
  }

  OceanScores _parseOceanResponse(String response) {
    try {
      // Try to extract JSON from response
      final jsonPattern = RegExp(r'\{[^{}]*"openness"[^{}]*\}', dotAll: true);
      final match = jsonPattern.firstMatch(response);
      
      if (match != null) {
        final parsed = json.decode(match.group(0)!);
        return OceanScores.fromJson(parsed);
      }
    } catch (e) {
      print('Error parsing ocean response: $e');
    }
    
    return OceanScores(
      openness: 50.0,
      conscientiousness: 50.0,
      extraversion: 50.0,
      agreeableness: 50.0,
      neuroticism: 50.0,
    );
  }
}