import 'dart:convert';
import 'package:intl/intl.dart';

class Helpers {
  static String formatDate(DateTime date, {String format = 'yyyy-MM-dd HH:mm:ss'}) {
    return DateFormat(format).format(date);
  }
  
  static String truncateString(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength - 3)}...';
  }
  
  static String sanitizeFileName(String fileName) {
    return fileName.replaceAll(RegExp(r'[:/\\*?"<>|]'), '_');
  }
  
  static String decodeHtmlEntities(String text) {
    return text
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&nbsp;', ' ');
  }
  
  static String cleanText(String text) {
    // Remove HTML tags
    String cleaned = text.replaceAll(RegExp(r'<[^>]*>'), '');
    
    // Decode HTML entities
    cleaned = decodeHtmlEntities(cleaned);
    
    // Remove extra whitespace
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
    
    return cleaned;
  }
  
  static String extractJsonFromText(String text) {
    final jsonPattern = RegExp(r'\{[^{}]*\}');
    final matches = jsonPattern.allMatches(text);
    
    for (final match in matches) {
      try {
        json.decode(match.group(0)!);
        return match.group(0)!;
      } catch (e) {
        continue;
      }
    }
    
    return '';
  }
  
  static String getTimeAgo(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays > 365) {
      return '${(difference.inDays / 365).floor()} year${(difference.inDays / 365).floor() == 1 ? '' : 's'} ago';
    } else if (difference.inDays > 30) {
      return '${(difference.inDays / 30).floor()} month${(difference.inDays / 30).floor() == 1 ? '' : 's'} ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
    } else {
      return 'Just now';
    }
  }
}