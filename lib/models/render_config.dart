import 'package:flutter/foundation.dart';

import 'social_format.dart';

class RenderConfig extends ChangeNotifier {
  SocialFormat _format       = SocialFormat.tiktok;
  bool         _batchMode    = true;   // false = one joined reel
  bool         _captions     = true;
  CaptionStyle _captionStyle = CaptionStyle.block;
  bool         _hookText     = true;
  bool         _verticalCrop = true;
  CropAnchor   _cropAnchor   = CropAnchor.face;
  bool         _transitions  = false;
  bool         _music        = false;
  String?      _musicAsset;            // bundled asset key, null = none
  double       _musicDuck    = 0.3;    // 0 = replace, 1 = keep original

  SocialFormat get format       => _format;
  bool         get batchMode    => _batchMode;
  bool         get captions     => _captions;
  CaptionStyle get captionStyle => _captionStyle;
  bool         get hookText     => _hookText;
  bool         get verticalCrop => _verticalCrop;
  CropAnchor   get cropAnchor   => _cropAnchor;
  bool         get transitions  => _transitions;
  bool         get music        => _music;
  String?      get musicAsset   => _musicAsset;
  double       get musicDuck    => _musicDuck;

  void setFormat(SocialFormat v)       { _format = v;       notifyListeners(); }
  void setBatchMode(bool v)            { _batchMode = v;    notifyListeners(); }
  void setCaptions(bool v)             { _captions = v;     notifyListeners(); }
  void setCaptionStyle(CaptionStyle v) { _captionStyle = v; notifyListeners(); }
  void setHookText(bool v)             { _hookText = v;     notifyListeners(); }
  void setVerticalCrop(bool v)         { _verticalCrop = v; notifyListeners(); }
  void setCropAnchor(CropAnchor v)     { _cropAnchor = v;   notifyListeners(); }
  void setTransitions(bool v)          { _transitions = v;  notifyListeners(); }
  void setMusic(bool v)                { _music = v;        notifyListeners(); }
  void setMusicAsset(String? v)        { _musicAsset = v;   notifyListeners(); }
  void setMusicDuck(double v)          { _musicDuck = v;    notifyListeners(); }
}
