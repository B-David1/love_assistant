import 'package:flutter/material.dart';
import '../models/user_profile.dart';
import '../services/profile_storage_service.dart';
import '../services/quiz_question_service.dart';
import '../models/quiz_questions.dart';

// ── Screen ────────────────────────────────────────────────────────────────────

class QuizScreen extends StatefulWidget {
  final UserProfile profile;

  /// The program day being completed (1–30).
  final int dayNumber;

  const QuizScreen({super.key, required this.profile, required this.dayNumber});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen>
    with SingleTickerProviderStateMixin {
  final ProfileStorageService _profileStorage = ProfileStorageService();
  final QuizQuestionService _questionService = QuizQuestionService();

  late List<QuizQuestion> _questions;
  int _currentIndex = 0;
  final Map<int, int> _answers = {};
  bool _isSaving = false;
  bool _isLoadingQuestions = true;

  late final AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _questions = [];

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeIn);

    _loadQuestions();
  }

  Future<void> _loadQuestions() async {
    final loaded = await _questionService.selectQuestionsFromDb(
      countPerTrait: 6,
      seed: widget.dayNumber,
    );
    if (mounted) {
      setState(() {
        _questions = loaded;
        _isLoadingQuestions = false;
      });
      _animController.forward();
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  QuizQuestion get _current => _questions[_currentIndex];

  void _selectLikert(int response) async {
    setState(() => _answers[_currentIndex] = response);
    await Future.delayed(const Duration(milliseconds: 220));

    if (_currentIndex < _questions.length - 1) {
      _animController.reset();
      setState(() => _currentIndex++);
      _animController.forward();
    } else {
      await _finishQuiz();
    }
  }

  void _goBack() {
    if (_currentIndex > 0) {
      _animController.reset();
      setState(() => _currentIndex--);
      _animController.forward();
    }
  }

  void _skipForward() {
    if (_currentIndex < _questions.length - 1) {
      _animController.reset();
      setState(() => _currentIndex++);
      _animController.forward();
    } else {
      _finishQuiz();
    }
  }

  Future<void> _finishQuiz() async {
    setState(() => _isSaving = true);

    try {
      // Accumulate deltas — add to any existing deltas from previous days
      final existing = Map<String, double>.from(widget.profile.quizDeltas ?? {
        'openness': 0.0,
        'conscientiousness': 0.0,
        'extraversion': 0.0,
        'agreeableness': 0.0,
        'neuroticism': 0.0,
      });

      for (int qi = 0; qi < _questions.length; qi++) {
        final response = _answers[qi];
        if (response == null) continue; // skipped
        final q = _questions[qi];
        final delta = likertDelta(response, reversed: q.reversed);
        existing[q.trait] = (existing[q.trait] ?? 0) + delta;
      }

      final today = DateTime.now();
      final dateOnly = DateTime(today.year, today.month, today.day);
      final newDays = Set<int>.from(widget.profile.quizDaysCompleted)
        ..add(widget.dayNumber);

      // Set program start date on first quiz completion
      final programStart = widget.profile.programStartDate ?? dateOnly;

      final updated = widget.profile.copyWith(
        quizDeltas: existing,
        lastQuizDate: dateOnly,
        quizDaysCompleted: newDays,
        programStartDate: programStart,
      );
      await _profileStorage.saveUserProfile(updated);

      if (mounted) {
        setState(() => _isSaving = false);
        Navigator.of(context).pop(updated);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving quiz: $e')),
        );
      }
      debugPrint('Error in _finishQuiz: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isSaving || _isLoadingQuestions) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final q = _current;
    const traitColor = Colors.pink;
    final progress = (_currentIndex + 1) / _questions.length;

    return Scaffold(
      appBar: AppBar(
        title: Text('Day ${widget.dayNumber} / ${UserProfile.programLength}'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.pink.shade400),
            minHeight: 4,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 32),

              // ── Question text ─────────────────────────────────────
              FadeTransition(
                opacity: _fadeAnim,
                child: Text(
                  q.text,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    height: 1.4,
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // ── Instruction label ─────────────────────────────────
              FadeTransition(
                opacity: _fadeAnim,
                child: Text(
                  'How much do you agree with this statement?',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade500,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // ── Likert scale ──────────────────────────────────────
              Expanded(
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Endpoint labels
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Strongly\nDisagree',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade500,
                            ),
                          ),
                          Text(
                            'Strongly\nAgree',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Five circles in a row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: List.generate(5, (i) {
                          final value = i + 1; // 1–5
                          final selected = _answers[_currentIndex] == value;
                          return _LikertButton(
                            value: value,
                            isSelected: selected,
                            color: traitColor,
                            onTap: () => _selectLikert(value),
                          );
                        }),
                      ),

                      const SizedBox(height: 16),

                      // Number labels under circles
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: List.generate(5, (i) {
                          final value = i + 1;
                          return SizedBox(
                            width: 52,
                            child: Text(
                              value.toString(),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          );
                        }),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Navigation row ────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_currentIndex > 0)
                    TextButton.icon(
                      onPressed: _goBack,
                      icon: const Icon(Icons.arrow_back, size: 18),
                      label: const Text('Back'),
                      style: TextButton.styleFrom(
                          foregroundColor: Colors.grey.shade600),
                    )
                  else
                    const SizedBox(),
                  TextButton(
                    onPressed: _skipForward,
                    style: TextButton.styleFrom(
                        foregroundColor: Colors.grey.shade500),
                    child: Text(
                      _currentIndex < _questions.length - 1 ? 'Skip' : 'Finish',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Likert button ─────────────────────────────────────────────────────────────

class _LikertButton extends StatelessWidget {
  final int value;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;

  const _LikertButton({
    required this.value,
    required this.isSelected,
    required this.color,
    required this.onTap,
  });

  // Circle size scales slightly with value to give a visual hint of magnitude.
  double get _size => 44.0 + (value - 3) * 2.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: _size,
        height: _size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isSelected ? color : Colors.transparent,
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade400,
            width: isSelected ? 2.5 : 1.5,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: color.withValues(alpha: 0.25), blurRadius: 8, spreadRadius: 1)]
              : [],
        ),
        child: Center(
          child: isSelected
              ? const Icon(Icons.check, color: Colors.white, size: 18)
              : null,
        ),
      ),
    );
  }
}