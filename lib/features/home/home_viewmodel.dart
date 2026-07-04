import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

class HomeViewModel extends ChangeNotifier {
  bool _isPickingFile = false;
  bool get isPickingFile => _isPickingFile;

  Future<String?> pickVideo() async {
    _isPickingFile = true;
    notifyListeners();
    try {
      if (Platform.isAndroid) {
        final status = await Permission.videos.request();
        if (!status.isGranted) return null;
      }
      final result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        withData: false,
      );
      final file = result?.files.single;
      if (file == null) return null;
      // On Android, prefer the content:// URI (identifier) over path.
      // Using path causes file_picker to copy the entire file to app cache,
      // which doubles storage use for large movie files before any processing.
      return Platform.isAndroid
          ? (file.identifier ?? file.path)
          : file.path;
    } finally {
      _isPickingFile = false;
      notifyListeners();
    }
  }
}
