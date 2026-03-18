import 'package:dart_claw/others/constants/color_constants.dart';
import 'package:dart_claw/others/model/ai_model_settings_info.dart';
import 'package:dart_claw/pages/settings/settings_logic.dart';
import 'package:dart_claw/pages/settings/view/common_settings_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

class SettingsAiModelsView extends StatelessWidget {
  const SettingsAiModelsView({super.key});

  @override
  Widget build(BuildContext context) {
    final logic = Get.find<SettingsLogic>();
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        settingsSectionTitle('Provider'),
        const SizedBox(height: 12),

        // Provider 选择
        Obx(
          () => Wrap(
            spacing: 8,
            runSpacing: 8,
            children: AIProvider.values.map((p) {
              final isSelected = logic.selectedProvider.value == p;
              return GestureDetector(
                onTap: () => logic.selectedProvider.value = p,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary.withOpacity(0.25)
                        : Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primary.withOpacity(0.6)
                          : Colors.white.withOpacity(0.1),
                    ),
                  ),
                  child: Text(
                    p.displayName,
                    style: TextStyle(
                      fontSize: 13,
                      color: isSelected ? Colors.white : Colors.white54,
                      fontWeight:
                          isSelected ? FontWeight.w500 : FontWeight.normal,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),

        const SizedBox(height: 24),
        settingsSectionTitle('Model'),
        const SizedBox(height: 12),

        // 模型选择
        Obx(() {
          final models = kProviderModels[logic.selectedProvider.value] ?? [];
          if (models.isEmpty) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Model ID',
                  style: TextStyle(fontSize: 13, color: Colors.white60),
                ),
                const SizedBox(height: 8),
                settingsTextField(
                  controller: TextEditingController(
                    text: logic.selectedModelId.value,
                  ),
                  hintText: 'e.g. my-custom-model',
                  onChanged: (v) => logic.selectedModelId.value = v,
                ),
              ],
            );
          }
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: models.map((m) {
              final isSelected = logic.selectedModelId.value == m;
              return GestureDetector(
                onTap: () => logic.selectedModelId.value = m,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.secondary.withOpacity(0.2)
                        : Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.secondary.withOpacity(0.5)
                          : Colors.white.withOpacity(0.08),
                    ),
                  ),
                  child: Text(
                    m,
                    style: TextStyle(
                      fontSize: 12,
                      fontFamily: 'monospace',
                      color: isSelected ? Colors.white : Colors.white54,
                    ),
                  ),
                ),
              );
            }).toList(),
          );
        }),

        const SizedBox(height: 24),
        settingsSectionTitle('API Key'),
        const SizedBox(height: 12),
        settingsTextField(
          controller: logic.apiKeyController,
          hintText: 'sk-...',
          obscureText: true,
        ),

        // Custom Base URL (only for custom provider)
        Obx(
          () => logic.selectedProvider.value == AIProvider.custom
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 24),
                    settingsSectionTitle('Base URL'),
                    const SizedBox(height: 12),
                    settingsTextField(
                      controller: logic.customBaseUrlController,
                      hintText: 'https://your-api.example.com/v1',
                    ),
                  ],
                )
              : const SizedBox.shrink(),
        ),

        const SizedBox(height: 28),
        settingsSectionTitle('Temperature'),
        const SizedBox(height: 4),
        Obx(
          () => Row(
            children: [
              const Text(
                '0',
                style: TextStyle(color: Colors.white38, fontSize: 12),
              ),
              Expanded(
                child: Slider(
                  value: logic.temperature.value,
                  min: 0.0,
                  max: 2.0,
                  divisions: 20,
                  activeColor: AppColors.primary,
                  inactiveColor: Colors.white12,
                  onChanged: (v) => logic.temperature.value = double.parse(
                    v.toStringAsFixed(1),
                  ),
                ),
              ),
              const Text(
                '2',
                style: TextStyle(color: Colors.white38, fontSize: 12),
              ),
              const SizedBox(width: 8),
              Text(
                logic.temperature.value.toStringAsFixed(1),
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),
        settingsSectionTitle('Max Tokens'),
        const SizedBox(height: 12),
        settingsTextField(
          controller: logic.maxTokensController,
          hintText: '4096',
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        ),

        const SizedBox(height: 12),
      ],
    );
  }
}
