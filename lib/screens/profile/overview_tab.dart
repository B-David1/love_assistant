import 'package:flutter/material.dart';
import '../../models/user_profile.dart';
import '../../models/person_score.dart';
import '../../widgets/person_score_tile.dart';

class OverviewTab extends StatelessWidget {
  final UserProfile profile;
  final List<MapEntry<String, int>> topPeople;
  final double averageRating;

  const OverviewTab({
    super.key,
    required this.profile,
    required this.topPeople,
    required this.averageRating,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stats row 1
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  title: 'People Analyzed',
                  value: '${profile.personScores.length}',
                  icon: Icons.people,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  title: 'Comments Analyzed',
                  value: '${profile.totalCommentsAnalyzed}',
                  icon: Icons.comment,
                  color: Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Stats row 2
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  title: 'Average Rating',
                  value: averageRating > 0
                      ? averageRating.toStringAsFixed(1)
                      : 'N/A',
                  icon: Icons.star,
                  color: Colors.orange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  title: 'Posts Analyzed',
                  value: '${profile.analyzedPostIds.length}',
                  icon: Icons.article,
                  color: Colors.purple,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Top rated people
          if (topPeople.isNotEmpty) ...[
            const Text(
              'Top Rated People',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...topPeople.map((entry) => PersonScoreTile(
                  score: PersonScore(name: entry.key, score: entry.value),
                  rank: topPeople.indexOf(entry) + 1,
                )),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Text(
                  'No ratings yet. Fetch and analyze posts to see ratings.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Stat card ─────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
