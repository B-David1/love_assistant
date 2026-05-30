import 'dart:math';

// ── Data model ────────────────────────────────────────────────────────────────

/// A Likert-scale quiz question tied to one OCEAN trait.
///
/// [reversed] = true means the trait effect is inverted:
///   answering 5 ("Strongly Agree") *decreases* the trait (used for
///   items phrased as "I stay calm…" for neuroticism, etc.).
class QuizQuestion {
  final String text;
  final String trait; // 'openness' | 'conscientiousness' | 'extraversion' | 'agreeableness' | 'neuroticism'
  final bool reversed;

  const QuizQuestion({
    required this.text,
    required this.trait,
    this.reversed = false,
  });
}

// ── Likert helpers ────────────────────────────────────────────────────────────

/// Labels for Likert responses 1–5.
const List<String> likertLabels = [
  'Strongly\nDisagree',
  'Disagree',
  'Neutral',
  'Agree',
  'Strongly\nAgree',
];

/// Maps a Likert response (1–5) to a trait delta.
/// Normal:   1 → −10, 2 → −4, 3 → 0, 4 → +4, 5 → +10.
/// Reversed: signs are flipped.
double likertDelta(int response, {bool reversed = false}) {
  const map = {1: -10.0, 2: -4.0, 3: 0.0, 4: 4.0, 5: 10.0};
  final base = map[response] ?? 0.0;
  return reversed ? -base : base;
}


// ── Question selection ────────────────────────────────────────────────────────

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
  for (final trait in [
    'openness',
    'conscientiousness',
    'extraversion',
    'agreeableness',
    'neuroticism',
  ]) {
    final pool = List<QuizQuestion>.from(byTrait[trait] ?? []);
    pool.shuffle(rng);
    selected.addAll(pool.take(countPerTrait));
  }

  selected.shuffle(rng);
  return selected;
}