import 'package:flutter/material.dart';

class OceanTraits {
  final int openness;        // Openness to experience
  final int conscientiousness; // Conscientiousness
  final int extraversion;    // Extraversion
  final int agreeableness;   // Agreeableness
  final int neuroticism;     // Neuroticism

  OceanTraits({
    required this.openness,
    required this.conscientiousness,
    required this.extraversion,
    required this.agreeableness,
    required this.neuroticism,
  });

  factory OceanTraits.fromJson(Map<String, dynamic> json) {
    return OceanTraits(
      openness: (json['openness'] as num?)?.toInt() ?? 50,
      conscientiousness: (json['conscientiousness'] as num?)?.toInt() ?? 50,
      extraversion: (json['extraversion'] as num?)?.toInt() ?? 50,
      agreeableness: (json['agreeableness'] as num?)?.toInt() ?? 50,
      neuroticism: (json['neuroticism'] as num?)?.toInt() ?? 50,
    );
  }

  factory OceanTraits.neutral() {
    return OceanTraits(
      openness: 50,
      conscientiousness: 50,
      extraversion: 50,
      agreeableness: 50,
      neuroticism: 50,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'openness': openness,
      'conscientiousness': conscientiousness,
      'extraversion': extraversion,
      'agreeableness': agreeableness,
      'neuroticism': neuroticism,
    };
  }
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
    this.isFavorite = false,
    this.isBlacklisted = false,
  }) : oceanTraits = oceanTraits ?? OceanTraits.neutral();

  factory PersonScore.fromJson(Map<String, dynamic> json) {
    return PersonScore(
      name: json['person'] as String,
      score: (json['score'] as num).toInt(),
      oceanTraits: json.containsKey('ocean') 
          ? OceanTraits.fromJson(json['ocean'] as Map<String, dynamic>)
          : OceanTraits.neutral(),
      isFavorite: json['isFavorite'] as bool? ?? false,
      isBlacklisted: json['isBlacklisted'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'person': name,
      'score': score,
      'ocean': oceanTraits.toJson(),
      'isFavorite': isFavorite,
      'isBlacklisted': isBlacklisted,
    };
  }

  String get interpretation {
    if (score == 50) return 'Neutral';
    if (score < 50) return 'Negative ($score/100)';
    return 'Positive ($score/100)';
  }

  Color get scoreColor {
    if (score == 50) return Colors.grey;
    if (score < 50) return Colors.red;
    return Colors.green;
  }

  String get oceanSummary {
    return 'O:${oceanTraits.openness} C:${oceanTraits.conscientiousness} E:${oceanTraits.extraversion} A:${oceanTraits.agreeableness} N:${oceanTraits.neuroticism}';
  }
}