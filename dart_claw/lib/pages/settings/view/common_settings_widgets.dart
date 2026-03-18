import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Shared UI helpers for settings views.

Widget settingsSectionTitle(String title) {
  return Text(
    title,
    style: const TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      color: Colors.white38,
      letterSpacing: 0.8,
    ),
  );
}

Widget settingsTextField({
  required TextEditingController controller,
  String hintText = '',
  String? label,
  bool obscureText = false,
  TextInputType? keyboardType,
  List<TextInputFormatter>? inputFormatters,
  ValueChanged<String>? onChanged,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (label != null) ...[
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: Colors.white60),
        ),
        const SizedBox(height: 8),
      ],
      Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: TextField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          onChanged: onChanged,
          style: const TextStyle(
            fontSize: 13,
            color: Colors.white,
            fontFamily: 'monospace',
          ),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: const TextStyle(color: Colors.white24, fontSize: 13),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
          ),
        ),
      ),
    ],
  );
}
