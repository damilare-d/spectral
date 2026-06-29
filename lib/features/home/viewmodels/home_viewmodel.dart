import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

class HomeViewModel extends ChangeNotifier {
  bool _isPickingFile = false;
  bool get isPickingFile => _isPickingFile;

  /// Requests permission then opens the system file picker.
  /// Returns the selected path, or null if cancelled / denied.
  Future<String?> pickVideo() async {
    _isPickingFile = true;
    notifyListeners();
    try {
      if (Platform.isAndroid) {
        final status = await Permission.videos.request();
        if (!status.isGranted) return null;
      }
      final result = await FilePicker.platform.pickFiles(type: FileType.video);
      return result?.files.single.path;
    } finally {
      _isPickingFile = false;
      notifyListeners();
    }
  }
}
