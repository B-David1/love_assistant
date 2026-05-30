import 'package:flutter/material.dart';

class AppConstants {
  static const String appName = 'Love Assistant';
  static const String appVersion = '1.0.0';
  
  // API Endpoints
  static const String facebookGraphAPI = 'https://graph.facebook.com/v18.0';
  static const String openAIAPI = 'https://api.openai.com/v1/chat/completions';
  
  // Storage Keys
  static const String tokenKey = 'facebook_access_token';
  static const String userDataKey = 'facebook_user_data';
  
  // Colors
  static const Color primaryColor = Color(0xFF1877F2);
  static const Color secondaryColor = Color(0xFF42A5F5);
  static const Color accentColor = Color(0xFFFF4081);
  
  // Score thresholds
  static const int neutralScore = 50;
  static const int maxScore = 100;
  static const int minScore = 0;
}

class ScoreInterpretation {
  static String getInterpretation(int score) {
    if (score == 50) return 'Neutral';
    if (score < 20) return 'Very Negative';
    if (score < 40) return 'Negative';
    if (score < 60) return 'Slightly Positive';
    if (score < 80) return 'Positive';
    return 'Very Positive';
  }
  
  static Color getScoreColor(int score) {
    if (score == 50) return Colors.grey;
    if (score < 20) return Colors.red.shade900;
    if (score < 40) return Colors.red;
    if (score < 60) return Colors.orange;
    if (score < 80) return Colors.lightGreen;
    return Colors.green;
  }
  
  static IconData getScoreIcon(int score) {
    if (score == 50) return Icons.sentiment_neutral;
    if (score < 20) return Icons.sentiment_very_dissatisfied;
    if (score < 40) return Icons.sentiment_dissatisfied;
    if (score < 60) return Icons.sentiment_satisfied;
    if (score < 80) return Icons.sentiment_satisfied_alt;
    return Icons.sentiment_very_satisfied;
  }
}