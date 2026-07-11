class BibleAudioProfile {
  const BibleAudioProfile({
    required this.id,
    required this.label,
    required this.isDefault,
    required this.isDramatized,
  });

  final String id;
  final String label;
  final bool isDefault;
  final bool isDramatized;

  factory BibleAudioProfile.fromJson(Map<String, dynamic> json) {
    return BibleAudioProfile(
      id: json['id']?.toString().trim().isNotEmpty == true
          ? json['id'].toString().trim()
          : 'default',
      label: json['label']?.toString().trim().isNotEmpty == true
          ? json['label'].toString().trim()
          : 'Default narration',
      isDefault: json['isDefault'] == true,
      isDramatized: json['isDramatized'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'label': label,
      'isDefault': isDefault,
      'isDramatized': isDramatized,
    };
  }
}
