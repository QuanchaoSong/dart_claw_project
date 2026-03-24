import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dart_claw/others/constants/color_constants.dart';
import 'package:dart_claw/others/services/app_config_service.dart';
import 'package:dart_claw/others/services/remote_service.dart';
import 'package:dart_claw/others/tool/snackbar_tool.dart';
import 'package:dart_claw/others/model/claw_session_info.dart';
import 'package:dart_claw/others/tool/database_tool.dart';
import 'package:dart_claw/pages/home/dialog/password_dialog.dart';
import 'package:dart_claw/pages/home/dialog/agent_error_dialog.dart';
import 'package:dart_claw/pages/home/dialog/ask_user_dialog.dart';
import 'package:dart_claw/pages/home/dialog/skill_failure_dialog.dart';
import 'package:dart_claw/others/dart_claw_core_extra_tools/mouse_keyboard_tools.dart';
import 'package:dart_claw/others/dart_claw_core_extra_tools/retrieve_message_tool.dart';
import 'package:dart_claw/others/compression/context_compressor.dart';
import 'package:dart_claw_core/dart_claw_core.dart';
import 'package:file_selector/file_selector.dart';
import 'package:get/get.dart';

/// LLM 发起的用户输入请求（内联卡片状态，存储在 HomeLogic.pendingUserInput）
class PendingUserInput {
  final String requestId;
  final AskUserRequest request;
  final Completer<String?> completer;

  const PendingUserInput({
    required this.requestId,
    required this.request,
    required this.completer,
  });
}

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
  final sessionTotalTokens = 0.obs;
  final isCompressing = false.obs;
  int _lastPromptTokens = 0;

  /// 当前正在流式输出的 assistant 消息 id（null 表示无流式输出）
  String? streamingMessageId;

  /// 当前激活的 Skill 名称（null 表示未激活任何 Skill）
  final activeSkillName = Rxn<String>();

  /// 用户手动选定、待下一条消息使用的 Skill 名称（null = 未选定）
  final pendingSkillName = Rxn<String>();

  /// LLM 调用 ask_user 工具时的待处理输入请求（Plan B 内联卡片）
  /// 非 null 时 chat_area_view 会在消息列表下方渲染交互卡片
  final pendingUserInput = Rxn<PendingUserInput>();

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
  void sendMessage(String content,
      {List<String> attachedPaths = const [],
      bool isRemote = false,
      String? sessionId}) {
    if (content.trim().isEmpty && attachedPaths.isEmpty) return;
    if (isRunning.value) return;

    // 移动端发起的新 session：若 session_id 与当前不符则重置桌面 UI
    if (sessionId != null &&
        currentSessionId.value != null &&
        currentSessionId.value != sessionId) {
      currentSessionId.value = null;
      messages.clear();
      sessionTotalTokens.value = 0;
    }

    // 历史消息快照（不含即将添加的新消息，排除 divider 和 log 行）
    final history = messages
        .where((m) =>
            m.type != ClawChatMessageType.divider &&
            m.type != ClawChatMessageType.log)
        .toList();

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
        explicitSkillName: skillName, isRemote: isRemote, externalSessionId: sessionId);
  }

  static const _imageExtensions = {'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'};

  /// 构建发给 LLM 的用户消息文本。
  /// 所有附件均以路径提示告知 LLM，由 LLM 根据任务需要自行决定：
  /// - 图片：调用 vision_read_image 进行视觉分析，或直接把路径传给工具（如 ffmpeg）
  /// - 其他文件：调用 read_file 读取内容
  static String _buildApiContent(String text, List<String> paths) {
    if (paths.isEmpty) return text;
    final imagePaths = <String>[];
    final filePaths = <String>[];
    for (final p in paths) {
      final ext = p.split('.').last.toLowerCase();
      (_imageExtensions.contains(ext) ? imagePaths : filePaths).add(p);
    }
    String result = text;
    if (filePaths.isNotEmpty) {
      final ref = filePaths.length == 1
          ? '[附件文件，请用 read_file 读取: ${filePaths.first}]'
          : '[附件文件，请用 read_file 读取:\n${filePaths.map((p) => '  $p').join('\n')}]';
      result = result.isEmpty ? ref : '$result\n\n$ref';
    }
    if (imagePaths.isNotEmpty) {
      final ref = imagePaths.length == 1
          ? '[附件图片: ${imagePaths.first}\n（视觉分析请调用 vision_read_image；文件处理直接使用此路径）]'
          : '[附件图片:\n${imagePaths.map((p) => '  $p').join('\n')}\n（视觉分析请调用 vision_read_image；文件处理直接使用路径）]';
      result = result.isEmpty ? ref : '$result\n\n$ref';
    }
    return result;
  }

  // ─── 事件处理 ─────────────────────────────────────────────────────────────

  void _broadcast(Map<String, dynamic> data) {
    RemoteService().broadcast({...data, 'session_id': currentSessionId.value});
  }

  /// show_image 工具广播时，将本地路径替换为手机可访问的 HTTP URL。
  /// 其他工具原样返回 args。
  Map<String, dynamic> _remoteArgs(ClawToolCallRecord record) {
    if (record.name == 'show_image') {
      final paths = record.args['paths'];
      if (paths is! List || paths.isEmpty) return record.args;
      final transformed =
          paths.map((p) => RemoteService().imageUrl(p.toString())).toList();
      return {...record.args, 'paths': transformed};
    }
    if (record.name == 'show_video') {
      final path = record.args['path'];
      if (path is! String || path.isEmpty) return record.args;
      return {...record.args, 'path': RemoteService().videoUrl(path)};
    }
    return record.args;
  }

  /// 处理来自 ClawAgentRunner 的事件（阶段二实现，目前为 stub）
  void handleEvent(ClawAgentEvent event) {
    switch (event) {
      case ClawAgentNewBlockEvent(:final messageId, :final blockType):
        _addBlock(messageId, blockType);
        _scrollToBottom();

      case ClawAgentMessageChunkEvent(:final messageId, :final chunk):
        _appendChunk(messageId, chunk);
        _scrollToBottom();
        _broadcast({'type': 'chunk', 'content': chunk});

      case ClawAgentReasoningChunkEvent(:final messageId, :final chunk):
        _appendReasoningChunk(messageId, chunk);
        _scrollToBottom();
        _broadcast({'type': 'reasoning_chunk', 'content': chunk});

      case ClawAgentMessageDoneEvent(:final messageId, :final toolCalls):
        _finalizeMessage(messageId, toolCalls: toolCalls);
        _broadcast({'type': 'message_done'});

      case ClawAgentToolEvent(:final record):
        _upsertToolRecord(record);
        _broadcast({
          'type': 'tool',
          'id': record.id,
          'name': record.name,
          'args': _remoteArgs(record),
          'status': record.status.name,
        });

      case ClawAgentConfirmRequestEvent(:final requestId, :final message, :final record):
        if (allowAllTools.value) {
          // Session 级别「全部放行」开启时，自动确认无需用户介入
          _activeRunner?.confirm(requestId, allow: true);
        } else {
          // 工具 block 已通过 ClawAgentToolEvent 更新为 awaitingConfirmation
          // UI 会自动显示内嵌确认卡片
          _scrollToBottom();
          _broadcast({
            'type': 'confirm_request',
            'id': requestId,
            'message': message,
            'args': record.args,
          });
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
        _broadcast({
          'type': 'error',
          'message': 'Skill "$skillName" 失败于「$stepTitle」',
        });

      case ClawAgentTokenUsageEvent(:final promptTokens, :final totalTokens):
        sessionTotalTokens.value += totalTokens;
        _lastPromptTokens = promptTokens;

      case ClawAgentDoneEvent():
        isRunning.value = false;
        streamingMessageId = null;
        activeSkillName.value = null;
        _checkAndTriggerCompression();
        _broadcast({'type': 'done'});

      case ClawAgentErrorEvent(:final message):
        _appendError(message);
        isRunning.value = false;
        streamingMessageId = null;
        activeSkillName.value = null;
        _broadcast({'type': 'error', 'message': message});

      case ClawAgentLogEvent(:final content):
        _broadcast({'type': 'log', 'content': content});
        break;
    }
  }

  // ─── 私有辅助 ─────────────────────────────────────────────────────────────

  /// 在每轮 Agent 完成后检查是否需要触发上下文压缩
  void _checkAndTriggerCompression() {
    final threshold =
        AppConfigService.shared.config.value.model.compressionThreshold;
    if (_lastPromptTokens >= threshold && !isCompressing.value) {
      _triggerCompression();
    }
  }

  /// 异步执行上下文压缩（后台运行，不阻塞 UI）
  Future<void> _triggerCompression() async {
    final sessionId = currentSessionId.value;
    if (sessionId == null) return;
    isCompressing.value = true;
    try {
      final allActive =
          await DatabaseTool.shared.loadContextMessages(sessionId);

      // 保留最近 15 条为热区，pin 第一条，其余归档
      const hotWindowSize = 15;
      if (allActive.length <= hotWindowSize + 2) return;

      final toArchive = allActive
          .skip(1) // 跳过 pin 住的第一条（用户初始任务描述）
          .take(allActive.length - 1 - hotWindowSize)
          .where((m) => m.type != ClawChatMessageType.summary) // 已有摘要不重复压缩
          .toList();
      if (toArchive.isEmpty) return;

      // 获取第一条待归档消息的 sort_index，作为摘要插入位置
      final insertSortIndex =
          await DatabaseTool.shared.getSortIndex(toArchive.first.id) ?? 1;

      final cfg = AppConfigService.shared.config.value.model;
      final client = ClawLlmClient(
        baseUrl: cfg.effectiveBaseUrl,
        apiKey: cfg.apiKey,
        modelId: cfg.modelId,
        temperature: 0.3, // 摘要任务用较低温度，保证稳定性
        maxTokens: 800,
      );

      final compressor = ContextCompressor(client: client);
      await compressor.compress(
        sessionId: sessionId,
        toArchive: toArchive,
        insertSortIndex: insertSortIndex,
      );

      // 压缩完成后重新加载消息列表刷新 UI
      if (currentSessionId.value == sessionId) {
        final reloaded = await DatabaseTool.shared.loadMessages(sessionId);
        messages.assignAll(reloaded);
        _scrollToBottom();
      }
    } catch (_) {
      // 压缩失败不影响正常聊天，静默处理
    } finally {
      isCompressing.value = false;
    }
  }

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
    // 1. Finalize the streaming bubble with error status (don't remove it)
    if (streamingMessageId != null) {
      final idx = messages.indexWhere((m) => m.id == streamingMessageId);
      if (idx != -1) {
        messages[idx] = messages[idx].copyWith(
          status: ClawChatMessageStatus.error,
        );
      }
    }

    // 2. Add compact inline error log
    messages.add(ClawChatMessage.log('⚠ $fullMessage'));

    // 3. Full error to debug console + dialog
    debugPrint('[dart_claw] ❌ Agent error:\n$fullMessage');

    AgentErrorDialog.show(fullMessage);
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
    // 同时取消内联用户输入卡片（让 Completer 返回 null 通知 AskUserTool）
    _cancelPendingUserInput();
  }

  Future<void> _runAgent(
    String rawText,
    List<String> attachedPaths,
    String assistantMsgId,
    List<ClawChatMessage> history,
    ClawChatMessage userMsg, {
    String? explicitSkillName,
    bool isRemote = false,
    String? externalSessionId,
  }) async {
    // ── 确保 session 存在，再持久化用户消息 ──
    await _ensureSession(
        firstUserMessage: rawText,
        isRemote: isRemote,
        externalSessionId: externalSessionId);
    final apiContent = _buildApiContent(rawText, attachedPaths);
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
        AskUserTool(onAskUser: _promptAskUser),
        ReadFileTool(),
        WriteFileTool(),
        ListDirTool(),
        SearchInFileTool(),
        ShowImageTool(),
        VisionReadImageTool(),
        ShowChartTool(),
        ShowVideoTool(),
        ScreenshotTool(),
        MouseMoveTool(),
        MouseClickTool(),
        MouseDragTool(),
        MouseScrollTool(),
        KeyboardTypeTool(),
        KeyboardShortcutTool(),
        RetrieveMessageTool(),
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
    sessionTotalTokens.value = 0;
    final msgs = await DatabaseTool.shared.loadMessages(sessionId);
    messages.assignAll(msgs);
    _scrollToBottom();
  }

  /// 若当前不存在 session，自动创建一个（懒创建）
  Future<void> _ensureSession(
      {required String firstUserMessage,
      bool isRemote = false,
      String? externalSessionId}) async {
    if (currentSessionId.value != null) return;
    // 若移动端提供的 session_id 已存在于本地 DB，直接复用，避免创建重复 session
    if (externalSessionId != null) {
      final existingIdx = sessions.indexWhere((s) => s.id == externalSessionId);
      if (existingIdx != -1) {
        currentSessionId.value = externalSessionId;
        return;
      }
    }
    final title = firstUserMessage.length > 50
        ? '${firstUserMessage.substring(0, 50)}…'
        : firstUserMessage;
    final session = ClawSessionInfo(
      id: externalSessionId ?? _newId(),
      title: title,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      source: isRemote ? 'remote' : 'local',
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
    sessionTotalTokens.value = 0;
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

  // ─── ask_user 内联卡片（Plan B）/ Dialog（Plan A）───────────────────────────

  /// AskUserTool 回调：根据设置决定用 Dialog 还是内联卡片。
  Future<String?> _promptAskUser(AskUserRequest request) {
    final useDialog = AppConfigService.shared.config.value.session.askUserUseDialog;
    if (useDialog) {
      return Get.dialog<String>(AskUserDialog(request: request));
    }
    // Plan B：内联卡片
    final requestId = _newId();
    final completer = Completer<String?>();
    pendingUserInput.value = PendingUserInput(
      requestId: requestId,
      request: request,
      completer: completer,
    );
    _scrollToBottom();
    return completer.future;
  }

  /// UI 层调用：用户提交了内联卡片的答案
  void respondUserInput(String requestId, String value) {
    final pending = pendingUserInput.value;
    if (pending == null || pending.requestId != requestId) return;
    pendingUserInput.value = null;
    pending.completer.complete(value);
  }

  /// UI 层调用：用户取消了内联卡片
  void cancelUserInput(String requestId) => _cancelPendingUserInput();

  void _cancelPendingUserInput() {
    final pending = pendingUserInput.value;
    if (pending == null) return;
    pendingUserInput.value = null;
    pending.completer.complete(null);
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



