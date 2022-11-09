import 'dart:io';

import 'package:path_provider/path_provider.dart';

class Utils {
  Utils._();

  static Future<String> createFolderPath(String foldername) async {
    final String path = (await getApplicationDocumentsDirectory()).path;
    final folderPath = (await Directory('$path/$foldername').create()).path;
    return folderPath;
  }
}
