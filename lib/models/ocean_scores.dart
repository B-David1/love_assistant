class OceanScores {
  final double openness;
  final double conscientiousness;
  final double extraversion;
  final double agreeableness;
  final double neuroticism;

  OceanScores({
    required this.openness,
    required this.conscientiousness,
    required this.extraversion,
    required this.agreeableness,
    required this.neuroticism,
  });

  factory OceanScores.fromJson(Map<String, dynamic> json) {
    return OceanScores(
      openness: (json['openness'] as num?)?.toDouble() ?? 50.0,
      conscientiousness: (json['conscientiousness'] as num?)?.toDouble() ?? 50.0,
      extraversion: (json['extraversion'] as num?)?.toDouble() ?? 50.0,
      agreeableness: (json['agreeableness'] as num?)?.toDouble() ?? 50.0,
      neuroticism: (json['neuroticism'] as num?)?.toDouble() ?? 50.0,
    );
  }

  Map<String, dynamic> toJson() => {
    'openness': openness,
    'conscientiousness': conscientiousness,
    'extraversion': extraversion,
    'agreeableness': agreeableness,
    'neuroticism': neuroticism,
  };

  double get averageScore =>
      (openness + conscientiousness + extraversion + agreeableness + (100 - neuroticism)) / 5;

  /// Returns a new OceanScores with each trait clamped to [0, 100].
  OceanScores clamp() {
    double c(double v) => v.clamp(0.0, 100.0);
    return OceanScores(
      openness: c(openness),
      conscientiousness: c(conscientiousness),
      extraversion: c(extraversion),
      agreeableness: c(agreeableness),
      neuroticism: c(neuroticism),
    );
  }

  /// Applies quiz deltas (map keys: 'openness', 'conscientiousness',
  /// 'extraversion', 'agreeableness', 'neuroticism') and returns
  /// the projected scores clamped to [0, 100].
  OceanScores applyDeltas(Map<String, double> deltas) {
    return OceanScores(
      openness: (openness + (deltas['openness'] ?? 0)).clamp(0.0, 100.0),
      conscientiousness: (conscientiousness + (deltas['conscientiousness'] ?? 0)).clamp(0.0, 100.0),
      extraversion: (extraversion + (deltas['extraversion'] ?? 0)).clamp(0.0, 100.0),
      agreeableness: (agreeableness + (deltas['agreeableness'] ?? 0)).clamp(0.0, 100.0),
      neuroticism: (neuroticism + (deltas['neuroticism'] ?? 0)).clamp(0.0, 100.0),
    );
  }
}
