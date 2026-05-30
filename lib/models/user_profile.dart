import 'ocean_scores.dart';

class UserProfile {
  final String userId;
  final String name;
  final String? email;
  final String? profilePictureUrl;
  final OceanScores oceanScores;
  final Map<String, int> personScores;
  final Set<String> favorites;
  final Set<String> blacklist;
  final List<String> analyzedPostIds;
  final DateTime lastAnalyzed;
  final int totalCommentsAnalyzed;
  final Map<String, double>? quizDeltas;

  // ── 30-day program ────────────────────────────────────────────────────────
  /// The calendar date the user started the program (date-only, no time).
  /// null means the program has not started yet.
  final DateTime? programStartDate;

  /// The calendar date of the last completed quiz (date-only).
  final DateTime? lastQuizDate;

  /// Which program days (1–30) have been completed.
  final Set<int> quizDaysCompleted;

  /// True once the user has run at least one personality analysis.
  /// Used to hide the re-analyze button and show the quiz card instead.
  final bool hasBeenAnalyzed;

  static const int programLength = 30;

  UserProfile({
    required this.userId,
    required this.name,
    this.email,
    this.profilePictureUrl,
    required this.oceanScores,
    required this.personScores,
    Set<String>? favorites,
    Set<String>? blacklist,
    required this.analyzedPostIds,
    required this.lastAnalyzed,
    required this.totalCommentsAnalyzed,
    this.quizDeltas,
    this.programStartDate,
    this.lastQuizDate,
    Set<int>? quizDaysCompleted,
    this.hasBeenAnalyzed = false,
  })  : favorites = favorites ?? {},
        blacklist = blacklist ?? {},
        quizDaysCompleted = quizDaysCompleted ?? {};

  // ── Program helpers ───────────────────────────────────────────────────────

  bool get programStarted => programStartDate != null;

  bool get programFinished =>
      programStarted && quizDaysCompleted.length >= programLength;

  /// Current program day (1-based). Returns 0 if not started.
  int get currentProgramDay {
    if (programStartDate == null) return 0;
    final today = _dateOnly(DateTime.now());
    final daysSinceStart = today.difference(programStartDate!).inDays;
    return (daysSinceStart + 1).clamp(1, programLength + 1);
  }

  /// Whether the quiz is available today (not yet done today, program active,
  /// not finished).
  bool get canTakeQuizToday {
    if (!programStarted || programFinished) return false;
    if (lastQuizDate == null) return true;
    final today = _dateOnly(DateTime.now());
    return lastQuizDate!.isBefore(today);
  }

  /// Next day number to complete (lowest not-yet-done day ≤ currentProgramDay).
  int get nextQuizDay {
    for (int d = 1; d <= currentProgramDay && d <= programLength; d++) {
      if (!quizDaysCompleted.contains(d)) return d;
    }
    return currentProgramDay.clamp(1, programLength);
  }

  static DateTime _dateOnly(DateTime dt) =>
      DateTime(dt.year, dt.month, dt.day);

  // ── Serialisation ─────────────────────────────────────────────────────────
  // fromJson / toJson removed — storage is handled field-by-field in
  // ProfileStorageService with per-field encryption.

  OceanScores? get projectedScores =>
      quizDeltas != null ? oceanScores.applyDeltas(quizDeltas!) : null;

  UserProfile copyWith({
    Set<String>? favorites,
    Set<String>? blacklist,
    Map<String, double>? quizDeltas,
    bool clearQuizDeltas = false,
    OceanScores? oceanScores,
    DateTime? programStartDate,
    DateTime? lastQuizDate,
    Set<int>? quizDaysCompleted,
    // Pass true to advance the simulated date by one day (debug only)
    bool debugAdvanceDay = false,
    bool? hasBeenAnalyzed,
  }) {
    DateTime? newStart = programStartDate ?? this.programStartDate;
    if (debugAdvanceDay && newStart != null) {
      newStart = newStart.subtract(const Duration(days: 1));
    }
    return UserProfile(
      userId: userId,
      name: name,
      email: email,
      profilePictureUrl: profilePictureUrl,
      oceanScores: oceanScores ?? this.oceanScores,
      personScores: personScores,
      favorites: favorites ?? this.favorites,
      blacklist: blacklist ?? this.blacklist,
      analyzedPostIds: analyzedPostIds,
      lastAnalyzed: lastAnalyzed,
      totalCommentsAnalyzed: totalCommentsAnalyzed,
      quizDeltas: clearQuizDeltas ? null : (quizDeltas ?? this.quizDeltas),
      programStartDate: newStart,
      lastQuizDate: lastQuizDate ?? this.lastQuizDate,
      quizDaysCompleted: quizDaysCompleted ?? this.quizDaysCompleted,
      hasBeenAnalyzed: hasBeenAnalyzed ?? this.hasBeenAnalyzed,
    );
  }

  List<MapEntry<String, int>> get topRatedPeople {
    final entries = personScores.entries
        .where((e) => !blacklist.contains(e.key))
        .toList();
    entries.sort((a, b) => b.value.compareTo(a.value));
    return entries.take(5).toList();
  }

  List<MapEntry<String, int>> get bottomRatedPeople {
    final entries = personScores.entries
        .where((e) => !blacklist.contains(e.key))
        .toList();
    entries.sort((a, b) => a.value.compareTo(b.value));
    return entries.take(5).toList();
  }
}