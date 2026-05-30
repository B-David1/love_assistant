import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/person_score.dart';

class ChatGPTService {
  String get _apiKey => dotenv.env['OPENAI_API_KEY'] ?? '';
  
  Future<List<PersonScore>> analyzeComments(
    List<String> comments, {
    List<String>? ownerComments,
    Function(String, {bool isError})? onStatusUpdate,
  }) async {
    final personScores = <PersonScore>[];
    
    try {
      if (comments.isEmpty) {
        onStatusUpdate?.call('No comment data available to send.');
        return personScores;
      }
      
      onStatusUpdate?.call('Sending ${comments.length} comments for AI scoring…');
      
      final prompt = _buildPrompt(comments, ownerComments: ownerComments);
      
      final response = await _callChatGPTAPI(prompt);
      
      if (response != null) {
        final scores = _parseResponse(response);
        personScores.addAll(scores);
        
        await _saveAnalysisResults(
          comments.length,
          response,
          personScores,
        );
      }
      
    } catch (e) {
      onStatusUpdate?.call('AI service error. Please check your connection and try again.', isError: true);
      debugPrint('ChatGPT error: $e');
    }
    
    return personScores;
  }
  
  String _buildPrompt(List<String> comments, {List<String>? ownerComments}) {
    final buffer = StringBuffer();

    // Task 1: Score every commenter
    buffer.writeln('Task 1 — Score every person who wrote a comment below.');
    buffer.writeln('The score (0–100) represents how positively that person feels about the post owner.');
    buffer.writeln('50 = neutral, 100 = "I love you", 0 = "I despise you".');
    buffer.writeln('Score EVERY distinct commenter — do not skip anyone.');
    buffer.writeln();

    // Task 2: OCEAN for the post owner only
    if (ownerComments != null && ownerComments.isNotEmpty) {
      buffer.writeln('Task 2 — Analyze the Big Five OCEAN personality traits of the POST OWNER');
      buffer.writeln('based ONLY on these comments written by the post owner themselves:');
      for (final c in ownerComments) {
        buffer.writeln(c);
      }
    } else {
      buffer.writeln('Task 2 — Analyze the Big Five OCEAN personality traits of the POST OWNER');
      buffer.writeln('based on the overall tone and content of the comments below.');
    }
    buffer.writeln();
    buffer.writeln('OCEAN traits (0–100):');
    buffer.writeln('- Openness: open to new ideas and experiences');
    buffer.writeln('- Conscientiousness: organized, responsible, disciplined');
    buffer.writeln('- Extraversion: outgoing, sociable, energetic');
    buffer.writeln('- Agreeableness: cooperative, compassionate, trustworthy');
    buffer.writeln('- Neuroticism: anxious, sensitive, emotionally reactive');
    buffer.writeln();
    buffer.writeln('Return a single JSON object. The "ocean" field should reflect the POST OWNER\'s personality.');
    buffer.writeln('Every commenter must appear in "data" with their score.');
    buffer.writeln('{');
    buffer.writeln('"data": [{"person": "<name>", "score": <0-100>, "ocean": {"openness": 0-100, "conscientiousness": 0-100, "extraversion": 0-100, "agreeableness": 0-100, "neuroticism": 0-100}}, ...]');
    buffer.writeln('}');
    buffer.writeln();
    buffer.writeln('Comments:');
    buffer.writeln();

    for (final comment in comments) {
      buffer.writeln(comment);
    }

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
      'max_tokens': 3000,
      'temperature': 0.3,
    };
    
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
      final content = data['choices'][0]['message']['content'] as String;
      debugPrint('ChatGPT Response: $content');
      return content;
    } else {
      debugPrint('API Error: ${response.statusCode} - ${response.body}');
      return null;
    }
  }
  
  List<PersonScore> _parseResponse(String response) {
    final scores = <PersonScore>[];
    
    try {
      // Try to extract JSON from response
      final jsonPattern = RegExp(r'\{[^{}]*"data"[^{}]*\[(.*?)\][^{}]*\}', dotAll: true);
      final match = jsonPattern.firstMatch(response);
      
      if (match != null) {
        final jsonStr = match.group(0)!;
        final parsed = json.decode(jsonStr);
        
        if (parsed.containsKey('data') && parsed['data'] is List) {
          for (final item in parsed['data']) {
            scores.add(PersonScore.fromJson(item));
          }
        }
      } else {
        // Fallback: manual parsing for basic structure
        final personPattern = RegExp(r'"person"\s*:\s*"([^"]+)"');
        final scorePattern = RegExp(r'"score"\s*:\s*(\d+)');
        
        final persons = personPattern.allMatches(response);
        final scoreMatches = scorePattern.allMatches(response);
        
        final personList = persons.map((m) => m.group(1)!).toList();
        final scoreList = scoreMatches.map((m) => int.parse(m.group(1)!)).toList();
        
        for (var i = 0; i < personList.length && i < scoreList.length; i++) {
          scores.add(PersonScore(name: personList[i], score: scoreList[i]));
        }
      }
      
      for (final score in scores) {
        debugPrint('Parsed: ${score.name} = ${score.score}');
        debugPrint('  OCEAN: ${score.oceanSummary}');
      }
      
    } catch (e) {
      debugPrint('Error parsing ChatGPT response: $e');
      debugPrint('Full response was: $response');
    }
    
    return scores;
  }
  
  Future<void> _saveAnalysisResults(
    int commentCount,
    String response,
    List<PersonScore> scores,
  ) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final analysisDir = Directory('${appDir.path}/ChatGPT_Analysis');
      
      if (!await analysisDir.exists()) {
        await analysisDir.create(recursive: true);
      }
      
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      final filePath = '${analysisDir.path}/analysis_$timestamp.txt';
      
      final buffer = StringBuffer();
      buffer.writeln('=== Person Scores Analysis ===');
      buffer.writeln('Analyzed on: ${DateTime.now()}');
      buffer.writeln('Number of comments analyzed: $commentCount');
      buffer.writeln();
      buffer.writeln('=== Scores (0-100) ===');
      
      for (final score in scores) {
        buffer.writeln('${score.name}: ${score.score}/100');
      }
      
      buffer.writeln();
      buffer.writeln('=== OCEAN Personality Traits ===');
      for (final score in scores) {
        buffer.writeln('${score.name}:');
        buffer.writeln('  Openness: ${score.oceanTraits.openness}/100');
        buffer.writeln('  Conscientiousness: ${score.oceanTraits.conscientiousness}/100');
        buffer.writeln('  Extraversion: ${score.oceanTraits.extraversion}/100');
        buffer.writeln('  Agreeableness: ${score.oceanTraits.agreeableness}/100');
        buffer.writeln('  Neuroticism: ${score.oceanTraits.neuroticism}/100');
      }
      
      buffer.writeln();
      buffer.writeln('=== Interpretation ===');
      buffer.writeln('50 = Neutral');
      buffer.writeln('0-49 = Negative opinion (closer to 0 = more negative)');
      buffer.writeln('51-100 = Positive opinion (closer to 100 = more positive)');
      buffer.writeln();
      buffer.writeln('OCEAN Traits (0-100):');
      buffer.writeln('- Openness: How open to new ideas and experiences');
      buffer.writeln('- Conscientiousness: How organized, responsible, and disciplined');
      buffer.writeln('- Extraversion: How outgoing, sociable, and energetic');
      buffer.writeln('- Agreeableness: How cooperative, compassionate, and trustworthy');
      buffer.writeln('- Neuroticism: How anxious, sensitive, and emotionally reactive');
      buffer.writeln();
      buffer.writeln('=== Raw ChatGPT Response ===');
      buffer.writeln(response);
      buffer.writeln();
      buffer.writeln('=== End of Analysis ===');
      
      final file = File(filePath);
      await file.writeAsString(buffer.toString());
      
      debugPrint('Analysis saved to: $filePath');
    } catch (e) {
      debugPrint('Error saving analysis: $e');
    }
  }
}