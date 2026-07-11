import 'dart:convert';
import 'package:flutter/services.dart';

class MusicService {
  Future<List<Map<String, dynamic>>> loadSongs() async {
    final String jsonString =
        await rootBundle.loadString("lib/data/songs.json");

    final List<dynamic> jsonData = json.decode(jsonString) as List<dynamic>;

    return List<Map<String, dynamic>>.from(
      jsonData
          .whereType<Map>()
          .map<Map<String, dynamic>>(Map<String, dynamic>.from),
    );
  }
}
