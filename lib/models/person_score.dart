import 'package:flutter/material.dart';

class OceanTraits {
  final int openness;
  final int conscientiousness;
  final int extraversion;
  final int agreeableness;
  final int neuroticism;

  const OceanTraits({
    required this.openness,
    required this.conscientiousness,
    required this.extraversion,
    required this.agreeableness,
    required this.neuroticism,
  });

  factory OceanTraits.neutral() => const OceanTraits(
        openness: 50, conscientiousness: 50, extraversion: 50,
        agreeableness: 50, neuroticism: 50,
      );

  factory OceanTraits.fromJson(Map<String, dynamic> json) => OceanTraits(
        openness:          (json['openness']          as num?)?.toInt() ?? 50,
        conscientiousness: (json['conscientiousness'] as num?)?.toInt() ?? 50,
        extraversion:      (json['extraversion']      as num?)?.toInt() ?? 50,
        agreeableness:     (json['agreeableness']     as num?)?.toInt() ?? 50,
        neuroticism:       (json['neuroticism']       as num?)?.toInt() ?? 50,
      );

  Map<String, dynamic> toJson() => {
        'openness':          openness,
        'conscientiousness': conscientiousness,
        'extraversion':      extraversion,
        'agreeableness':     agreeableness,
        'neuroticism':       neuroticism,
      };
}

class PersonScore {
  final String name;
  final int score;
  final OceanTraits oceanTraits;
  bool isFavorite;
  bool isBlacklisted;

  PersonScore({
    required this.name,
    required this.score,
    OceanTraits? oceanTraits,
    this.isFavorite    = false,
    this.isBlacklisted = false,
  }) : oceanTraits = oceanTraits ?? OceanTraits.neutral();

  factory PersonScore.fromJson(Map<String, dynamic> json) => PersonScore(
        name:       json['person'] as String,
        score:      (json['score'] as num).toInt(),
        oceanTraits: json['ocean'] != null
            ? OceanTraits.fromJson(json['ocean'] as Map<String, dynamic>)
            : OceanTraits.neutral(),
        isFavorite:    json['isFavorite']    as bool? ?? false,
        isBlacklisted: json['isBlacklisted'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'person':       name,
        'score':        score,
        'ocean':        oceanTraits.toJson(),
        'isFavorite':   isFavorite,
        'isBlacklisted': isBlacklisted,
      };

  Color get scoreColor {
    if (score >= 80) return Colors.green.shade600;
    if (score >= 60) return Colors.lightGreen.shade600;
    if (score >= 40) return Colors.orange;
    if (score >= 20) return Colors.red;
    return Colors.red.shade900;
  }

  String get oceanSummary =>
      'O:${oceanTraits.openness} C:${oceanTraits.conscientiousness} '
      'E:${oceanTraits.extraversion} A:${oceanTraits.agreeableness} '
      'N:${oceanTraits.neuroticism}';
}
