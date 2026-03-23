import 'package:flutter/material.dart';

extension SizedBoxExt on num {
  Widget get vSizedBox => SizedBox(height: this * 1.0);
  Widget get hSizedBox => SizedBox(width: this * 1.0);
}
