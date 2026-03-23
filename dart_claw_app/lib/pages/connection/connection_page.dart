import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../others/constants/color_constants.dart';
import 'connection_logic.dart';

class ConnectionPage extends StatelessWidget {
  const ConnectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    final logic = Get.put(ConnectionLogic());
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0A0E1A), Color(0xFF0D1230), Color(0xFF111827)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildLogo(),
                  const SizedBox(height: 52),
                  _buildForm(logic),
                  const SizedBox(height: 28),
                  _buildConnectButton(logic),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Logo block ────────────────────────────────────────────────────────────

  Widget _buildLogo() {
    return const Column(
      children: [
        Text('🦞', style: TextStyle(fontSize: 64)),
        SizedBox(height: 16),
        Text(
          'Dart Claw',
          style: TextStyle(
              fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        SizedBox(height: 6),
        Text(
          'Remote Control',
          style: TextStyle(fontSize: 14, color: Colors.white38),
        ),
      ],
    );
  }

  // ── Form fields + error message ───────────────────────────────────────────

  Widget _buildForm(ConnectionLogic logic) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: logic.hostController,
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(color: Colors.white, fontSize: 15),
          decoration: const InputDecoration(
            labelText: 'Server IP',
            prefixIcon: Icon(Icons.computer_outlined,
                color: Colors.white38, size: 20),
          ),
          onSubmitted: (_) => logic.connect(),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: logic.portController,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(color: Colors.white, fontSize: 15),
          decoration: const InputDecoration(
            labelText: 'Port',
            prefixIcon: Icon(Icons.settings_ethernet,
                color: Colors.white38, size: 20),
          ),
          onSubmitted: (_) => logic.connect(),
        ),
        Obx(() {
          final msg = logic.errorMessage.value;
          if (msg == null) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(msg,
                style: const TextStyle(
                    color: Colors.redAccent, fontSize: 12)),
          );
        }),
      ],
    );
  }

  // ── Connect button ────────────────────────────────────────────────────────

  Widget _buildConnectButton(ConnectionLogic logic) {
    return Obx(() {
      final busy = logic.isConnecting.value;
      return SizedBox(
        width: double.infinity,
        height: 50,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: busy
                ? null
                : const LinearGradient(colors: AppColors.primaryGradient),
            color: busy ? Colors.white.withOpacity(0.08) : null,
            borderRadius: BorderRadius.circular(12),
          ),
          child: TextButton(
            onPressed: busy ? null : logic.connect,
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: busy
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                          AlwaysStoppedAnimation(Colors.white70),
                    ),
                  )
                : const Text(
                    '连接',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600),
                  ),
          ),
        ),
      );
    });
  }
}

