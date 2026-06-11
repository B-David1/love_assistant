import 'package:flutter/material.dart';
import '../models/user_profile.dart';
import '../models/ocean_scores.dart';
import '../services/activity_checklist_service.dart';

class ActivityChecklistScreen extends StatefulWidget {
  final UserProfile profile;

  const ActivityChecklistScreen({super.key, required this.profile});

  @override
  State<ActivityChecklistScreen> createState() =>
      _ActivityChecklistScreenState();
}

class _ActivityChecklistScreenState extends State<ActivityChecklistScreen> {
  final ActivityChecklistService _service = ActivityChecklistService();
  final Map<String, bool> _checked = {};

  Map<String, List<ChecklistActivity>>? _activities;
  bool _isLoading = true;

  static final OceanScores _target = OceanScores(
    openness: 75,
    conscientiousness: 75,
    extraversion: 75,
    agreeableness: 75,
    neuroticism: 25,
  );

  static const Map<String, Color> _traitColors = {
    'openness':          Color(0xFF00897B),
    'conscientiousness': Color(0xFF1E88E5),
    'extraversion':      Color(0xFFEF6C00),
    'agreeableness':     Color(0xFF43A047),
    'neuroticism':       Color(0xFF8E24AA),
  };

  static const Map<String, String> _traitLabels = {
    'openness':          'Openness',
    'conscientiousness': 'Conscientiousness',
    'extraversion':      'Extraversion',
    'agreeableness':     'Agreeableness',
    'neuroticism':       'Emotional Stability',
  };

  @override
  void initState() {
    super.initState();
    _loadActivities();
  }

  Future<void> _loadActivities() async {
    final activities = await _service.loadActivities();
    if (mounted) {
      setState(() {
        _activities = activities;
        _isLoading = false;
      });
    }
  }

  bool _needsIncrease(String trait) {
    final scores = widget.profile.oceanScores;
    final current = _currentValue(scores, trait);
    final target  = _targetValue(trait);
    if (trait == 'neuroticism') return current > target;
    return current < target;
  }

  double _currentValue(OceanScores s, String trait) {
    switch (trait) {
      case 'openness':          return s.openness;
      case 'conscientiousness': return s.conscientiousness;
      case 'extraversion':      return s.extraversion;
      case 'agreeableness':     return s.agreeableness;
      case 'neuroticism':       return s.neuroticism;
      default:                  return 50;
    }
  }

  double _targetValue(String trait) {
    switch (trait) {
      case 'openness':          return _target.openness;
      case 'conscientiousness': return _target.conscientiousness;
      case 'extraversion':      return _target.extraversion;
      case 'agreeableness':     return _target.agreeableness;
      case 'neuroticism':       return _target.neuroticism;
      default:                  return 75;
    }
  }

  double _gap(String trait) =>
      (_targetValue(trait) - _currentValue(widget.profile.oceanScores, trait)).abs();

  int get _totalChecked =>
      _checked.values.where((v) => v).length;

  int get _totalActivities =>
      (_activities ?? {}).values.fold(0, (sum, list) => sum + list.length);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Personality Checklist'),
        bottom: _isLoading ? null : PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: _totalActivities == 0 ? 0 : _totalChecked / _totalActivities,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.pink.shade400),
            minHeight: 4,
          ),
        ),
        actions: [
          if (!_isLoading)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text(
                  '$_totalChecked / $_totalActivities',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildList(),
    );
  }

  Widget _buildList() {
    final activities = _activities!;
    final traits = activities.keys.toList()
      ..sort((a, b) => _gap(b).compareTo(_gap(a)));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            color: Colors.pink.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.pink.shade200),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.pink.shade700, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Activities are sorted by how far each trait is from '
                  'the target. Tick them off as you complete them.',
                  style: TextStyle(fontSize: 12, color: Colors.pink.shade900),
                ),
              ),
            ],
          ),
        ),
        ...traits.map((trait) => _TraitSection(
              trait: trait,
              label: _traitLabels[trait] ?? trait,
              color: _traitColors[trait] ?? Colors.grey,
              current: _currentValue(widget.profile.oceanScores, trait),
              target: _targetValue(trait),
              needsIncrease: _needsIncrease(trait),
              activities: activities[trait]!,
              checked: _checked,
              onToggle: (key, val) => setState(() => _checked[key] = val),
            )),
      ],
    );
  }
}

// ── Trait section ─────────────────────────────────────────────────────────────

class _TraitSection extends StatelessWidget {
  final String trait;
  final String label;
  final Color color;
  final double current;
  final double target;
  final bool needsIncrease;
  final List<ChecklistActivity> activities;
  final Map<String, bool> checked;
  final void Function(String key, bool val) onToggle;

  const _TraitSection({
    required this.trait,
    required this.label,
    required this.color,
    required this.current,
    required this.target,
    required this.needsIncrease,
    required this.activities,
    required this.checked,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final gap = (target - current).abs();
    final atTarget = gap < 5;

    final relevant = activities.where((a) => a.increases == needsIncrease).toList();
    final other    = activities.where((a) => a.increases != needsIncrease).toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
            ),
            child: Row(
              children: [
                Container(
                  width: 10, height: 10,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Text(label,
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15, color: color)),
                const Spacer(),
                if (atTarget)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                        color: Colors.green.shade100,
                        borderRadius: BorderRadius.circular(10)),
                    child: Text('✓ On target',
                        style: TextStyle(
                            fontSize: 11,
                            color: Colors.green.shade700,
                            fontWeight: FontWeight.w600)),
                  )
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        trait == 'neuroticism'
                            ? '${(100 - current).toInt()} → ${(100 - target).toInt()}'
                            : '${current.toInt()} → ${target.toInt()}',
                        style: TextStyle(
                            fontSize: 12,
                            color: color,
                            fontWeight: FontWeight.w600),
                      ),
                      Text(
                        '▲ needs increase',
                        style: TextStyle(
                            fontSize: 10, color: color.withValues(alpha: 0.7)),
                      ),
                    ],
                  ),
              ],
            ),
          ),

          if (relevant.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
              child: Text(
                'Activities to increase $label',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600),
              ),
            ),
            ...relevant.map((a) => _ActivityTile(
                  activityKey: '${trait}_${a.text}',
                  text: a.text,
                  color: color,
                  checked: checked['${trait}_${a.text}'] ?? false,
                  onToggle: onToggle,
                )),
          ],

          if (other.isNotEmpty && !atTarget) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(
                'Activities to avoid',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade400),
              ),
            ),
            ...other.map((a) => _ActivityTile(
                  activityKey: '${trait}_avoid_${a.text}',
                  text: a.text,
                  color: Colors.grey.shade400,
                  checked: checked['${trait}_avoid_${a.text}'] ?? false,
                  onToggle: onToggle,
                  isAvoid: true,
                )),
          ],

          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ── Activity tile ─────────────────────────────────────────────────────────────

class _ActivityTile extends StatelessWidget {
  final String activityKey;
  final String text;
  final Color color;
  final bool checked;
  final bool isAvoid;
  final void Function(String key, bool val) onToggle;

  const _ActivityTile({
    required this.activityKey,
    required this.text,
    required this.color,
    required this.checked,
    required this.onToggle,
    this.isAvoid = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onToggle(activityKey, !checked),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: checked ? color : Colors.transparent,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                    color: checked ? color : Colors.grey.shade400,
                    width: 1.5),
              ),
              child: checked
                  ? const Icon(Icons.check, color: Colors.white, size: 14)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 13,
                  color: checked
                      ? Colors.grey.shade400
                      : isAvoid
                          ? Colors.grey.shade500
                          : Colors.grey.shade800,
                  decoration: checked ? TextDecoration.lineThrough : null,
                  fontStyle: isAvoid ? FontStyle.italic : FontStyle.normal,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}