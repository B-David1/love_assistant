import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static const String _tokenKey = 'facebook_access_token';
  
  Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }
  
  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }
  
  Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }
  
  Future<void> saveHTML(String postId, String htmlContent) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final htmlDir = Directory('${appDir.path}/PostHTML');
      
      if (!await htmlDir.exists()) {
        await htmlDir.create(recursive: true);
      }
      
      final safePostId = postId.replaceAll(RegExp(r'[:/\\*?"<>|]'), '_');
      final filePath = '${htmlDir.path}/$safePostId.html';
      
      final file = File(filePath);
      await file.writeAsString(htmlContent);
      
      print('HTML saved to: $filePath');
    } catch (e) {
      print('Error saving HTML: $e');
    }
  }
  
  Future<List<File>> getSavedHTMLFiles() async {
    final appDir = await getApplicationDocumentsDirectory();
    final htmlDir = Directory('${appDir.path}/PostHTML');
    
    if (!await htmlDir.exists()) {
      return [];
    }
    
    return htmlDir
        .listSync()
        .where((file) => file.path.endsWith('.html'))
        .map((file) => File(file.path))
        .toList();
  }
}