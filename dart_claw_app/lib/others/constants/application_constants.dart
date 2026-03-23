import 'package:flutter/material.dart';

class ApplicationConstants {
  ///应用全局 key
  static GlobalKey<NavigatorState> globalKey = GlobalKey<NavigatorState>();
  static OverlayEntry? overlayEntry;
  static BuildContext? globalContext;
}
