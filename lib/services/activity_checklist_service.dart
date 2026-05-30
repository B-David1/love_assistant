import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class ActivityChecklistService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Map<String, List<ChecklistActivity>>? _cachedActivities;

  Future<Map<String, List<ChecklistActivity>>> loadActivities() async {
    if (_cachedActivities != null) return _cachedActivities!;

    final snap = await _db.collection('checklist_activities').get();

    final result = <String, List<ChecklistActivity>>{};
    for (final doc in snap.docs) {
      final data     = doc.data();
      final text     = data['text']      as String?;
      final trait    = data['trait']     as String?;
      final increases = data['increases'] as bool? ?? true;

      if (text != null && trait != null) {
        result.putIfAbsent(trait, () => []);
        result[trait]!.add(ChecklistActivity(text, trait, increases));
      }
    }

    debugPrint('ActivityChecklistService: loaded ${snap.docs.length} activities');
    _cachedActivities = result;
    return result;
  }

  void clearCache() => _cachedActivities = null;
}

class ChecklistActivity {
  final String text;
  final String trait;
  final bool increases;
  const ChecklistActivity(this.text, this.trait, this.increases);
}