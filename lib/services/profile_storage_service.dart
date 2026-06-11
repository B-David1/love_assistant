import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../models/ocean_scores.dart';
import '../models/user_profile.dart';
import 'profile_encryption_service.dart';

class ProfileStorageService {
  ProfileStorageService();

  final _db         = FirebaseFirestore.instance;
  final _encryption = ProfileEncryptionService();

  static final Map<String, UserProfile> _cache = {};

  DocumentReference<Map<String, dynamic>> _doc(String userId) =>
      _db.collection('users').doc(userId);

  Future<void> saveUserProfile(UserProfile profile) async {
    try {
      final results = await Future.wait([
        _encryption.encrypt(jsonEncode(profile.oceanScores.toJson())),
        _encryption.encrypt(jsonEncode(profile.personScores)),
        _encryption.encrypt(jsonEncode(profile.favorites.toList())),
        _encryption.encrypt(jsonEncode(profile.blacklist.toList())),
        if (profile.quizDeltas != null)
          _encryption.encrypt(jsonEncode(profile.quizDeltas)),
      ]);

      final doc = <String, dynamic>{
        'userId':                profile.userId,
        'name':                  profile.name,
        'email':                 profile.email,
        'profilePictureUrl':     profile.profilePictureUrl,
        'analyzedPostIds':       profile.analyzedPostIds,
        'lastAnalyzed':          profile.lastAnalyzed.toIso8601String(),
        'totalCommentsAnalyzed': profile.totalCommentsAnalyzed,
        'hasBeenAnalyzed':       profile.hasBeenAnalyzed,
        'quizDaysCompleted':     profile.quizDaysCompleted.toList(),
        if (profile.programStartDate != null)
          'programStartDate': profile.programStartDate!.toIso8601String(),
        if (profile.lastQuizDate != null)
          'lastQuizDate': profile.lastQuizDate!.toIso8601String(),
        'oceanScores':  results[0],
        'personScores': results[1],
        'favorites':    results[2],
        'blacklist':    results[3],
        if (profile.quizDeltas != null) 'quizDeltas': results[4],
      };

      await _doc(profile.userId).set(doc);
      _cache[profile.userId] = profile;
      debugPrint('ProfileStorage: saved profile for ${profile.name}');
    } catch (e) {
      debugPrint('ProfileStorage: save failed — $e');
      rethrow;
    }
  }

  Future<UserProfile?> loadUserProfile(String userId) async {
    if (_cache.containsKey(userId)) {
      debugPrint('ProfileStorage: cache hit for $userId');
      return _cache[userId];
    }

    try {
      final snap = await _doc(userId).get();
      if (!snap.exists || snap.data() == null) {
        debugPrint('ProfileStorage: no document for $userId');
        return null;
      }

      final profile = await _fromDoc(snap.data()!);
      if (profile != null) _cache[userId] = profile;
      return profile;
    } catch (e) {
      debugPrint('ProfileStorage: load failed — $e');
      return null;
    }
  }

  Future<void> deleteUserProfile(String userId) async {
    try {
      await _doc(userId).delete();
      _cache.remove(userId);
      debugPrint('ProfileStorage: deleted Firestore doc for $userId');
    } catch (e) {
      debugPrint('ProfileStorage: Firestore delete failed — $e');
      rethrow;
    }

    try {
      final dir = await _userDir(userId);
      if (await dir.exists()) {
        await dir.delete(recursive: true);
        debugPrint('ProfileStorage: deleted local files for $userId');
      }
    } catch (e) {
      debugPrint('ProfileStorage: local delete failed — $e');
    }
  }

  Future<bool> userProfileExists(String userId) async {
    if (_cache.containsKey(userId)) return true;
    try {
      return (await _doc(userId).get()).exists;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, UserProfile>> loadAllProfiles() async {
    final profiles = <String, UserProfile>{};
    try {
      final snap = await _db.collection('users').get();
      for (final doc in snap.docs) {
        try {
          final profile = await _fromDoc(doc.data());
          if (profile != null) {
            profiles[doc.id] = profile;
            _cache[doc.id]   = profile;
          }
        } catch (e) {
          debugPrint('ProfileStorage: failed to parse ${doc.id} — $e');
        }
      }
      debugPrint('ProfileStorage: loaded ${profiles.length} profiles');
    } catch (e) {
      debugPrint('ProfileStorage: loadAllProfiles failed — $e');
    }
    return profiles;
  }

  Future<List<String>> getAllUserIds() async {
    try {
      final snap = await _db.collection('users').get();
      return snap.docs.map((d) => d.id).toList();
    } catch (e) {
      debugPrint('ProfileStorage: getAllUserIds failed — $e');
      return [];
    }
  }

  void invalidateCache(String userId) => _cache.remove(userId);
  void clearCache() => _cache.clear();

  Future<UserProfile?> _fromDoc(Map<String, dynamic> doc) async {
    try {
      final results = await Future.wait([
        _encryption.decrypt(
            Map<String, dynamic>.from(doc['oceanScores'] as Map)),
        _encryption.decrypt(
            Map<String, dynamic>.from(doc['personScores'] as Map)),
        _encryption.decrypt(
            Map<String, dynamic>.from(doc['favorites'] as Map)),
        _encryption.decrypt(
            Map<String, dynamic>.from(doc['blacklist'] as Map)),
        if (doc['quizDeltas'] != null)
          _encryption.decrypt(
              Map<String, dynamic>.from(doc['quizDeltas'] as Map)),
      ]);

      Map<String, double>? quizDeltas;
      if (doc['quizDeltas'] != null) {
        quizDeltas = Map<String, double>.from(
          (jsonDecode(results[4]) as Map)
              .map((k, v) => MapEntry(k as String, (v as num).toDouble())),
        );
      }

      return UserProfile(
        userId:                doc['userId'] as String,
        name:                  doc['name']   as String,
        email:                 doc['email']  as String?,
        profilePictureUrl:     doc['profilePictureUrl'] as String?,
        oceanScores:           OceanScores.fromJson(
                                   jsonDecode(results[0]) as Map<String, dynamic>),
        personScores:          Map<String, int>.from(
                                   jsonDecode(results[1]) as Map),
        favorites:             Set<String>.from(
                                   jsonDecode(results[2]) as List),
        blacklist:             Set<String>.from(
                                   jsonDecode(results[3]) as List),
        analyzedPostIds:       List<String>.from(
                                   doc['analyzedPostIds'] as List? ?? []),
        lastAnalyzed:          DateTime.parse(doc['lastAnalyzed'] as String),
        totalCommentsAnalyzed: doc['totalCommentsAnalyzed'] as int? ?? 0,
        quizDeltas:            quizDeltas,
        programStartDate:      doc['programStartDate'] != null
                                   ? DateTime.parse(doc['programStartDate'] as String)
                                   : null,
        lastQuizDate:          doc['lastQuizDate'] != null
                                   ? DateTime.parse(doc['lastQuizDate'] as String)
                                   : null,
        quizDaysCompleted:     Set<int>.from(
                                   (doc['quizDaysCompleted'] as List? ?? [])
                                   .map((e) => e as int)),
        hasBeenAnalyzed:       doc['hasBeenAnalyzed'] as bool? ?? false,
      );
    } catch (e) {
      debugPrint('ProfileStorage: _fromDoc failed — $e');
      return null;
    }
  }

  Future<Directory> _baseDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir  = Directory('${docs.path}/LoveAssistant');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<Directory> _userDir(String userId) async {
    final dir = Directory('${(await _baseDir()).path}/$userId');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<Directory> _postsDir(String userId) async {
    final dir = Directory('${(await _userDir(userId)).path}/Posts');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<void> savePostHTML(
      String userId, String postId, String html) async {
    try {
      final safeId = postId.replaceAll(RegExp(r'[:/\\*?"<>|]'), '_');
      final file   = File('${(await _postsDir(userId)).path}/$safeId.html');
      await file.writeAsString(html);
      debugPrint('ProfileStorage: saved HTML for $userId / $postId');
    } catch (e) {
      debugPrint('ProfileStorage: savePostHTML failed — $e');
      rethrow;
    }
  }

  Future<List<File>> getUserPosts(String userId) async {
    try {
      final dir = await _postsDir(userId);
      if (!await dir.exists()) return [];
      return dir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.html'))
          .toList();
    } catch (e) {
      debugPrint('ProfileStorage: getUserPosts failed — $e');
      return [];
    }
  }
}
