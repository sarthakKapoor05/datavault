import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StorageManager {
  static const String _defaultStoragePathKey = 'default_storage_path';
  
  // Get the default storage path or return the app documents directory if not set
  static Future<String> getDefaultStoragePath() async {
    final prefs = await SharedPreferences.getInstance();
    final storedPath = prefs.getString(_defaultStoragePathKey);
    
    if (storedPath != null && Directory(storedPath).existsSync()) {
      return storedPath;
    } else {
      // Fallback to app documents directory
      final documentsDir = await getApplicationDocumentsDirectory();
      return '${documentsDir.path}/Downloads';
    }
  }
  
  // Set the default storage path
  static Future<bool> setDefaultStoragePath(String path) async {
    if (!Directory(path).existsSync()) {
      try {
        await Directory(path).create(recursive: true);
      } catch (e) {
        print('Error creating directory: $e');
        return false;
      }
    }
    
    final prefs = await SharedPreferences.getInstance();
    return prefs.setString(_defaultStoragePathKey, path);
  }
  
  // Ensure the default download directory exists
  static Future<Directory> ensureDefaultStorageExists() async {
    final path = await getDefaultStoragePath();
    final directory = Directory(path);
    
    if (!directory.existsSync()) {
      await directory.create(recursive: true);
    }
    
    return directory;
  }
  
  // Save a file to the default storage location
  static Future<File> saveToDefaultStorage(
    String filename, 
    List<int> bytes, 
    {String? subfolder}
  ) async {
    final baseDir = await getDefaultStoragePath();
    final dirPath = subfolder != null ? '$baseDir/$subfolder' : baseDir;
    
    // Create directory if it doesn't exist
    final directory = Directory(dirPath);
    if (!directory.existsSync()) {
      await directory.create(recursive: true);
    }
    
    // Save the file
    final file = File('$dirPath/$filename');
    return file.writeAsBytes(bytes);
  }
}