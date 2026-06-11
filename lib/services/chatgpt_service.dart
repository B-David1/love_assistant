import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../models/person_score.dart';

class ChatGPTService {
  static const _model      = 'gpt-4o-mini';
  static const _maxTokens  = 3000;
  static const _temperature = 0.3;
  static const _endpoint   = 'https://api.openai.com/v1/chat/completions';

  String get _apiKey => dotenv.env['OPENAI_API_KEY'] ?? '';

  Future<List<PersonScore>> analyzeComments(
    List<String> comments, {
    List<String>? ownerComments,
    void Function(String, {bool isError})? onStatusUpdate,
  }) async {
    if (comments.isEmpty) {
      onStatusUpdate?.call('No comment data available to send.');
      return [];
    }

    onStatusUpdate?.call(
        'Sending ${comments.length} comments for AI scoring…');

    try {
      final prompt   = _buildPrompt(comments, ownerComments: ownerComments);
      final response = await _callApi(prompt);

      if (response == null) return [];

      final scores = _parseResponse(response);
      await _saveDebugLog(comments.length, response, scores);
      return scores;
    } catch (e) {
      onStatusUpdate?.call(
          'AI service error. Please check your connection and try again.',
          isError: true);
      debugPrint('ChatGPTService: error — $e');
      return [];
    }
  }

  String _buildPrompt(
    List<String> comments, {
    List<String>? ownerComments,
  }) {
    final buf = StringBuffer()
      ..writeln('Task 1 — Score every person who wrote a comment below.')
      ..writeln(
          'The score (0–100) represents how positively that person feels '
          'about the post owner. 50 = neutral, 100 = "I love you", '
          '0 = "I despise you".')
      ..writeln('Score EVERY distinct commenter — do not skip anyone.')
      ..writeln();

    if (ownerComments != null && ownerComments.isNotEmpty) {
      buf
        ..writeln(
            'Task 2 — Analyse the Big Five OCEAN personality traits of the '
            'POST OWNER based ONLY on these comments written by the post '
            'owner themselves:')
        ..writeAll(ownerComments, '\n')
        ..writeln();
    } else {
      buf.writeln(
          'Task 2 — Analyse the Big Five OCEAN personality traits of the '
          'POST OWNER based on the overall tone and content of all comments.');
    }

    buf
      ..writeln()
      ..writeln('OCEAN traits (0–100):')
      ..writeln('- Openness:          open to new ideas and experiences')
      ..writeln('- Conscientiousness: organised, responsible, disciplined')
      ..writeln('- Extraversion:      outgoing, sociable, energetic')
      ..writeln('- Agreeableness:     cooperative, compassionate, trustworthy')
      ..writeln('- Neuroticism:       anxious, sensitive, emotionally reactive')
      ..writeln()
      ..writeln(
          "Return a single JSON object. The \"ocean\" field reflects the "
          "POST OWNER's personality. Every commenter must appear in \"data\".")
      ..writeln('{')
      ..writeln(
          '"data": [{"person": "<name>", "score": <0-100>, '
          '"ocean": {"openness": 0-100, "conscientiousness": 0-100, '
          '"extraversion": 0-100, "agreeableness": 0-100, '
          '"neuroticism": 0-100}}, ...]')
      ..writeln('}')
      ..writeln()
      ..writeln('Comments:')
      ..writeln()
      ..writeAll(comments, '\n');

    return buf.toString();
  }

  Future<String?> _callApi(String prompt) async {
    final body = jsonEncode({
      'model':       _model,
      'messages':    [{'role': 'user', 'content': prompt}],
      'max_tokens':  _maxTokens,
      'temperature': _temperature,
    });

    final res = await http.post(
      Uri.parse(_endpoint),
      headers: {
        'Content-Type':  'application/json',
        'Authorization': 'Bearer $_apiKey',
      },
      body: body,
    );

    if (res.statusCode != 200) {
      debugPrint('ChatGPTService: HTTP ${res.statusCode} — ${res.body}');
      return null;
    }

    final data    = json.decode(res.body) as Map<String, dynamic>;
    final content = data['choices'][0]['message']['content'] as String;
    debugPrint('ChatGPTService: response received (${content.length} chars)');
    return content;
  }

  List<PersonScore> _parseResponse(String response) {
    try {
      final match = RegExp(
        r'\{[^{}]*"data"[^{}]*\[(.*?)\][^{}]*\}',
        dotAll: true,
      ).firstMatch(response);

      if (match != null) {
        final parsed = json.decode(match.group(0)!) as Map<String, dynamic>;
        if (parsed['data'] is List) {
          return (parsed['data'] as List)
              .map((item) =>
                  PersonScore.fromJson(item as Map<String, dynamic>))
              .toList();
        }
      }

      debugPrint('ChatGPTService: falling back to manual parsing');
      return _manualParse(response);
    } catch (e) {
      debugPrint('ChatGPTService: parse error — $e');
      return [];
    }
  }

  List<PersonScore> _manualParse(String response) {
    final names  = RegExp(r'"person"\s*:\s*"([^"]+)"')
        .allMatches(response)
        .map((m) => m.group(1)!)
        .toList();
    final scores = RegExp(r'"score"\s*:\s*(\d+)')
        .allMatches(response)
        .map((m) => int.parse(m.group(1)!))
        .toList();

    return [
      for (var i = 0; i < names.length && i < scores.length; i++)
        PersonScore(name: names[i], score: scores[i]),
    ];
  }

  Future<void> _saveDebugLog(
    int commentCount,
    String response,
    List<PersonScore> scores,
  ) async {
    try {
      final dir = Directory(
          '${(await getApplicationDocumentsDirectory()).path}/ChatGPT_Analysis');
      if (!await dir.exists()) await dir.create(recursive: true);

      final stamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      final file  = File('${dir.path}/analysis_$stamp.txt');

      final buf = StringBuffer()
        ..writeln('=== Analysis — ${DateTime.now()} ===')
        ..writeln('Comments analysed: $commentCount')
        ..writeln()
        ..writeln('=== Scores ===');

      for (final s in scores) {
        buf.writeln('${s.name}: ${s.score}/100  OCEAN: ${s.oceanSummary}');
      }

      buf
        ..writeln()
        ..writeln('=== Raw Response ===')
        ..writeln(response);

      await file.writeAsString(buf.toString());
    } catch (e) {
      debugPrint('ChatGPTService: failed to save debug log — $e');
    }
  }
}
