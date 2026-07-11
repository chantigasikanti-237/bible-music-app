class AudioTrack {
  final String id;
  final String title;
  final String thumbnailUrl;
  final String channelTitle;
  final String audioUrl;
  final String language;

  const AudioTrack({
    required this.id,
    required this.title,
    required this.thumbnailUrl,
    required this.channelTitle,
    this.audioUrl = '',
    this.language = '',
  });

  factory AudioTrack.fromJson(Map<String, dynamic> json) {
    return AudioTrack(
      id: json['id']?.toString().trim() ?? '',
      title: json['title']?.toString().trim() ?? '',
      thumbnailUrl:
          (json['thumbnailUrl'] ?? json['thumbnail'])?.toString().trim() ?? '',
      channelTitle:
          (json['channelTitle'] ?? json['artist'])?.toString().trim() ?? '',
      audioUrl: (json['audioUrl'] ??
                  json['streamUrl'] ??
                  json['url'] ??
                  json['file'] ??
                  json['source'])
              ?.toString()
              .trim() ??
          '',
      language: json['language']?.toString().trim().toLowerCase() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'title': title,
      'thumbnailUrl': thumbnailUrl,
      'channelTitle': channelTitle,
      'audioUrl': audioUrl,
      if (language.isNotEmpty) 'language': language,
    };
  }
}
