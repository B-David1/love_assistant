class FacebookPost {
  final String id;
  final String? message;
  final DateTime createdTime;
  final String? story;
  final String? permalinkUrl;

  const FacebookPost({
    required this.id,
    this.message,
    required this.createdTime,
    this.story,
    this.permalinkUrl,
  });

  factory FacebookPost.fromJson(Map<String, dynamic> json) => FacebookPost(
        id:           json['id'] as String,
        message:      json['message'] as String?,
        createdTime:  DateTime.parse(json['created_time'] as String),
        story:        json['story'] as String?,
        permalinkUrl: json['permalink_url'] as String?,
      );

  String get actualPostId =>
      id.contains('_') ? id.split('_').last : id;

  String get displayTitle {
    if (message != null && message!.isNotEmpty) {
      return message!.length > 100
          ? '${message!.substring(0, 97)}…'
          : message!;
    }
    return story ?? 'No content';
  }
}
