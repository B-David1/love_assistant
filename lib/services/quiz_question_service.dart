import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/quiz_questions.dart';

class QuizQuestionService {
  QuizQuestionService();

  final _db = FirebaseFirestore.instance;

  List<QuizQuestion>? _cache;

  Future<List<QuizQuestion>> loadQuestionPool() async {
    if (_cache != null) return _cache!;

    final snap = await _db.collection('quiz_questions').get();

    final questions = snap.docs.expand((doc) {
      final data      = doc.data();
      final text      = data['text']      as String?;
      final trait     = data['trait']     as String?;
      final reversed  = data['reversed']  as bool? ?? false;
      if (text == null || trait == null) return <QuizQuestion>[];
      return [QuizQuestion(text: text, trait: trait, reversed: reversed)];
    }).toList();

    debugPrint('QuizQuestionService: loaded ${questions.length} questions');
    _cache = questions;
    return questions;
  }

  Future<List<QuizQuestion>> selectQuestionsFromDb({
    int countPerTrait = 6,
    int seed = 0,
  }) async {
    final pool = await loadQuestionPool();
    return selectQuestionsFromPool(
        pool, countPerTrait: countPerTrait, seed: seed);
  }

  void clearCache() => _cache = null;
}
