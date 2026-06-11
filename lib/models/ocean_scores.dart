class OceanScores {
  final double openness;
  final double conscientiousness;
  final double extraversion;
  final double agreeableness;
  final double neuroticism;

  const OceanScores({
    required this.openness,
    required this.conscientiousness,
    required this.extraversion,
    required this.agreeableness,
    required this.neuroticism,
  });

  factory OceanScores.fromJson(Map<String, dynamic> json) => OceanScores(
        openness:          (json['openness']          as num?)?.toDouble() ?? 50,
        conscientiousness: (json['conscientiousness'] as num?)?.toDouble() ?? 50,
        extraversion:      (json['extraversion']      as num?)?.toDouble() ?? 50,
        agreeableness:     (json['agreeableness']     as num?)?.toDouble() ?? 50,
        neuroticism:       (json['neuroticism']       as num?)?.toDouble() ?? 50,
      );

  Map<String, dynamic> toJson() => {
        'openness':          openness,
        'conscientiousness': conscientiousness,
        'extraversion':      extraversion,
        'agreeableness':     agreeableness,
        'neuroticism':       neuroticism,
      };

  double get averageScore =>
      (openness + conscientiousness + extraversion + agreeableness +
              (100 - neuroticism)) /
          5;

  OceanScores clamp() => OceanScores(
        openness:          openness.clamp(0.0, 100.0),
        conscientiousness: conscientiousness.clamp(0.0, 100.0),
        extraversion:      extraversion.clamp(0.0, 100.0),
        agreeableness:     agreeableness.clamp(0.0, 100.0),
        neuroticism:       neuroticism.clamp(0.0, 100.0),
      );

  OceanScores applyDeltas(Map<String, double> deltas) => OceanScores(
        openness:          (openness          + (deltas['openness']          ?? 0)).clamp(0.0, 100.0),
        conscientiousness: (conscientiousness + (deltas['conscientiousness'] ?? 0)).clamp(0.0, 100.0),
        extraversion:      (extraversion      + (deltas['extraversion']      ?? 0)).clamp(0.0, 100.0),
        agreeableness:     (agreeableness     + (deltas['agreeableness']     ?? 0)).clamp(0.0, 100.0),
        neuroticism:       (neuroticism       + (deltas['neuroticism']       ?? 0)).clamp(0.0, 100.0),
      );
}
