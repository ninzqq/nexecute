import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nexecute/ai/ai.dart';
import 'package:provider/provider.dart';

class AssistantPage extends StatefulWidget {
  const AssistantPage({super.key});

  @override
  State<AssistantPage> createState() => _AssistantPageState();
}

class _AssistantPageState extends State<AssistantPage> {
  late final AiChatController _controller;
  final _composerController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _controller = AiChatController(
      assistantRepository: context.read<AiAssistantRepository>(),
      connectionProfileStore: context.read<AiConnectionProfileStore>(),
      conversationStore: context.read<AiConversationStore>(),
    )..addListener(_onControllerChanged);
    unawaited(_controller.initialize());
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    _composerController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = _controller.activeProfile;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Assistant'),
            if (profile != null)
              Text(
                '${profile.name} · ${profile.modelId}',
                key: const Key('assistant-active-connection'),
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
        actions: [
          IconButton(
            key: const Key('assistant-new-conversation'),
            tooltip: 'New conversation',
            onPressed: () => unawaited(_controller.startNewConversation()),
            icon: const Icon(Icons.add_comment_outlined),
          ),
          IconButton(
            key: const Key('assistant-conversation-list'),
            tooltip: 'Conversations',
            onPressed: _showConversations,
            icon: const Icon(Icons.history_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (_controller.errorMessage case final error?)
              _ErrorBanner(message: error, onDismiss: _controller.clearError),
            Expanded(child: _buildConversation()),
            _Composer(
              controller: _composerController,
              enabled: !_controller.isLoading && profile != null,
              isGenerating: _controller.isGenerating,
              onSend: _send,
              onStop: () => unawaited(_controller.stopResponse()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConversation() {
    if (_controller.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_controller.activeProfile == null) {
      return _AssistantEmptyState(
        icon: Icons.hub_outlined,
        title: 'Connect an AI endpoint',
        message:
            'Create and select a connection profile before starting a chat.',
        actionLabel: 'Open Settings',
        onAction: () => Navigator.pushNamed(context, '/settings'),
      );
    }
    if (_controller.messages.isEmpty) {
      return const _AssistantEmptyState(
        icon: Icons.auto_awesome_outlined,
        title: 'Start a conversation',
        message:
            'Messages sync through your account. AI requests go only to the selected endpoint.',
      );
    }
    return ListView.builder(
      key: const Key('assistant-message-list'),
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(12, 18, 12, 12),
      itemCount: _controller.messages.length,
      itemBuilder: (context, index) {
        final message = _controller.messages[index];
        return _MessageBubble(
          message: message,
          onRetry:
              message.role == AiMessageRole.assistant &&
                      (message.status == AiMessageStatus.failed ||
                          message.status == AiMessageStatus.cancelled)
                  ? () => unawaited(_controller.retryLastResponse())
                  : null,
        );
      },
    );
  }

  void _send(String text) {
    if (text.trim().isEmpty) return;
    _composerController.clear();
    unawaited(_controller.send(text));
  }

  Future<void> _showConversations() async {
    final selectedId = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder:
          (context) => _ConversationSheet(
            conversations: _controller.conversations,
            activeConversationId: _controller.conversation?.id,
            onDelete: (id) async {
              await _controller.deleteConversation(id);
              if (context.mounted) Navigator.pop(context);
            },
          ),
    );
    if (selectedId == null) return;
    await _controller.openConversation(selectedId);
  }

  void _onControllerChanged() {
    if (!mounted) return;
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    });
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.enabled,
    required this.isGenerating,
    required this.onSend,
    required this.onStop,
  });

  final TextEditingController controller;
  final bool enabled;
  final bool isGenerating;
  final ValueChanged<String> onSend;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          12,
          10,
          12,
          10 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                key: const Key('assistant-composer'),
                controller: controller,
                enabled: enabled && !isGenerating,
                minLines: 1,
                maxLines: 6,
                textInputAction: TextInputAction.newline,
                decoration: const InputDecoration(
                  hintText: 'Message the assistant',
                ),
              ),
            ),
            const SizedBox(width: 10),
            if (isGenerating)
              IconButton.filled(
                key: const Key('assistant-stop'),
                tooltip: 'Stop response',
                onPressed: onStop,
                icon: const Icon(Icons.stop_rounded),
              )
            else
              IconButton.filled(
                key: const Key('assistant-send'),
                tooltip: 'Send',
                onPressed: enabled ? () => onSend(controller.text) : null,
                icon: const Icon(Icons.arrow_upward_rounded),
              ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, this.onRetry});

  final AiChatMessage message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == AiMessageRole.user;
    final colors = Theme.of(context).colorScheme;
    final statusText = switch (message.status) {
      AiMessageStatus.streaming => 'Thinking…',
      AiMessageStatus.cancelled => 'Stopped',
      AiMessageStatus.failed => message.errorMessage ?? 'Response failed',
      AiMessageStatus.complete => null,
    };
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        key: ValueKey('assistant-message-${message.id}'),
        constraints: const BoxConstraints(maxWidth: 680),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: isUser ? colors.primaryContainer : colors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(16).copyWith(
            bottomRight: isUser ? const Radius.circular(4) : null,
            bottomLeft: isUser ? null : const Radius.circular(4),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message.content.isNotEmpty)
              SelectableText(message.content)
            else if (message.status == AiMessageStatus.streaming)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            if (statusText != null) ...[
              const SizedBox(height: 7),
              Text(
                statusText,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color:
                      message.status == AiMessageStatus.failed
                          ? colors.error
                          : colors.onSurfaceVariant,
                ),
              ),
            ],
            if (onRetry != null) ...[
              const SizedBox(height: 6),
              TextButton.icon(
                key: const Key('assistant-retry'),
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AssistantEmptyState extends StatelessWidget {
  const _AssistantEmptyState({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 52,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(title, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(message, textAlign: TextAlign.center),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: 18),
                FilledButton(onPressed: onAction, child: Text(actionLabel!)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onDismiss});

  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return MaterialBanner(
      key: const Key('assistant-error'),
      content: Text(message),
      leading: const Icon(Icons.error_outline_rounded),
      actions: [TextButton(onPressed: onDismiss, child: const Text('Dismiss'))],
    );
  }
}

class _ConversationSheet extends StatelessWidget {
  const _ConversationSheet({
    required this.conversations,
    required this.activeConversationId,
    required this.onDelete,
  });

  final List<AiConversation> conversations;
  final String? activeConversationId;
  final Future<void> Function(String id) onDelete;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.7,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Text(
                'Conversations',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            Expanded(
              child:
                  conversations.isEmpty
                      ? const Center(child: Text('No conversations yet.'))
                      : ListView.builder(
                        itemCount: conversations.length,
                        itemBuilder: (context, index) {
                          final conversation = conversations[index];
                          return ListTile(
                            selected: conversation.id == activeConversationId,
                            leading: const Icon(Icons.chat_bubble_outline),
                            title: Text(
                              conversation.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(conversation.modelId),
                            onTap:
                                () => Navigator.pop(context, conversation.id),
                            trailing: IconButton(
                              tooltip: 'Delete conversation',
                              onPressed: () => onDelete(conversation.id),
                              icon: const Icon(Icons.delete_outline),
                            ),
                          );
                        },
                      ),
            ),
          ],
        ),
      ),
    );
  }
}
