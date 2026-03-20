import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dart_claw/others/constants/color_constants.dart';
import 'package:dart_claw/others/services/app_config_service.dart';
import 'package:dart_claw/others/tool/snackbar_tool.dart';
import 'package:dart_claw/others/model/claw_session_info.dart';
import 'package:dart_claw/others/tool/database_tool.dart';
import 'package:dart_claw/pages/home/dialog/password_dialog.dart';
import 'package:dart_claw/pages/home/dialog/skill_failure_dialog.dart';
import 'package:dart_claw_core/dart_claw_core.dart';
import 'package:file_selector/file_selector.dart';
import 'package:get/get.dart';

class HomeLogic extends GetxController {
  // ─── 输入框 & 滚动控制器 ───────────────────────────────────────────────

  final inputController = TextEditingController();
  final scrollController = ScrollController();

  late final inputFocusNode = FocusNode(
    onKeyEvent: (node, event) {
      if (event is KeyDownEvent &&
          event.logicalKey == LogicalKeyboardKey.enter &&
          HardwareKeyboard.instance.isControlPressed) {
        submitInput();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    },
  );

  @override
  void onInit() {
    super.onInit();
    _initDb();
  }

  @override
  void onClose() {
    inputController.dispose();
    scrollController.dispose();
    inputFocusNode.dispose();
    sudoPasswordController.dispose();
    super.onClose();
  }

  /// 从输入框取文本发送，发送后清空输入框（由 UI 层调用）
  void submitInput() {
    final text = inputController.text.trim();
    if (text.isEmpty && attachedPaths.isEmpty) return;
    inputController.clear();
    final paths = List<String>.from(attachedPaths);
    attachedPaths.clear();
    sendMessage(text, attachedPaths: paths);
  }

  // ─── 附件 ─────────────────────────────────────────────────────────────────

  final attachedPaths = <String>[].obs;

  Future<void> pickFiles() async {
    final files = await openFiles();
    for (final f in files) {
      if (!attachedPaths.contains(f.path)) {
        attachedPaths.add(f.path);
      }
    }
  }

  void removeAttachedPath(String path) => attachedPaths.remove(path);
  // ─── 面板显示 ─────────────────────────────────────────────────────────────

  final showInfoPanel = true.obs;

  void toggleInfoPanel() {
    showInfoPanel.value = !showInfoPanel.value;
  }

  // ─── Session 级别设置 ──────────────────────────────────────────────────────

  /// 当前 session 内所有危险工具都自动放行（无需逐次确认）
  final allowAllTools = false.obs;

  /// Skill 模式下，工具偏离预期时是否允许继续（true = 警告后继续；false = 立即中止）
  final allowToolDeviation = true.obs;

  /// 遇到 sudo 密码提示时自动填入 [sudoPasswordController] 中存储的密码
  final autoFillSudoPassword = false.obs;

  /// 内存中暂存的 sudo 密码（不持久化）
  late final sudoPasswordController = TextEditingController();

  void setAllowAllTools(bool value) {
    allowAllTools.value = value;
  }

  // ─── Session 状态 ────────────────────────────────────────────────────────

  /// 所有历史 session（供侧边栏使用）
  final sessions = <ClawSessionInfo>[].obs;

  /// 当前活跃 session id（null = 尚未创建），Rxn 供 UI 层 Obx 监听
  final currentSessionId = Rxn<String>();

  /// 当前 session 标题（供顶栏显示）
  String get currentSessionTitle {
    final id = currentSessionId.value;
    if (id == null) return 'New Session';
    final matches = sessions.where((s) => s.id == id);
    return matches.isEmpty ? 'Session' : matches.first.title;
  }

  String _newId() {
    final t = DateTime.now().microsecondsSinceEpoch;
    return (t ^ (t >> 16)).toRadixString(36);
  }

  // ─── 消息列表 ─────────────────────────────────────────────────────────────

  /// 当前会话的消息列表，UI 层用 Obx 监听
  final messages = <ClawChatMessage>[].obs;

  /// Agent loop 是否正在运行（用于禁用输入框、显示 loading 状态）
  final isRunning = false.obs;

  /// 当前正在流式输出的 assistant 消息 id（null 表示无流式输出）
  String? streamingMessageId;

  /// 当前激活的 Skill 名称（null 表示未激活任何 Skill）
  final activeSkillName = Rxn<String>();

  /// 用户手动选定、待下一条消息使用的 Skill 名称（null = 未选定）
  final pendingSkillName = Rxn<String>();

  /// 缓存的已安装 Skill 列表（供选择弹窗使用，Settings 刷新后自动失效）
  final _cachedSkills = <ClawSkillInfo>[];

  /// 设置待发送消息使用的 Skill（null = 取消选定）
  void setPendingSkill(String? name) => pendingSkillName.value = name;

  /// 加载可用 Skill 列表（有缓存则直接返回，否则从磁盘读取）
  Future<List<ClawSkillInfo>> loadAvailableSkills() async {
    if (_cachedSkills.isNotEmpty) return List.unmodifiable(_cachedSkills);
    final skills = await ClawSkillLoader.loadAll();
    _cachedSkills
      ..clear()
      ..addAll(skills);
    return List.unmodifiable(_cachedSkills);
  }

  // ─── 发送消息 ─────────────────────────────────────────────────────────────

  /// 用户发送一条消息（由 UI 层调用）
  void sendMessage(String content, {List<String> attachedPaths = const []}) {
    if (content.trim().isEmpty && attachedPaths.isEmpty) return;
    if (isRunning.value) return;

    // 历史消息快照（不含即将添加的新消息）
    final history = List<ClawChatMessage>.from(messages);

    // 1. 添加用户消息气泡（存储展示文本 + 附件路径）
    final userMsg = ClawChatMessage.user(
      content.trim(),
      attachedPaths: attachedPaths,
    );
    messages.add(userMsg);

    // 2. 添加 assistant 占位气泡（流式输出用）
    final assistantMsg = ClawChatMessage.assistantStreaming();
    streamingMessageId = assistantMsg.id;
    messages.add(assistantMsg);

    isRunning.value = true;
    _scrollToBottom();

    final skillName = pendingSkillName.value;
    pendingSkillName.value = null;
    _runAgent(content.trim(), attachedPaths, assistantMsg.id, history, userMsg,
        explicitSkillName: skillName);
  }

  static const _imageExtensions = {'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'};

  static String _imageMime(String ext) => switch (ext) {
        'jpg' || 'jpeg' => 'image/jpeg',
        'png' => 'image/png',
        'gif' => 'image/gif',
        'webp' => 'image/webp',
        'bmp' => 'image/bmp',
        _ => 'image/jpeg',
      };

  /// 构建发给 LLM 的 content。
  /// 若有图片附件则返回 OpenAI vision 格式的 List（多模态），否则返回 String。
  static Future<dynamic> _buildApiContent(
      String text, List<String> paths) async {
    final imagePaths = <String>[];
    final filePaths = <String>[];
    for (final p in paths) {
      final ext = p.split('.').last.toLowerCase();
      (_imageExtensions.contains(ext) ? imagePaths : filePaths).add(p);
    }

    // 非图片附件 → 追加「请用 read_file 读取」提示
    String baseText = text;
    if (filePaths.isNotEmpty) {
      final ref = filePaths.length == 1
          ? '[附件文件，请用 read_file 读取: ${filePaths.first}]'
          : '[附件文件，请用 read_file 读取:\n${filePaths.map((p) => '  $p').join('\n')}]';
      baseText = baseText.isEmpty ? ref : '$baseText\n\n$ref';
    }

    // 没有图片 → 向后兼容，返回纯字符串
    if (imagePaths.isEmpty) return baseText;

    // 有图片 → 构建多模态 content parts（OpenAI vision 格式）
    final parts = <Map<String, dynamic>>[];
    if (baseText.isNotEmpty) parts.add({'type': 'text', 'text': baseText});
    for (final imgPath in imagePaths) {
      final bytes = await File(imgPath).readAsBytes();
      final b64 = base64Encode(bytes);
      final ext = imgPath.split('.').last.toLowerCase();
      parts.add({
        'type': 'image_url',
        'image_url': {'url': 'data:${_imageMime(ext)};base64,$b64'},
      });
    }
    return parts;
  }

  // ─── 事件处理 ─────────────────────────────────────────────────────────────

  /// 处理来自 ClawAgentRunner 的事件（阶段二实现，目前为 stub）
  void handleEvent(ClawAgentEvent event) {
    switch (event) {
      case ClawAgentNewBlockEvent(:final messageId, :final blockType):
        _addBlock(messageId, blockType);
        _scrollToBottom();

      case ClawAgentMessageChunkEvent(:final messageId, :final chunk):
        _appendChunk(messageId, chunk);
        _scrollToBottom();

      case ClawAgentReasoningChunkEvent(:final messageId, :final chunk):
        _appendReasoningChunk(messageId, chunk);
        _scrollToBottom();

      case ClawAgentMessageDoneEvent(:final messageId, :final toolCalls):
        _finalizeMessage(messageId, toolCalls: toolCalls);

      case ClawAgentToolEvent(:final record):
        _upsertToolRecord(record);

      case ClawAgentConfirmRequestEvent(:final requestId):
        if (allowAllTools.value) {
          // Session 级别「全部放行」开启时，自动确认无需用户介入
          _activeRunner?.confirm(requestId, allow: true);
        } else {
          // 工具 block 已通过 ClawAgentToolEvent 更新为 awaitingConfirmation
          // UI 会自动显示内嵌确认卡片
          _scrollToBottom();
        }
        break;

      case ClawAgentSkillActivatedEvent(:final skillName):
        activeSkillName.value = skillName;

      case ClawAgentSkillStepFailureEvent(
            :final skillName,
            :final stepTitle,
            :final toolName,
            :final toolOutput,
            :final failureReport,
            :final reason,
          ):
        isRunning.value = false;
        streamingMessageId = null;
        activeSkillName.value = null;
        if (allowToolDeviation.value) {
          // 宽松模式：snackbar 轻提示，不打断用户
          SnackbarTool.showWarning(
            'Skill "$skillName" 失败于「$stepTitle」'
            '${reason == ClawSkillFailureReason.unexpectedTool ? '（工具偏离）' : ''}',
          );
        } else {
          // 严格模式：弹窗展示详情
          _showSkillFailureDialog(
            skillName: skillName,
            stepTitle: stepTitle,
            toolName: toolName,
            toolOutput: toolOutput,
            failureReport: failureReport,
            reason: reason,
          );
        }

      case ClawAgentDoneEvent():
        isRunning.value = false;
        streamingMessageId = null;
        activeSkillName.value = null;

      case ClawAgentErrorEvent(:final message):
        _appendError(message);
        isRunning.value = false;
        streamingMessageId = null;
        activeSkillName.value = null;

      case ClawAgentLogEvent():
        // 普通日志暂不展示在消息列表，后续可加到 Info 面板
        break;
    }
  }

  // ─── 私有辅助 ─────────────────────────────────────────────────────────────

  void _addBlock(String messageId, ClawChatBlockType blockType) {
    final idx = messages.indexWhere((m) => m.id == messageId);
    if (idx == -1) return;
    final block = switch (blockType) {
      ClawChatBlockType.reasoning => const ClawReasoningBlock(),
      ClawChatBlockType.content => const ClawContentBlock(),
    };
    messages[idx] = messages[idx].addBlock(block);
  }

  void _appendChunk(String messageId, String chunk) {
    final idx = messages.indexWhere((m) => m.id == messageId);
    if (idx == -1) return;
    messages[idx] = messages[idx].appendChunk(chunk);
  }

  void _appendReasoningChunk(String messageId, String chunk) {
    final idx = messages.indexWhere((m) => m.id == messageId);
    if (idx == -1) return;
    messages[idx] = messages[idx].appendReasoningChunk(chunk);
  }

  void _finalizeMessage(
    String messageId, {
    List<ClawToolCallRecord> toolCalls = const [],
  }) {
    final idx = messages.indexWhere((m) => m.id == messageId);
    if (idx == -1) return;
    // tool blocks are already in blocks via _upsertToolRecord; just finalize
    messages[idx] = messages[idx].finalize();
  }

  void _upsertToolRecord(ClawToolCallRecord record) {
    // Tool calls always belong to the current streaming assistant message
    if (streamingMessageId == null) return;
    final idx = messages.indexWhere((m) => m.id == streamingMessageId);
    if (idx == -1) return;
    messages[idx] = messages[idx].updateToolBlock(record);
  }

  void _appendError(String fullMessage) {
    // 1. 移除 assistant 占位消息（不在聊天中展示错误）
    if (streamingMessageId != null) {
      messages.removeWhere((m) => m.id == streamingMessageId);
    }

    // 2. 完整错误信息打印到控制台，方便复制调试
    debugPrint('[dart_claw] ❌ Agent error:\n$fullMessage');

    // 3. 弹窗展示（可滚动，方便阅读）
    Get.dialog(
      AlertDialog(
        backgroundColor: AppColors.dialogBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Colors.red, width: 0.5),
        ),
        title: const Text(
          'Error',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Text(
              fullMessage,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontFamily: 'monospace',
                height: 1.5,
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: Get.back,
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// 当前配置的模型名称（用于 Info 面板显示）
  String get currentModelId =>
      AppConfigService.shared.config.value.model.modelId;

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scrollController.hasClients) {
        scrollController.animateTo(
          scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// 使用 [ClawAgentRunner] 运行一轮 Agent 对话
  ClawAgentRunner? _activeRunner;

  /// 根据配置返回浏览器 profileDir。
  /// null 表示不保留登录（每次使用临时目录）。
  String? _browserProfileDir() {
    final cfg = AppConfigService.shared.config.value;
    if (!cfg.session.browserRememberLogin) return null;
    final home = Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ?? '';
    return '$home/.dart_claw/browser_profile';
  }

  /// UI 层调用：将用户对工具确认的结果回传给 Runner
  void confirmTool(String requestId, {required bool allow}) {
    _activeRunner?.confirm(requestId, allow: allow);
  }

  /// UI 层调用：中止当前 Agent loop
  void stopAgent() {
    _activeRunner?.cancel();
  }

  Future<void> _runAgent(
    String rawText,
    List<String> attachedPaths,
    String assistantMsgId,
    List<ClawChatMessage> history,
    ClawChatMessage userMsg, {
    String? explicitSkillName,
  }) async {
    // ── 确保 session 存在，再持久化用户消息 ──
    await _ensureSession(firstUserMessage: rawText);
    final apiContent = await _buildApiContent(rawText, attachedPaths);
    await _persistMessage(userMsg, messages.indexOf(userMsg));

    final cfg = AppConfigService.shared.config.value;
    final client = ClawLlmClient(
      baseUrl: cfg.model.effectiveBaseUrl,
      apiKey: cfg.model.apiKey,
      modelId: cfg.model.modelId,
      temperature: cfg.model.temperature,
      maxTokens: cfg.model.maxTokens,
    );
    final runner = ClawAgentRunner(
      client: client,
      tools: [
        InteractiveRunCommandTool(onPasswordRequired: _promptPassword),
        ReadFileTool(),
        WriteFileTool(),
        ListDirTool(),
        SearchInFileTool(),
        ShowImageTool(),
        ShowChartTool(),
        ShowVideoTool(),
        ...getWebBrowserTools(_browserProfileDir()),
      ],
    );
    _activeRunner = runner;

    await for (final event in runner.run(
      userMessage: apiContent,
      history: history,
      assistantMessageId: assistantMsgId,
      maxRounds: cfg.session.maxRounds,
      explicitSkillName: explicitSkillName,
      allowToolDeviation: allowToolDeviation.value,
    )) {
      handleEvent(event);
    }

    // Runner 退出后（正常结束或被 cancel）确保 UI 状态清理干净
    if (isRunning.value) {
      if (streamingMessageId != null) {
        _finalizeMessage(streamingMessageId!);
      }
      isRunning.value = false;
      streamingMessageId = null;
    }

    // ── 持久化 assistant 消息（最终状态）──
    final assistantIdx = messages.indexWhere((m) => m.id == assistantMsgId);
    if (assistantIdx != -1) {
      await _persistMessage(messages[assistantIdx], assistantIdx);
    }

    _activeRunner = null;
  }

  // ─── DB 初始化 & Session 管理 ───────────────────────────────────────────────

  Future<void> _initDb() async {
    await DatabaseTool.shared.init();
    final loaded = await DatabaseTool.shared.listSessions();
    sessions.assignAll(loaded);
    // 自动加载最近一次 session
    if (loaded.isNotEmpty) {
      await _loadSession(loaded.first.id);
    }
  }

  Future<void> _loadSession(String sessionId) async {
    currentSessionId.value = sessionId;
    final msgs = await DatabaseTool.shared.loadMessages(sessionId);
    messages.assignAll(msgs);
    _scrollToBottom();
  }

  /// 若当前不存在 session，自动创建一个（懒创建）
  Future<void> _ensureSession({required String firstUserMessage}) async {
    if (currentSessionId.value != null) return;
    final title = firstUserMessage.length > 50
        ? '${firstUserMessage.substring(0, 50)}…'
        : firstUserMessage;
    final session = ClawSessionInfo(
      id: _newId(),
      title: title,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await DatabaseTool.shared.insertSession(session);
    sessions.insert(0, session);
    currentSessionId.value = session.id;
  }

  Future<void> _persistMessage(ClawChatMessage msg, int sortIndex) async {
    if (currentSessionId.value == null) return;
    await DatabaseTool.shared.upsertMessage(currentSessionId.value!, msg, sortIndex);
    await DatabaseTool.shared.touchSession(currentSessionId.value!);
    // 同步更新 sessions 列表中的 updatedAt
    final idx = sessions.indexWhere((s) => s.id == currentSessionId.value);
    if (idx != -1) {
      sessions[idx] = sessions[idx].copyWith(updatedAt: DateTime.now());
    }
  }

  // ─── 公开 Session 操作（供侧边栏 UI 调用）─────────────────────────────────

  /// 新建空白 session（不写 DB，等第一条消息才创建）
  void newSession() {
    currentSessionId.value = null;
    messages.clear();
    allowAllTools.value = false;
    allowToolDeviation.value = true;
    activeSkillName.value = null;
    pendingSkillName.value = null;
  }

  /// 切换到已有 session
  Future<void> switchToSession(String sessionId) async {
    if (currentSessionId.value == sessionId) return;
    if (isRunning.value) return; // 运行中禁止切换
    await _loadSession(sessionId);
    allowAllTools.value = false;
    allowToolDeviation.value = true;
  }

  /// 重命名 session
  Future<void> renameSession(String sessionId, String newTitle) async {
    await DatabaseTool.shared.updateSessionTitle(sessionId, newTitle);
    final idx = sessions.indexWhere((s) => s.id == sessionId);
    if (idx != -1) {
      sessions[idx] = sessions[idx].copyWith(title: newTitle);
    }
  }

  // ─── 密码输入弹窗 ──────────────────────────────────────────────────────────

  Future<String?> _promptPassword(String prompt) {
    // 如果开启了自动填充且已存储密码，直接返回，无需弹窗
    if (autoFillSudoPassword.value) {
      final stored = sudoPasswordController.text.trim();
      if (stored.isNotEmpty) return Future.value(stored);
    }
    return Get.dialog<String>(
      PasswordDialog(prompt: prompt),
      barrierDismissible: false,
    );
  }

  void _showSkillFailureDialog({
    required String skillName,
    required String stepTitle,
    required String toolName,
    required String toolOutput,
    required String failureReport,
    required ClawSkillFailureReason reason,
  }) {
    debugPrint('[HomeLogic] ⚠️ Skill "$skillName" failed at step "$stepTitle" when calling tool "$toolName". Reason: $reason. Tool output: $toolOutput. Failure report: $failureReport');

    Get.dialog(SkillFailureDialog(
      skillName: skillName,
      stepTitle: stepTitle,
      toolName: toolName,
      toolOutput: toolOutput,
      failureReport: failureReport,
      reason: reason,
    ));
  }

  /// 删除 session
  Future<void> deleteSessionById(String sessionId) async {
    await DatabaseTool.shared.deleteSession(sessionId);
    sessions.removeWhere((s) => s.id == sessionId);
    // 若删除的是当前 session，切到最新一个或新建空白
    if (currentSessionId.value == sessionId) {
      if (sessions.isNotEmpty) {
        await _loadSession(sessions.first.id);
      } else {
        newSession();
      }
    }
  }
}



