import 'package:flutter/material.dart';
import '../models/person_score.dart';

class AnalysisScreen extends StatefulWidget {
  final List<PersonScore> scores;

  const AnalysisScreen({super.key, required this.scores});

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> {
  final Set<int> _expandedIndices = {};

  @override
  Widget build(BuildContext context) {
    final filteredScores = List<PersonScore>.from(widget.scores)
      ..removeWhere((s) => s.isBlacklisted)
      ..sort((a, b) => b.score.compareTo(a.score));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analysis Results'),
      ),
      body: widget.scores.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.analytics_outlined,
                    size: 80,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No scores available',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.blue.shade50,
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue.shade700),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '${filteredScores.length} people analyzed',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.blue.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredScores.length,
                    itemBuilder: (context, index) {
                      final score = filteredScores[index];
                      final isExpanded = _expandedIndices.contains(index);
                      
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    if (_expandedIndices.contains(index)) {
                                      _expandedIndices.remove(index);
                                    } else {
                                      _expandedIndices.add(index);
                                    }
                                  });
                                },
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: score.scoreColor.withOpacity(0.2),
                                      child: Text(
                                        score.name[0].toUpperCase(),
                                        style: TextStyle(
                                          color: score.scoreColor,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  score.name,
                                                  style: const TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                              if (score.isFavorite)
                                                const Icon(Icons.star, color: Colors.amber, size: 18),
                                              if (score.isBlacklisted)
                                                const Icon(Icons.block, color: Colors.red, size: 18),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            score.interpretation,
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: score.scoreColor.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(20),
                                          ),
                                          child: Text(
                                            '${score.score}/100',
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: score.scoreColor,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        SizedBox(
                                          width: 100,
                                          child: LinearProgressIndicator(
                                            value: score.score / 100,
                                            backgroundColor: Colors.grey.shade200,
                                            valueColor: AlwaysStoppedAnimation<Color>(
                                              score.scoreColor,
                                            ),
                                            borderRadius: BorderRadius.circular(10),
                                            minHeight: 8,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(width: 12),
                                    Icon(
                                      isExpanded ? Icons.expand_less : Icons.expand_more,
                                      color: Colors.grey.shade600,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (isExpanded) ...[
                              const Divider(height: 1),
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Personality Traits (OCEAN)',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    _buildOceanTrait(
                                      'Openness',
                                      score.oceanTraits.openness,
                                      Colors.purple,
                                      'Open to new experiences',
                                    ),
                                    const SizedBox(height: 10),
                                    _buildOceanTrait(
                                      'Conscientiousness',
                                      score.oceanTraits.conscientiousness,
                                      Colors.blue,
                                      'Organized & disciplined',
                                    ),
                                    const SizedBox(height: 10),
                                    _buildOceanTrait(
                                      'Extraversion',
                                      score.oceanTraits.extraversion,
                                      Colors.green,
                                      'Outgoing & energetic',
                                    ),
                                    const SizedBox(height: 10),
                                    _buildOceanTrait(
                                      'Agreeableness',
                                      score.oceanTraits.agreeableness,
                                      Colors.orange,
                                      'Cooperative & compassionate',
                                    ),
                                    const SizedBox(height: 10),
                                    _buildOceanTrait(
                                      'Neuroticism',
                                      score.oceanTraits.neuroticism,
                                      Colors.red,
                                      'Emotional sensitivity',
                                    ),
                                    const SizedBox(height: 16),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                      children: [
                                        ElevatedButton.icon(
                                          onPressed: () {
                                            setState(() {
                                              score.isFavorite = !score.isFavorite;
                                            });
                                          },
                                          icon: Icon(
                                            score.isFavorite ? Icons.star : Icons.star_outline,
                                          ),
                                          label: Text(
                                            score.isFavorite ? 'Favorited' : 'Favorite',
                                          ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: score.isFavorite ? Colors.amber : Colors.grey,
                                            foregroundColor: Colors.white,
                                          ),
                                        ),
                                        ElevatedButton.icon(
                                          onPressed: () {
                                            setState(() {
                                              score.isBlacklisted = !score.isBlacklisted;
                                            });
                                          },
                                          icon: Icon(
                                            score.isBlacklisted ? Icons.block : Icons.block_outlined,
                                          ),
                                          label: Text(
                                            score.isBlacklisted ? 'Blacklisted' : 'Blacklist',
                                          ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: score.isBlacklisted ? Colors.red : Colors.grey,
                                            foregroundColor: Colors.white,
                                          ),
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
                    },
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildOceanTrait(
    String label,
    int value,
    Color color,
    String description,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              '$value/100',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: value / 100,
          backgroundColor: Colors.grey.shade200,
          valueColor: AlwaysStoppedAnimation<Color>(color),
          borderRadius: BorderRadius.circular(8),
          minHeight: 6,
        ),
        const SizedBox(height: 3),
        Text(
          description,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade500,
          ),
        ),
      ],
    );
  }
}