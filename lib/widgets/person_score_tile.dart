import 'package:flutter/material.dart';
import '../models/person_score.dart';

class PersonScoreTile extends StatefulWidget {
  final PersonScore score;
  final int rank;
  final VoidCallback? onFavoriteToggle;
  final VoidCallback? onBlacklistToggle;

  const PersonScoreTile({
    super.key,
    required this.score,
    required this.rank,
    this.onFavoriteToggle,
    this.onBlacklistToggle,
  });

  @override
  State<PersonScoreTile> createState() => _PersonScoreTileState();
}

class _PersonScoreTileState extends State<PersonScoreTile> {
  @override
  Widget build(BuildContext context) {
    final isFavorite = widget.score.isFavorite;
    final isBlacklisted = widget.score.isBlacklisted;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: widget.score.scoreColor.withValues(alpha: 0.2),
          child: Text(
            widget.rank.toString(),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: widget.score.scoreColor,
            ),
          ),
        ),
        title: Text(
          widget.score.name,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: widget.score.scoreColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${widget.score.score}/100',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: widget.score.scoreColor,
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: Icon(
                isFavorite ? Icons.star : Icons.star_outline,
                color: Colors.amber,
                size: 20,
              ),
              onPressed: () {
                setState(() {
                  widget.score.isFavorite = !widget.score.isFavorite;
                });
                widget.onFavoriteToggle?.call();
              },
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
            IconButton(
              icon: Icon(
                isBlacklisted ? Icons.block : Icons.block_outlined,
                color: Colors.red,
                size: 20,
              ),
              onPressed: () {
                setState(() {
                  widget.score.isBlacklisted = !widget.score.isBlacklisted;
                });
                widget.onBlacklistToggle?.call();
              },
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          ],
        ),
      ),
    );
  }
}