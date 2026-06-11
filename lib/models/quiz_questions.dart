import 'dart:math';

class QuizQuestion {
  final String text;
  final String trait;

  final bool reversed;

  const QuizQuestion({
    required this.text,
    required this.trait,
    this.reversed = false,
  });
}

double likertDelta(int response, {bool reversed = false}) {
  const deltas = {1: -10.0, 2: -4.0, 3: 0.0, 4: 4.0, 5: 10.0};
  final base = deltas[response] ?? 0.0;
  return reversed ? -base : base;
}

List<QuizQuestion> selectQuestionsFromPool(
  List<QuizQuestion> pool, {
  int countPerTrait = 6,
  int seed = 0,
}) {
  final rng = Random(seed);

  final byTrait = <String, List<QuizQuestion>>{};
  for (final q in pool) {
    byTrait.putIfAbsent(q.trait, () => []).add(q);
  }

  final selected = <QuizQuestion>[];
  for (final questions in byTrait.values) {
    final shuffled = List.of(questions)..shuffle(rng);
    selected.addAll(shuffled.take(countPerTrait));
  }

  return selected..shuffle(rng);
}
