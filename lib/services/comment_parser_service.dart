import 'dart:io';
import 'package:flutter/material.dart';
import '../models/comment_parser_result.dart';
import '../models/person_score.dart';
import 'chatgpt_service.dart';
import 'profile_storage_service.dart';

class CommentParserService {
  final ChatGPTService _chatGPTService = ChatGPTService();
  final ProfileStorageService _profileStorage = ProfileStorageService();

  // ── Public API ────────────────────────────────────────────────────────────

  Future<List<CommentParserResult>> parseAllHTMLFilesForUser(
      String userId) async {
    final results = <CommentParserResult>[];

    try {
      final posts = await _profileStorage.getUserPosts(userId);

      if (posts.isEmpty) {
        debugPrint('No HTML files found for user $userId');
        return results;
      }

      debugPrint('Found ${posts.length} HTML files for user $userId');

      for (final file in posts) {
        try {
          final fileName =
              file.path.split('/').last.replaceAll('.html', '');
          debugPrint('Parsing file: $fileName');

          final result = await parseHTMLFile(file.path, fileName);

          if (result.comments.isNotEmpty) {
            results.add(result);
            debugPrint('  Found ${result.comments.length} comments');
          } else {
            debugPrint('  No comments found in this file');
          }
        } catch (e) {
          debugPrint('  Error parsing file ${file.path}: $e');
        }
      }
    } catch (e) {
      debugPrint('Error parsing HTML files: $e');
    }

    return results;
  }

  Future<CommentParserResult> parseHTMLFile(
      String filePath, String postId) async {
    final result = CommentParserResult(postId: postId);

    try {
      final file = File(filePath);
      String htmlContent = await file.readAsString();

      // Android WebView returns HTML that is JSON-encoded inside a JS string,
      // so tags appear as \u003C and slashes as \/. Unescape before parsing.
      htmlContent = _unescapeJsonString(htmlContent);

      final found = _extractComments(htmlContent);
      result.comments.addAll(found.toSet().toList());

      debugPrint(
          '  Total unique comments in $postId: ${result.comments.length}');

      for (var i = 0; i < result.comments.length && i < 3; i++) {
        final preview = result.comments[i];
        final cut = preview.length > 100 ? 100 : preview.length;
        debugPrint('    Comment ${i + 1}: ${preview.substring(0, cut)}...');
      }
    } catch (e) {
      debugPrint('  Error in parseHTMLFile: $e');
    }

    return result;
  }

  Future<List<PersonScore>> processAllCommentsForUser({
    required String userId,
    String? userName,
    Function(String, {bool isError})? onStatusUpdate,
  }) async {
    final allPersonScores = <PersonScore>[];

    try {
      onStatusUpdate?.call('Reading saved post data…');
      final results = await parseAllHTMLFilesForUser(userId);

      if (results.isEmpty) {
        onStatusUpdate?.call('No comments were found in the saved posts.');
        return allPersonScores;
      }

      final allComments = <String>[];
      final ownerComments = <String>[];

      for (final r in results) {
        for (final comment in r.comments) {
          allComments.add(comment);
          if (userName != null && _isOwnerComment(comment, userName)) {
            ownerComments.add(comment);
          }
        }
      }

      debugPrint('Total comments collected: ${allComments.length}');
      debugPrint('Owner comments (${userName ?? 'unknown'}): ${ownerComments.length}');

      if (allComments.isNotEmpty) {
        onStatusUpdate?.call(
            'Processing ${allComments.length} comments — this may take a moment…');

        final scores = await _chatGPTService.analyzeComments(
          allComments,
          ownerComments: ownerComments.isNotEmpty ? ownerComments : null,
          onStatusUpdate: onStatusUpdate,
        );

        allPersonScores.addAll(scores);
        onStatusUpdate?.call(
            'Scoring complete. ${allPersonScores.length} people identified.');
      } else {
        onStatusUpdate?.call('No comments available to analyse.');
      }
    } catch (e) {
      onStatusUpdate?.call('An error occurred during analysis. Please try again.', isError: true);
      debugPrint('ProcessAllComments error: $e');
    }

    return allPersonScores;
  }

  bool _isOwnerComment(String comment, String userName) {
    const prefix = 'Comment by ';
    if (!comment.startsWith(prefix)) return false;
    final rest = comment.substring(prefix.length);
    final colonIdx = rest.indexOf(':');
    if (colonIdx < 0) return false;
    final author = rest.substring(0, colonIdx).trim().toLowerCase();
    final name = userName.trim().toLowerCase();
    return author == name || author.contains(name) || name.contains(author);
  }

  // ── Parsing ───────────────────────────────────────────────────────────────

  List<String> _extractComments(String htmlContent) {
    final output = <String>[];

    final labelPattern = RegExp(r'aria-label="Comment by ([^"]+?)"');
    final labelHits = labelPattern.allMatches(htmlContent).toList();

    debugPrint('  Found ${labelHits.length} comment blocks via aria-label');

    for (int idx = 0; idx < labelHits.length; idx++) {
      final labelHit = labelHits[idx];

      String authorName = labelHit.group(1)!.trim();
      authorName = authorName
          .replaceAll(
            RegExp(r'\s+\d+\s+\w+\s+ago$', caseSensitive: false),
            '',
          )
          .trim();

      if (authorName.isEmpty) continue;

      final searchStart = labelHit.end;
      final searchEnd = idx + 1 < labelHits.length
          ? labelHits[idx + 1].start
          : (searchStart + 6000).clamp(0, htmlContent.length);
      final searchWindow = htmlContent.substring(searchStart, searchEnd);

      final dirAutoPattern = RegExp(
        r'dir="auto"[^>]*>(.*?)</(?:span|div|p)>',
        dotAll: true,
      );

      String commentBody = '';
      for (final node in dirAutoPattern.allMatches(searchWindow)) {
        final nodeText = _clean(node.group(1) ?? '');
        if (nodeText.isEmpty || nodeText == authorName) continue;
        commentBody = nodeText;
        break;
      }

      if (commentBody.isNotEmpty) {
        final entry = 'Comment by $authorName: $commentBody';
        output.add(entry);
        debugPrint('    $entry');
      } else {
        debugPrint('    Comment by $authorName: [no text — sticker or emoji]');
      }
    }

    debugPrint('  Extracted ${output.length} comments total');
    return output;
  }

  /// Unescapes a JSON-encoded string so that HTML tags are restored.
  /// Android WebView returns outerHTML as a JSON string, which means:
  ///   \u003C  →  <
  ///   \u003E  →  >
  ///   \/      →  /
  ///   \\      →  \
  String _unescapeJsonString(String s) {
    return s
        .replaceAll(r'\u003C', '<')
        .replaceAll(r'\u003c', '<')
        .replaceAll(r'\u003E', '>')
        .replaceAll(r'\u003e', '>')
        .replaceAll(r'\u0026', '&')
        .replaceAll(r'\/', '/')
        .replaceAll(r'\\', '\\');
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _clean(String input) {
    String s = input.trim();
    s = s.replaceAll(RegExp(r'<[^>]*>'), '');
    s = s
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&apos;', "'")
        .replaceAll('&nbsp;', ' ');
    s = s.replaceAll(RegExp(r'\s+'), ' ');
    return s.trim();
  }
}