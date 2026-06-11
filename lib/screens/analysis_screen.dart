import 'package:flutter/material.dart';

import '../models/person_score.dart';

class AnalysisScreen extends StatefulWidget {
  final List<PersonScore> scores;

  const AnalysisScreen({super.key, required this.scores});

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> {
  final Set<int> _expanded = {};

  List<PersonScore> get _sorted => (List.of(widget.scores)
        ..removeWhere((s) => s.isBlacklisted)
        ..sort((a, b) => b.score.compareTo(a.score)));

  @override
  Widget build(BuildContext context) {
    final scores = _sorted;

    return Scaffold(
      appBar: AppBar(title: const Text('Analysis Results')),
      body: scores.isEmpty
          ? const _EmptyState()
          : Column(
              children: [
                _SummaryBanner(count: scores.length),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: scores.length,
                    itemBuilder: (_, i) => _PersonCard(
                      score:      scores[i],
                      rank:       i + 1,
                      isExpanded: _expanded.contains(i),
                      onTap:      () => setState(() =>
                          _expanded.contains(i)
                              ? _expanded.remove(i)
                              : _expanded.add(i)),
                      onFlagChanged: () => setState(() {}),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.analytics_outlined, size: 80, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text('No results available',
              style: TextStyle(fontSize: 18, color: Colors.grey.shade600)),
        ],
      ),
    );
  }
}

class _SummaryBanner extends StatelessWidget {
  final int count;
  const _SummaryBanner({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Colors.blue.shade50,
      child: Row(
        children: [
          Icon(Icons.people, color: Colors.blue.shade700),
          const SizedBox(width: 12),
          Text(
            '$count people analysed',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: Colors.blue.shade900),
          ),
        ],
      ),
    );
  }
}

class _PersonCard extends StatelessWidget {
  final PersonScore score;
  final int rank;
  final bool isExpanded;
  final VoidCallback onTap;
  final VoidCallback onFlagChanged;

  const _PersonCard({
    required this.score,
    required this.rank,
    required this.isExpanded,
    required this.onTap,
    required this.onFlagChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: score.scoreColor.withValues(alpha: 0.15),
                    child: Text(
                      rank.toString(),
                      style: TextStyle(
                          color: score.scoreColor,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(score.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15)),
                            ),
                            if (score.isFavorite)
                              const Icon(Icons.star,
                                  color: Colors.amber, size: 16),
                            if (score.isBlacklisted)
                              const Icon(Icons.block,
                                  color: Colors.red, size: 16),
                          ],
                        ),
                        const SizedBox(height: 4),
                        SizedBox(
                          width: 120,
                          child: LinearProgressIndicator(
                            value: score.score / 100,
                            backgroundColor: Colors.grey.shade200,
                            valueColor: AlwaysStoppedAnimation(score.scoreColor),
                            borderRadius: BorderRadius.circular(8),
                            minHeight: 6,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: score.scoreColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${score.score}/100',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: score.scoreColor,
                          fontSize: 16),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.grey.shade500,
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('OCEAN Personality Traits',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade700)),
                  const SizedBox(height: 12),
                  _OceanBar('Openness',          score.oceanTraits.openness,          const Color(0xFF00897B), 'Open to new experiences'),
                  _OceanBar('Conscientiousness', score.oceanTraits.conscientiousness, const Color(0xFF1E88E5), 'Organised & disciplined'),
                  _OceanBar('Extraversion',      score.oceanTraits.extraversion,      const Color(0xFFEF6C00), 'Outgoing & energetic'),
                  _OceanBar('Agreeableness',     score.oceanTraits.agreeableness,     const Color(0xFF43A047), 'Cooperative & compassionate'),
                  _OceanBar('Neuroticism',       score.oceanTraits.neuroticism,       const Color(0xFF8E24AA), 'Emotional sensitivity'),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _FlagButton(
                        icon:  score.isFavorite ? Icons.star : Icons.star_outline,
                        label: score.isFavorite ? 'Favourited' : 'Favourite',
                        color: score.isFavorite ? Colors.amber : Colors.grey,
                        onPressed: () {
                          score.isFavorite = !score.isFavorite;
                          onFlagChanged();
                        },
                      ),
                      _FlagButton(
                        icon:  score.isBlacklisted ? Icons.block : Icons.block_outlined,
                        label: score.isBlacklisted ? 'Blacklisted' : 'Blacklist',
                        color: score.isBlacklisted ? Colors.red : Colors.grey,
                        onPressed: () {
                          score.isBlacklisted = !score.isBlacklisted;
                          onFlagChanged();
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _OceanBar extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  final String description;

  const _OceanBar(this.label, this.value, this.color, this.description);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w500)),
              Text('$value/100',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: color)),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: value / 100,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation(color),
            borderRadius: BorderRadius.circular(8),
            minHeight: 6,
          ),
          const SizedBox(height: 2),
          Text(description,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
        ],
      ),
    );
  }
}

class _FlagButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onPressed;

  const _FlagButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
      style: ElevatedButton.styleFrom(
          backgroundColor: color, foregroundColor: Colors.white),
    );
  }
}
