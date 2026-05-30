import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/user_profile.dart';
import '../models/ocean_scores.dart';
import 'profile_encryption_service.dart';

/// Firestore structure:
///   users/{userId}/profile  (single document)
///     Plain fields:
///       userId, name, email, profilePictureUrl,
///       analyzedPostIds, lastAnalyzed, totalCommentsAnalyzed,
///       programStartDate, lastQuizDate, quizDaysCompleted, hasBeenAnalyzed
///     Encrypted fields (each is { salt, iv, datablob }):
///       oceanScores, personScores, quizDeltas, favorites, blacklist
class ProfileStorageService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final ProfileEncryptionService _encryption = ProfileEncryptionService();

  // Static cache shared across all instances — prevents redundant Firestore
  // reads when multiple screens/services each create their own instance.
  static final Map<String, UserProfile> _cache = {};

  DocumentReference<Map<String, dynamic>> _profileDoc(String userId) =>
      _db.collection('users').doc(userId);

  // ── Save ──────────────────────────────────────────────────────────────────

  Future<void> saveUserProfile(UserProfile profile) async {
    try {
      // Encrypt sensitive fields individually
      final oceanBlob = await _encryption.encrypt(
          jsonEncode(profile.oceanScores.toJson()));
      final personBlob = await _encryption.encrypt(
          jsonEncode(profile.personScores));
      final favoritesBlob = await _encryption.encrypt(
          jsonEncode(profile.favorites.toList()));
      final blacklistBlob = await _encryption.encrypt(
          jsonEncode(profile.blacklist.toList()));

      Map<String, dynamic>? deltasBlob;
      if (profile.quizDeltas != null) {
        deltasBlob = await _encryption.encrypt(
            jsonEncode(profile.quizDeltas));
      }

      final doc = <String, dynamic>{
        // ── Plain fields ──
        'userId':                 profile.userId,
        'name':                   profile.name,
        'email':                  profile.email,
        'profilePictureUrl':      profile.profilePictureUrl,
        'analyzedPostIds':        profile.analyzedPostIds,
        'lastAnalyzed':           profile.lastAnalyzed.toIso8601String(),
        'totalCommentsAnalyzed':  profile.totalCommentsAnalyzed,
        'hasBeenAnalyzed':        profile.hasBeenAnalyzed,
        'quizDaysCompleted':      profile.quizDaysCompleted.toList(),
        if (profile.programStartDate != null)
          'programStartDate': profile.programStartDate!.toIso8601String(),
        if (profile.lastQuizDate != null)
          'lastQuizDate': profile.lastQuizDate!.toIso8601String(),

        // ── Encrypted fields ──
        'oceanScores':  oceanBlob,
        'personScores': personBlob,
        'favorites':    favoritesBlob,
        'blacklist':    blacklistBlob,
        if (deltasBlob != null) 'quizDeltas': deltasBlob,
      };

      await _profileDoc(profile.userId).set(doc);
      _cache[profile.userId] = profile;
      debugPrint('Profile saved for user: ${profile.name}');
    } catch (e) {
      debugPrint('Error saving profile: $e');
      rethrow;
    }
  }

  // ── Load ──────────────────────────────────────────────────────────────────

  Future<UserProfile?> loadUserProfile(String userId) async {
    if (_cache.containsKey(userId)) {
      debugPrint('Profile loaded from cache for user: $userId');
      return _cache[userId];
    }

    try {
      final snap = await _profileDoc(userId).get();
      if (!snap.exists || snap.data() == null) {
        debugPrint('No profile found for user: $userId');
        return null;
      }

      final profile = await _fromDoc(snap.data()!);
      if (profile == null) return null;

      _cache[userId] = profile;
      debugPrint('Profile loaded for user: $userId');
      return profile;
    } catch (e) {
      debugPrint('Error loading profile: $e');
      return null;
    }
  }

  // ── Delete ────────────────────────────────────────────────────────────────

  Future<void> deleteUserProfile(String userId) async {
    try {
      await _profileDoc(userId).delete();
      _cache.remove(userId);
      debugPrint('Profile deleted for user: $userId');
    } catch (e) {
      debugPrint('Error deleting profile: $e');
      rethrow;
    }

    try {
      final userDir = await _getUserDirectory(userId);
      if (await userDir.exists()) {
        await userDir.delete(recursive: true);
        debugPrint('Local post files deleted for user: $userId');
      }
    } catch (e) {
      debugPrint('Error deleting local post files: $e');
    }
  }

  // ── Exists ────────────────────────────────────────────────────────────────

  Future<bool> userProfileExists(String userId) async {
    if (_cache.containsKey(userId)) return true;
    try {
      final snap = await _profileDoc(userId).get();
      return snap.exists;
    } catch (e) {
      debugPrint('Error checking profile existence: $e');
      return false;
    }
  }

  // ── Load all ──────────────────────────────────────────────────────────────

  Future<Map<String, UserProfile>> loadAllProfiles() async {
    final profiles = <String, UserProfile>{};
    try {
      final usersSnap = await _db.collection('users').get();
      for (final userDoc in usersSnap.docs) {
        try {
          final profile = await _fromDoc(userDoc.data());
          if (profile != null) {
            profiles[userDoc.id] = profile;
            _cache[userDoc.id]   = profile;
          }
        } catch (e) {
          debugPrint('Error loading profile for ${userDoc.id}: $e');
        }
      }
      debugPrint('Loaded ${profiles.length} profiles');
    } catch (e) {
      debugPrint('Error loading all profiles: $e');
    }
    return profiles;
  }

  Future<List<String>> getAllUserIds() async {
    try {
      final snap = await _db.collection('users').get();
      return snap.docs.map((d) => d.id).toList();
    } catch (e) {
      debugPrint('Error getting user IDs: $e');
      return [];
    }
  }

  // ── Cache ─────────────────────────────────────────────────────────────────

  void invalidateCache(String userId) => _cache.remove(userId);
  void clearCache() => _cache.clear();

  // ── Doc → UserProfile ─────────────────────────────────────────────────────

  Future<UserProfile?> _fromDoc(Map<String, dynamic> doc) async {
    try {
      // Decrypt all sensitive fields in parallel instead of sequentially.
      final results = await Future.wait([
        _encryption.decrypt(Map<String, dynamic>.from(doc['oceanScores'])),
        _encryption.decrypt(Map<String, dynamic>.from(doc['personScores'])),
        _encryption.decrypt(Map<String, dynamic>.from(doc['favorites'])),
        _encryption.decrypt(Map<String, dynamic>.from(doc['blacklist'])),
        if (doc['quizDeltas'] != null)
          _encryption.decrypt(Map<String, dynamic>.from(doc['quizDeltas'])),
      ]);

      final oceanJson  = results[0];
      final personJson = results[1];
      final favJson    = results[2];
      final blackJson  = results[3];

      Map<String, double>? quizDeltas;
      if (doc['quizDeltas'] != null) {
        quizDeltas = Map<String, double>.from(
          (jsonDecode(results[4]) as Map).map(
            (k, v) => MapEntry(k as String, (v as num).toDouble()),
          ),
        );
      }

      return UserProfile(
        userId:                doc['userId'] as String,
        name:                  doc['name'] as String,
        email:                 doc['email'] as String?,
        profilePictureUrl:     doc['profilePictureUrl'] as String?,
        oceanScores:           OceanScores.fromJson(
                                 jsonDecode(oceanJson) as Map<String, dynamic>),
        personScores:          Map<String, int>.from(
                                 jsonDecode(personJson) as Map),
        favorites:             Set<String>.from(jsonDecode(favJson) as List),
        blacklist:             Set<String>.from(jsonDecode(blackJson) as List),
        analyzedPostIds:       List<String>.from(doc['analyzedPostIds'] ?? []),
        lastAnalyzed:          DateTime.parse(doc['lastAnalyzed'] as String),
        totalCommentsAnalyzed: doc['totalCommentsAnalyzed'] as int? ?? 0,
        quizDeltas:            quizDeltas,
        programStartDate:      doc['programStartDate'] != null
                                 ? DateTime.parse(doc['programStartDate'])
                                 : null,
        lastQuizDate:          doc['lastQuizDate'] != null
                                 ? DateTime.parse(doc['lastQuizDate'])
                                 : null,
        quizDaysCompleted:     Set<int>.from(
                                 (doc['quizDaysCompleted'] as List? ?? [])
                                 .map((e) => e as int)),
        hasBeenAnalyzed:       doc['hasBeenAnalyzed'] as bool? ?? false,
      );
    } catch (e) {
      debugPrint('Error parsing profile doc: $e');
      return null;
    }
  }

  // ── HTML posts — local file storage ──────────────────────────────────────

  Future<Directory> _getLoveAssistantDirectory() async {
    final documentsDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${documentsDir.path}/LoveAssistant');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<Directory> _getUserDirectory(String userId) async {
    final base = await _getLoveAssistantDirectory();
    final dir = Directory('${base.path}/$userId');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<Directory> _getPostsDirectory(String userId) async {
    final userDir = await _getUserDirectory(userId);
    final dir = Directory('${userDir.path}/Posts');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<void> savePostHTML(
      String userId, String postId, String htmlContent) async {
    try {
      final postsDir = await _getPostsDirectory(userId);
      final safeId   = postId.replaceAll(RegExp(r'[:/\\*?"<>|]'), '_');
      final file     = File('${postsDir.path}/$safeId.html');
      await file.writeAsString(htmlContent);
      debugPrint('Post HTML saved locally for $userId: $postId');
    } catch (e) {
      debugPrint('Error saving post HTML: $e');
      rethrow;
    }
  }

  Future<List<File>> getUserPosts(String userId) async {
    try {
      final postsDir = await _getPostsDirectory(userId);
      if (!await postsDir.exists()) return [];
      return postsDir
          .listSync()
          .where((f) => f.path.endsWith('.html'))
          .map((f) => File(f.path))
          .toList();
    } catch (e) {
      debugPrint('Error getting user posts: $e');
      return [];
    }
  }
}