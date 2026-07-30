import 'package:flutter/widgets.dart';

enum AspectRatioMode {
  fit,
  fill,
  stretch,
  ratio16x9,
  ratio4x3,
  original,
  zoom;

  String get displayName {
    switch (this) {
      case AspectRatioMode.fit:
        return 'Fit';
      case AspectRatioMode.fill:
        return 'Fill';
      case AspectRatioMode.stretch:
        return 'Stretch';
      case AspectRatioMode.ratio16x9:
        return '16:9';
      case AspectRatioMode.ratio4x3:
        return '4:3';
      case AspectRatioMode.original:
        return 'Original';
      case AspectRatioMode.zoom:
        return 'Zoom';
    }
  }

  BoxFit toBoxFit() {
    switch (this) {
      case AspectRatioMode.fit:
        return BoxFit.contain;
      case AspectRatioMode.fill:
        return BoxFit.cover;
      case AspectRatioMode.stretch:
        return BoxFit.fill;
      case AspectRatioMode.ratio16x9:
        return BoxFit.fitWidth;
      case AspectRatioMode.ratio4x3:
        return BoxFit.fitHeight;
      case AspectRatioMode.original:
        return BoxFit.none;
      case AspectRatioMode.zoom:
        return BoxFit.cover;
    }
  }
}
