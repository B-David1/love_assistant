import 'package:flutter/material.dart';
import '../models/person_score.dart';
import '../models/comment_parser_result.dart';

class AppProvider extends ChangeNotifier {
  List<CommentParserResult> _parseResults = [];
  List<PersonScore> _personScores = [];
  Map<String, dynamic>? _userData;
  bool _isLoading = false;
  String _statusMessage = 'Ready';
  bool _isError = false;
  int _currentStep = 0;

  List<CommentParserResult> get parseResults => _parseResults;
  List<PersonScore> get personScores => _personScores;
  Map<String, dynamic>? get userData => _userData;
  bool get isLoading => _isLoading;
  String get statusMessage => _statusMessage;
  bool get isError => _isError;
  int get currentStep => _currentStep;
  
  String get userName => _userData?['name'] ?? 'User';
  String get userEmail => _userData?['email'] ?? '';
  String get userPicture => _userData?['picture']?['data']?['url'] ?? '';

  void setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void setStatus(String message, {bool isError = false}) {
    _statusMessage = message;
    _isError = isError;
    notifyListeners();
  }

  void setCurrentStep(int step) {
    _currentStep = step;
    notifyListeners();
  }

  void setUserData(Map<String, dynamic> userData) {
    _userData = userData;
    notifyListeners();
  }

  void setParseResults(List<CommentParserResult> results) {
    _parseResults = results;
    notifyListeners();
  }

  void addParseResult(CommentParserResult result) {
    _parseResults.add(result);
    notifyListeners();
  }

  void setPersonScores(List<PersonScore> scores) {
    _personScores = scores;
    notifyListeners();
  }

  void addPersonScore(PersonScore score) {
    _personScores.add(score);
    notifyListeners();
  }

  void clearAll() {
    _parseResults.clear();
    _personScores.clear();
    _isLoading = false;
    _statusMessage = 'Ready';
    _isError = false;
    _currentStep = 0;
    // Keep user data unless explicitly logging out
    notifyListeners();
  }

  void logout() {
    clearAll();
    _userData = null;
    notifyListeners();
  }

  int get totalComments {
    return _parseResults.fold(0, (sum, result) => sum + result.comments.length);
  }

  int get totalAnalyzedPeople {
    return _personScores.length;
  }

  double get averageScore {
    if (_personScores.isEmpty) return 50.0;
    final sum = _personScores.fold(0, (total, score) => total + score.score);
    return sum / _personScores.length;
  }

  PersonScore? getHighestScore() {
    if (_personScores.isEmpty) return null;
    return _personScores.reduce((a, b) => a.score > b.score ? a : b);
  }

  PersonScore? getLowestScore() {
    if (_personScores.isEmpty) return null;
    return _personScores.reduce((a, b) => a.score < b.score ? a : b);
  }
}