import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/quiz_questions.dart';

class QuizQuestionService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  List<QuizQuestion>? _cachedPool;

  Future<List<QuizQuestion>> loadQuestionPool() async {
    if (_cachedPool != null) return _cachedPool!;

    final snap = await _db.collection('quiz_questions').get();

    final questions = <QuizQuestion>[];
    for (final doc in snap.docs) {
      final data = doc.data();
      final text = data['text'] as String?;
      final trait = data['trait'] as String?;
      final reversed = data['reversed'] as bool? ?? false;

      if (text != null && trait != null) {
        questions.add(QuizQuestion(text: text, trait: trait, reversed: reversed));
      }
    }

    debugPrint('QuizQuestionService: loaded ${questions.length} questions from Firestore');
    _cachedPool = questions;
    return questions;
  }

  Future<List<QuizQuestion>> selectQuestionsFromDb({
    int countPerTrait = 6,
    int seed = 0,
  }) async {
    final pool = await loadQuestionPool();
    return selectQuestionsFromPool(pool, countPerTrait: countPerTrait, seed: seed);
  }

  void clearCache() => _cachedPool = null;
}