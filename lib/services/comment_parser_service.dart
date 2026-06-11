import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/comment_parser_result.dart';
import '../models/person_score.dart';
import 'chatgpt_service.dart';
import 'profile_storage_service.dart';

class CommentParserService {
  CommentParserService();

  final ChatGPTService _chatGPTService = ChatGPTService();
  final ProfileStorageService _profileStorage = ProfileStorageService();

  Future<List<PersonScore>> processAllCommentsForUser({
    required String userId,
    String? userName,
    void Function(String message, {bool isError})? onStatusUpdate,
  }) async {
    onStatusUpdate?.call('Reading saved post data…');

    final results = await _parseAllFilesForUser(userId);
    if (results.isEmpty) {
      onStatusUpdate?.call('No comments were found in the saved posts.');
      return [];
    }

    final allComments   = <String>[];
    final ownerComments = <String>[];

    for (final r in results) {
      for (final comment in r.comments) {
        allComments.add(comment);
        if (userName != null && _isOwnerComment(comment, userName)) {
          ownerComments.add(comment);
        }
      }
    }

    debugPrint(
        'CommentParser: ${allComments.length} total, '
        '${ownerComments.length} owner comments');

    if (allComments.isEmpty) {
      onStatusUpdate?.call('No comments available to analyse.');
      return [];
    }

    onStatusUpdate?.call(
        'Processing ${allComments.length} comments — this may take a moment…');

    final scores = await _chatGPTService.analyzeComments(
      allComments,
      ownerComments: ownerComments.isNotEmpty ? ownerComments : null,
      onStatusUpdate: onStatusUpdate,
    );

    onStatusUpdate?.call(
        'Scoring complete. ${scores.length} people identified.');

    return scores;
  }

  Future<List<CommentParserResult>> _parseAllFilesForUser(
      String userId) async {
    final results = <CommentParserResult>[];

    try {
      final posts = await _profileStorage.getUserPosts(userId);
      if (posts.isEmpty) {
        debugPrint('CommentParser: no HTML files for user $userId');
        return results;
      }

      debugPrint('CommentParser: parsing ${posts.length} files');

      for (final file in posts) {
        final postId = file.path
            .split('/')
            .last
            .replaceAll('.html', '');
        try {
          final result = await _parseFile(file, postId);
          if (result.comments.isNotEmpty) results.add(result);
        } catch (e) {
          debugPrint('CommentParser: error parsing $postId — $e');
        }
      }
    } catch (e) {
      debugPrint('CommentParser: error listing posts — $e');
    }

    return results;
  }

  Future<CommentParserResult> _parseFile(File file, String postId) async {
    final raw = await file.readAsString();
    final html = _unescapeJsonHtml(raw);
    final comments = _extractComments(html).toSet().toList();
    debugPrint('CommentParser: $postId → ${comments.length} comments');
    return CommentParserResult(postId: postId, comments: comments);
  }

  List<String> _extractComments(String html) {
    final output = <String>[];

    final labelPattern = RegExp(r'aria-label="Comment by ([^"]+?)"');
    final labelHits = labelPattern.allMatches(html).toList();

    debugPrint('CommentParser: ${labelHits.length} comment blocks via aria-label');

    for (var i = 0; i < labelHits.length; i++) {
      final hit = labelHits[i];

      final author = hit
          .group(1)!
          .trim()
          .replaceAll(RegExp(r'\s+\d+\s+\w+\s+ago$', caseSensitive: false), '')
          .trim();

      if (author.isEmpty) continue;

      final searchStart = hit.end;
      final searchEnd   = i + 1 < labelHits.length
          ? labelHits[i + 1].start
          : (searchStart + 6000).clamp(0, html.length);
      final window = html.substring(searchStart, searchEnd);

      final bodyPattern = RegExp(
        r'dir="auto"[^>]*>(.*?)</(?:span|div|p)>',
        dotAll: true,
      );

      String body = '';
      for (final node in bodyPattern.allMatches(window)) {
        final text = _cleanHtml(node.group(1) ?? '');
        if (text.isNotEmpty && text != author) {
          body = text;
          break;
        }
      }

      if (body.isNotEmpty) {
        output.add('Comment by $author: $body');
      }
    }

    return output;
  }

  bool _isOwnerComment(String comment, String userName) {
    const prefix = 'Comment by ';
    if (!comment.startsWith(prefix)) return false;

    final rest      = comment.substring(prefix.length);
    final colonIdx  = rest.indexOf(':');
    if (colonIdx < 0) return false;

    final author = rest.substring(0, colonIdx).trim().toLowerCase();
    final name   = userName.trim().toLowerCase();

    return author == name ||
        author.contains(name) ||
        name.contains(author);
  }

  String _unescapeJsonHtml(String s) => s
      .replaceAll(r'\u003C', '<')
      .replaceAll(r'\u003c', '<')
      .replaceAll(r'\u003E', '>')
      .replaceAll(r'\u003e', '>')
      .replaceAll(r'\u0026', '&')
      .replaceAll(r'\/', '/')
      .replaceAll(r'\\', r'\');

  String _cleanHtml(String input) {
    var s = input.trim();
    s = s.replaceAll(RegExp(r'<[^>]*>'), '');
    s = s
        .replaceAll('&amp;',  '&')
        .replaceAll('&lt;',   '<')
        .replaceAll('&gt;',   '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;',  "'")
        .replaceAll('&apos;', "'")
        .replaceAll('&nbsp;', ' ');
    return s.replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}
