import 'package:flutter/foundation.dart';

import '../models/comment_parser_result.dart';
import '../models/person_score.dart';

class AppProvider extends ChangeNotifier {
  List<CommentParserResult> _parseResults = [];
  List<PersonScore>         _personScores = [];
  Map<String, dynamic>?     _userData;

  bool   _isLoading     = false;
  String _statusMessage = 'Ready';
  bool   _isError       = false;

  List<CommentParserResult> get parseResults  => _parseResults;
  List<PersonScore>         get personScores  => _personScores;
  Map<String, dynamic>?     get userData      => _userData;
  bool                      get isLoading     => _isLoading;
  String                    get statusMessage => _statusMessage;
  bool                      get isError       => _isError;

  String get userName   => _userData?['name']                       as String? ?? 'User';
  String get userEmail  => _userData?['email']                      as String? ?? '';
  String get userPicture =>
      _userData?['picture']?['data']?['url'] as String? ?? '';

  int get totalComments =>
      _parseResults.fold(0, (sum, r) => sum + r.comments.length);

  double get averageScore {
    if (_personScores.isEmpty) return 50.0;
    return _personScores.fold(0, (sum, s) => sum + s.score) /
        _personScores.length;
  }

  PersonScore? get highestScore => _personScores.isEmpty
      ? null
      : _personScores.reduce((a, b) => a.score > b.score ? a : b);

  PersonScore? get lowestScore => _personScores.isEmpty
      ? null
      : _personScores.reduce((a, b) => a.score < b.score ? a : b);

  void setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void setStatus(String message, {bool isError = false}) {
    _statusMessage = message;
    _isError       = isError;
    notifyListeners();
  }

  void setUserData(Map<String, dynamic> data) {
    _userData = data;
    notifyListeners();
  }

  void setPersonScores(List<PersonScore> scores) {
    _personScores = scores;
    notifyListeners();
  }

  void setParseResults(List<CommentParserResult> results) {
    _parseResults = results;
    notifyListeners();
  }

  void clearAll() {
    _parseResults  = [];
    _personScores  = [];
    _isLoading     = false;
    _statusMessage = 'Ready';
    _isError       = false;
    notifyListeners();
  }

  void logout() {
    clearAll();
    _userData = null;
    notifyListeners();
  }
}
