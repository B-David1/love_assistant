import 'person_score.dart';

class CommentParserResult {
  final String postId;
  final List<String> comments;
  final List<PersonScore> personScores;
  final DateTime timestamp;

  CommentParserResult({
    required this.postId,
    List<String>? comments,
    List<PersonScore>? personScores,
    DateTime? timestamp,
  })  : comments     = comments     ?? [],
        personScores = personScores ?? [],
        timestamp    = timestamp    ?? DateTime.now();

  bool get hasComments => comments.isNotEmpty;
  bool get hasScores   => personScores.isNotEmpty;
}
