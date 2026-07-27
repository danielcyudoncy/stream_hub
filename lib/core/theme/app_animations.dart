import 'package:flutter/animation.dart';
import 'package:get/get.dart';

class AppAnimations {
  static const Curve defaultCurve = Curves.easeInOut;
  static const Curve fastOutSlowIn = Curves.fastOutSlowIn;
  static const Curve bounce = Curves.bounceOut;

  // GetX Route Transitions
  static Transition get pageTransition => Transition.fadeIn;
  static Transition get dialogTransition => Transition.cupertinoDialog;
}
