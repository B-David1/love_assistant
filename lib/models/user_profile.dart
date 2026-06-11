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

  final DateTime? programStartDate;

  final DateTime? lastQuizDate;

  final Set<int> quizDaysCompleted;

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
  })  : favorites         = favorites         ?? {},
        blacklist         = blacklist         ?? {},
        quizDaysCompleted = quizDaysCompleted ?? {};

  bool get programStarted  => programStartDate != null;
  bool get programFinished =>
      programStarted && quizDaysCompleted.length >= programLength;

  int get currentProgramDay {
    if (programStartDate == null) return 0;
    final days = _today.difference(programStartDate!).inDays;
    return (days + 1).clamp(1, programLength + 1);
  }

  bool get canTakeQuizToday {
    if (!programStarted || programFinished) return false;
    if (lastQuizDate == null) return true;
    return lastQuizDate!.isBefore(_today);
  }

  int get nextQuizDay {
    for (var d = 1; d <= currentProgramDay && d <= programLength; d++) {
      if (!quizDaysCompleted.contains(d)) return d;
    }
    return currentProgramDay.clamp(1, programLength);
  }

  static DateTime get _today {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  OceanScores? get projectedScores =>
      quizDeltas != null ? oceanScores.applyDeltas(quizDeltas!) : null;

  List<MapEntry<String, int>> get topRatedPeople {
    final entries = personScores.entries
        .where((e) => !blacklist.contains(e.key))
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.take(5).toList();
  }

  List<MapEntry<String, int>> get bottomRatedPeople {
    final entries = personScores.entries
        .where((e) => !blacklist.contains(e.key))
        .toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    return entries.take(5).toList();
  }

  UserProfile copyWith({
    String?              name,
    String?              email,
    String?              profilePictureUrl,
    OceanScores?         oceanScores,
    Map<String, int>?    personScores,
    Set<String>?         favorites,
    Set<String>?         blacklist,
    List<String>?        analyzedPostIds,
    DateTime?            lastAnalyzed,
    int?                 totalCommentsAnalyzed,
    Map<String, double>? quizDeltas,
    bool                 clearQuizDeltas = false,
    DateTime?            programStartDate,
    DateTime?            lastQuizDate,
    Set<int>?            quizDaysCompleted,
    bool?                hasBeenAnalyzed,
    bool                 debugAdvanceDay = false,
  }) {
    DateTime? newStart = programStartDate ?? this.programStartDate;
    if (debugAdvanceDay && newStart != null) {
      newStart = newStart.subtract(const Duration(days: 1));
    }

    return UserProfile(
      userId:                userId,
      name:                  name                  ?? this.name,
      email:                 email                 ?? this.email,
      profilePictureUrl:     profilePictureUrl     ?? this.profilePictureUrl,
      oceanScores:           oceanScores           ?? this.oceanScores,
      personScores:          personScores          ?? this.personScores,
      favorites:             favorites             ?? this.favorites,
      blacklist:             blacklist             ?? this.blacklist,
      analyzedPostIds:       analyzedPostIds       ?? this.analyzedPostIds,
      lastAnalyzed:          lastAnalyzed          ?? this.lastAnalyzed,
      totalCommentsAnalyzed: totalCommentsAnalyzed ?? this.totalCommentsAnalyzed,
      quizDeltas:            clearQuizDeltas ? null : (quizDeltas ?? this.quizDeltas),
      programStartDate:      newStart,
      lastQuizDate:          lastQuizDate          ?? this.lastQuizDate,
      quizDaysCompleted:     quizDaysCompleted     ?? this.quizDaysCompleted,
      hasBeenAnalyzed:       hasBeenAnalyzed       ?? this.hasBeenAnalyzed,
    );
  }
}
