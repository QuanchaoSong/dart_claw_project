import 'package:dart_claw/pages/settings/settings_logic.dart';
import 'package:dart_claw/pages/settings/view/common_settings_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

class SettingsSessionsView extends StatelessWidget {
  const SettingsSessionsView({super.key});

  @override
  Widget build(BuildContext context) {
    final logic = Get.find<SettingsLogic>();
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        settingsSectionTitle('Session Preferences'),
        const SizedBox(height: 20),

        // Auto-save switch
        Obx(
          () => _buildSwitchRow(
            label: 'Auto-save sessions',
            description: 'Automatically save conversation history to disk',
            value: logic.autoSave.value,
            onChanged: (v) => logic.autoSave.value = v,
          ),
        ),

        const SizedBox(height: 28),
        settingsSectionTitle('History'),
        const SizedBox(height: 12),

        settingsTextField(
          controller: logic.maxHistoryCountController,
          hintText: '50',
          label: 'Max sessions to keep',
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        ),
        const SizedBox(height: 8),
        const Text(
          'Older sessions beyond this limit will be removed automatically.',
          style: TextStyle(fontSize: 12, color: Colors.white38),
        ),

        const SizedBox(height: 28),
        settingsSectionTitle('Agent'),
        const SizedBox(height: 12),

        settingsTextField(
          controller: logic.maxRoundsController,
          hintText: '20',
          label: 'Max tool-call rounds',
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        ),
        const SizedBox(height: 8),
        const Text(
          'Maximum number of tool-call loops per message before auto-stopping.',
          style: TextStyle(fontSize: 12, color: Colors.white38),
        ),
      ],
    );
  }

  Widget _buildSwitchRow({
    required String label,
    required String description,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 14, color: Colors.white),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(fontSize: 12, color: Colors.white38),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: const Color(0xFF6366F1),
          ),
        ],
      ),
    );
  }
}
