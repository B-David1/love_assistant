import 'dart:io';
import 'package:flutter/material.dart';
import '../../models/user_profile.dart';
import '../../widgets/ocean_spider_chart.dart';
import '../../screens/activity_checklist_screen.dart';

class PersonalityTab extends StatelessWidget {
  final UserProfile profile;
  final bool isAnalyzing;
  final Duration timeUntilMidnight;

  /// Called when the user taps "Analyze" or "Re-analyze".
  final VoidCallback onAnalyze;

  /// Called when the user taps "Start / Take Quiz".
  final VoidCallback onOpenQuiz;

  /// Called when the user taps "Go Fetch Posts" (navigates back).
  final VoidCallback onGoFetchPosts;

  /// Debug-only: advance the simulated day (Windows only).
  final VoidCallback onDebugNextDay;

  /// Debug-only: instantly mark all 30 quiz days as complete (Windows only).
  final VoidCallback onDebugCompleteQuiz;

  const PersonalityTab({
    super.key,
    required this.profile,
    required this.isAnalyzing,
    required this.timeUntilMidnight,
    required this.onAnalyze,
    required this.onOpenQuiz,
    required this.onGoFetchPosts,
    required this.onDebugNextDay,
    required this.onDebugCompleteQuiz,
  });

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// True if the user has ever run an analysis (all-50 = never analyzed).
  bool get _hasAnalyzed {
    final o = profile.oceanScores;
    return !(o.openness == 50 &&
        o.conscientiousness == 50 &&
        o.extraversion == 50 &&
        o.agreeableness == 50 &&
        o.neuroticism == 50);
  }

  @override
  Widget build(BuildContext context) {
    final hasPosts = profile.analyzedPostIds.isNotEmpty;

    // ── State 0: no posts fetched yet ────────────────────────────────────────
    if (!hasPosts) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.cloud_download_outlined,
                  size: 80, color: Colors.grey.shade300),
              const SizedBox(height: 24),
              const Text(
                'No Posts Yet',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Fetch your Facebook posts first so your comments can be '
                'analyzed for personality insights.',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: onGoFetchPosts,
                icon: const Icon(Icons.arrow_back),
                label: const Text('Go Fetch Posts'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade400,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 28, vertical: 14),
                  textStyle: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // ── State 1: posts exist but no analysis run yet ──────────────────────────
    if (!_hasAnalyzed) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.psychology_outlined,
                  size: 80, color: Colors.pink.shade200),
              const SizedBox(height: 24),
              const Text(
                'Discover Your Personality',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Run an analysis of your Facebook comments to generate your '
                'Big Five (OCEAN) personality profile.',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: isAnalyzing ? null : onAnalyze,
                icon: isAnalyzing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.psychology),
                label: Text(
                    isAnalyzing ? 'Analyzing...' : 'Analyze My Personality'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.pink.shade400,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 28, vertical: 14),
                  textStyle: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // ── States 2 & 3: analysis exists ────────────────────────────────────────

    // Show the re-analyze button only when:
    //   • The user has never analyzed before (hasBeenAnalyzed == false), OR
    //   • The quiz program is fully completed (30/30 days done).
    // While the program is active the button is hidden and the quiz card
    // is shown in its place instead.
    final showReanalyze =
        !profile.hasBeenAnalyzed || profile.programFinished;
    final showQuizCard = profile.hasBeenAnalyzed && !profile.programFinished;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Legend ────────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 20,
              runSpacing: 6,
              children: [
                _legendItem(Colors.pink.shade700, 'Current', solid: true),
                _legendItem(Colors.grey.shade400, 'Target (75)', solid: false),
                if (profile.projectedScores != null)
                  _legendItem(Colors.deepPurple.shade300, 'Quiz Projection',
                      solid: false),
              ],
            ),
          ),

          Center(
            child: OceanSpiderChart(
              scores: profile.oceanScores,
              projectedScores: profile.projectedScores,
              size: 300,
            ),
          ),

          const SizedBox(height: 24),

          // ── Info banner ───────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline,
                    color: Colors.blue.shade700, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'The dashed grey line shows the recommended target '
                    '(75/100). The purple dotted line shows your quiz '
                    'projection.',
                    style:
                        TextStyle(fontSize: 12, color: Colors.blue.shade900),
                  ),
                ),
              ],
            ),
          ),

          // ── Re-analyze button OR quiz card (mutually exclusive) ───────────
          if (showReanalyze) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: isAnalyzing ? null : onAnalyze,
                icon: isAnalyzing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.refresh, size: 18),
                label: Text(
                    isAnalyzing ? 'Analyzing...' : 'Re-analyze Personality'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.pink.shade400,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  textStyle: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ] else if (showQuizCard) ...[
            if (!profile.programStarted) ...[
              _StartProgramCard(onStart: onOpenQuiz),
            ] else ...[
              _ProgramCard(
                profile: profile,
                timeUntilMidnight: timeUntilMidnight,
                onOpenQuiz: onOpenQuiz,
                onDebugNextDay: onDebugNextDay,
                onDebugCompleteQuiz: onDebugCompleteQuiz,
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        ActivityChecklistScreen(profile: profile),
                  ),
                ),
                icon: const Icon(Icons.checklist_rounded),
                label: const Text('Personality Checklist'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.pink.shade700,
                  side: BorderSide(color: Colors.pink.shade300),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  textStyle: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // ── Trait cards ───────────────────────────────────────────────────
          _TraitCard(
            title: 'Openness',
            score: profile.oceanScores.openness,
            target: 75,
            description: 'Curiosity, creativity, open-mindedness',
            color: Colors.teal,
            projected: profile.projectedScores?.openness,
          ),
          const SizedBox(height: 12),
          _TraitCard(
            title: 'Conscientiousness',
            score: profile.oceanScores.conscientiousness,
            target: 75,
            description: 'Organization, dependability, discipline',
            color: Colors.blue,
            projected: profile.projectedScores?.conscientiousness,
          ),
          const SizedBox(height: 12),
          _TraitCard(
            title: 'Extraversion',
            score: profile.oceanScores.extraversion,
            target: 75,
            description: 'Sociability, energy, assertiveness',
            color: Colors.orange,
            projected: profile.projectedScores?.extraversion,
          ),
          const SizedBox(height: 12),
          _TraitCard(
            title: 'Agreeableness',
            score: profile.oceanScores.agreeableness,
            target: 75,
            description: 'Compassion, cooperation, trust',
            color: Colors.green,
            projected: profile.projectedScores?.agreeableness,
          ),
          const SizedBox(height: 12),
          _TraitCard(
            title: 'Emotional Stability',
            score: 100 - profile.oceanScores.neuroticism,
            target: 75,
            description: 'Calmness, resilience, stress management',
            color: Colors.purple,
            projected: profile.projectedScores != null
                ? 100 - profile.projectedScores!.neuroticism
                : null,
          ),
        ],
      ),
    );
  }

  // ── Legend item ───────────────────────────────────────────────────────────

  Widget _legendItem(Color color, String label, {required bool solid}) {
    return Row(children: [
      Container(
        width: 20,
        height: 2,
        decoration: BoxDecoration(
          color: solid ? color : Colors.transparent,
          border: solid
              ? null
              : Border(
                  bottom: BorderSide(
                    color: color,
                    width: 2,
                    style: BorderStyle.solid,
                  ),
                ),
        ),
        child: solid ? null : CustomPaint(painter: _DashPainter(color: color)),
      ),
      const SizedBox(width: 6),
      Text(label, style: const TextStyle(fontSize: 12)),
    ]);
  }
}

// ── Trait card ────────────────────────────────────────────────────────────────

class _TraitCard extends StatelessWidget {
  final String title;
  final double score;
  final double target;
  final String description;
  final Color color;
  final double? projected;

  const _TraitCard({
    required this.title,
    required this.score,
    required this.target,
    required this.description,
    required this.color,
    this.projected,
  });

  @override
  Widget build(BuildContext context) {
    final isAboveTarget = score >= target;
    final difference = (score - target).abs();
    final delta = projected != null ? projected! - score : null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade100,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${score.toStringAsFixed(0)}/100',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, color: color),
                    ),
                  ),
                  if (delta != null) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: delta >= 0
                            ? Colors.deepPurple.shade50
                            : Colors.red.shade50,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        delta >= 0
                            ? '+${delta.toStringAsFixed(1)} quiz'
                            : '${delta.toStringAsFixed(1)} quiz',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: delta >= 0
                              ? Colors.deepPurple.shade600
                              : Colors.red.shade600,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Target: ${target.toStringAsFixed(0)}',
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey.shade600),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              return Stack(
                children: [
                  LinearProgressIndicator(
                    value: score / 100,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  Positioned(
                    left: (target / 100) * constraints.maxWidth,
                    top: 0,
                    child: Container(
                        width: 2, height: 8, color: Colors.grey.shade800),
                  ),
                ],
              );
            },
          ),
          if (projected != null) ...[
            const SizedBox(height: 6),
            LayoutBuilder(
              builder: (context, constraints) {
                return Stack(
                  children: [
                    LinearProgressIndicator(
                      value: projected! / 100,
                      backgroundColor: Colors.transparent,
                      valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.deepPurple.shade200),
                      minHeight: 4,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    Positioned(
                      left: (target / 100) * constraints.maxWidth,
                      top: 0,
                      child: Container(
                          width: 2,
                          height: 4,
                          color: Colors.grey.shade800),
                    ),
                  ],
                );
              },
            ),
          ],
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(description,
                  style:
                      TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isAboveTarget
                      ? Colors.green.shade50
                      : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isAboveTarget
                      ? '+${difference.toStringAsFixed(0)} above target'
                      : '${difference.toStringAsFixed(0)} below target',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: isAboveTarget
                        ? Colors.green.shade700
                        : Colors.orange.shade700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── "Start program" invitation card ──────────────────────────────────────────

class _StartProgramCard extends StatelessWidget {
  final VoidCallback onStart;
  const _StartProgramCard({required this.onStart});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.deepPurple.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.deepPurple.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.local_fire_department,
                  color: Colors.deepPurple.shade400),
              const SizedBox(width: 8),
              Text(
                'Want to improve your scores?',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.deepPurple.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Start the 30-day quiz program to track and improve your '
            'personality traits over time.',
            style: TextStyle(fontSize: 13, color: Colors.deepPurple.shade600),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: onStart,
            icon: const Icon(Icons.play_arrow, size: 18),
            label: const Text('Start 30-Day Program'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.deepPurple,
              side: const BorderSide(color: Colors.deepPurple),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Active program card ───────────────────────────────────────────────────────

class _ProgramCard extends StatelessWidget {
  final UserProfile profile;
  final Duration timeUntilMidnight;
  final VoidCallback onOpenQuiz;
  final VoidCallback onDebugNextDay;
  final VoidCallback onDebugCompleteQuiz;

  const _ProgramCard({
    required this.profile,
    required this.timeUntilMidnight,
    required this.onOpenQuiz,
    required this.onDebugNextDay,
    required this.onDebugCompleteQuiz,
  });

  @override
  Widget build(BuildContext context) {
    final p = profile;
    final daysCompleted = p.quizDaysCompleted.length;
    final progress = daysCompleted / UserProfile.programLength;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.deepPurple.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.deepPurple.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.local_fire_department,
                  color: Colors.deepPurple.shade400),
              const SizedBox(width: 8),
              Text(
                '30-Day Personality Program',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.deepPurple.shade700,
                ),
              ),
              const Spacer(),
              Text(
                '$daysCompleted / ${UserProfile.programLength}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.deepPurple.shade600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: Colors.deepPurple.shade100,
              valueColor:
                  AlwaysStoppedAnimation<Color>(Colors.deepPurple.shade400),
            ),
          ),
          const SizedBox(height: 12),
          if (p.programFinished) ...[
            Row(
              children: [
                Icon(Icons.check_circle,
                    color: Colors.green.shade600, size: 18),
                const SizedBox(width: 6),
                Text(
                  'Program complete! Personality analysis is unlocked.',
                  style: TextStyle(
                      fontSize: 12,
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ] else if (p.canTakeQuizToday) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Day ${p.nextQuizDay} quiz is ready!',
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.deepPurple.shade700,
                        fontWeight: FontWeight.w500),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: onOpenQuiz,
                  icon: const Icon(Icons.quiz_outlined, size: 16),
                  label: Text('Take Day ${p.nextQuizDay} Quiz'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.deepPurple,
                    side: const BorderSide(color: Colors.deepPurple),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    textStyle: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          ] else ...[
            _CountdownRow(
                profile: p, timeUntilMidnight: timeUntilMidnight),
          ],

          // Debug buttons (Windows only)
          if (Platform.isWindows) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: onDebugNextDay,
                  icon: const Icon(Icons.fast_forward, size: 16),
                  label: const Text('[Debug] Next Day'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.orange.shade700,
                    side: BorderSide(color: Colors.orange.shade300),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: onDebugCompleteQuiz,
                  icon: const Icon(Icons.done_all, size: 16),
                  label: const Text('[Debug] Complete Quiz'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.orange.shade700,
                    side: BorderSide(color: Colors.orange.shade300),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ],

          if (p.quizDeltas != null) ...[
            const SizedBox(height: 8),
            Text(
              'Quiz results shown as purple dotted line on the chart.',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Countdown row ─────────────────────────────────────────────────────────────

class _CountdownRow extends StatelessWidget {
  final UserProfile profile;
  final Duration timeUntilMidnight;

  const _CountdownRow(
      {required this.profile, required this.timeUntilMidnight});

  @override
  Widget build(BuildContext context) {
    final h = timeUntilMidnight.inHours;
    final m = timeUntilMidnight.inMinutes
        .remainder(60)
        .toString()
        .padLeft(2, '0');
    final s = timeUntilMidnight.inSeconds
        .remainder(60)
        .toString()
        .padLeft(2, '0');

    return Row(
      children: [
        Icon(Icons.schedule, color: Colors.grey.shade500, size: 16),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            'Day ${profile.nextQuizDay} quiz available in',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ),
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.deepPurple.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.deepPurple.shade200),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.timer_outlined,
                  size: 14, color: Colors.deepPurple.shade400),
              const SizedBox(width: 4),
              Text(
                '$h:$m:$s',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.deepPurple.shade700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Legend dash painter ───────────────────────────────────────────────────────

class _DashPainter extends CustomPainter {
  final Color color;
  const _DashPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    double x = 0;
    while (x < size.width) {
      canvas.drawLine(
        Offset(x, size.height / 2),
        Offset((x + 4).clamp(0, size.width), size.height / 2),
        paint,
      );
      x += 8;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}