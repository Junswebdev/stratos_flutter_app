import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:stratos_app/core/theme.dart';
import 'package:stratos_app/core/widgets/minimalist_widgets.dart';
import 'package:stratos_app/core/socket_service.dart';

import '../../../../data/dio_client.dart';
import '../../../home/application/home_providers.dart';
import '../../../auth/data/auth_repository.dart';
import '../../data/chat_repository.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({
    super.key,
    this.courseId,
    this.courseName,
    this.recipientId,
    this.recipientName,
  });

  final String? courseId;
  final String? courseName;
  final String? recipientId;
  final String? recipientName;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();
  
  List<ChatMessage> _messages = [];
  StreamSubscription? _subscription;
  bool _isLoading = true;
  DateTime? _peerLastReadAt;
  
  ChatMessage? _replyingTo;
  ChatMessage? _editingMessage;
  Uint8List? _attachmentBytes;
  String? _attachmentName;

  @override
  void initState() {
    super.initState();
    debugPrint('CHAT SCREEN INIT: courseId=${widget.courseId}, recipientId=${widget.recipientId}');
    _loadHistory();
    _subscribeToMessages();
    
    // Track which chat is active to suppress notifications
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(chattingWithProvider.notifier).update(widget.courseId ?? widget.recipientId);
      }
    });
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    try {
      final repo = ref.read(chatRepositoryProvider);
      ChatHistory history;
      if (widget.courseId != null && widget.courseId!.isNotEmpty) {
        history = await repo.getCourseMessages(widget.courseId!);
        await repo.markAsRead(widget.courseId!);
      } else if (widget.recipientId != null && widget.recipientId!.isNotEmpty) {
        history = await repo.getDirectMessages(widget.recipientId!);
        await repo.markDirectAsRead(widget.recipientId!);
      } else {
        history = const ChatHistory(messages: []);
      }
      if (!mounted) return;
      
      setState(() {
        _messages = List.from(history.messages);
        _peerLastReadAt = history.peerLastReadAt;
        _isLoading = false;
      });
      _scrollToBottom();
    } catch (e, stack) {
      debugPrint('FAILED TO LOAD HISTORY: $e');
      debugPrint(stack.toString());
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _subscribeToMessages() {
    final repo = ref.read(chatRepositoryProvider);
    final socketEventStream = ref.read(socketServiceProvider).eventStream;

    _subscription = socketEventStream.listen((event) {
      final type = event['type'] as String?;
      
      if (type == 'read_receipt') {
        final userId = event['user_id'] as String?;
        if (userId == widget.recipientId) {
          final timestamp = DateTime.tryParse(event['last_read_at']?.toString() ?? '');
          if (timestamp != null && mounted) {
            setState(() {
              _peerLastReadAt = timestamp;
            });
          }
        }
        return;
      }

      if (type == 'message' || type == 'reaction' || type == 'edit' || type == 'delete') {
        try {
          final msg = ChatMessage.fromJson(event);
          final myId = ref.read(authRepositoryProvider).currentUserId;
          
          final isRelevant = (widget.courseId != null && msg.courseId == widget.courseId) ||
              (widget.recipientId != null && (msg.senderId == widget.recipientId || msg.recipientId == widget.recipientId));
          
          if (isRelevant && mounted) {
            setState(() {
              final index = _messages.indexWhere((m) => m.id == msg.id);
              if (index != -1) {
                _messages[index] = msg;
              } else {
                _messages = [..._messages, msg];
                _scrollToBottom();
              }
            });

            // If we are active in this chat and receive a message from peer, mark it as read
            if (msg.senderId != myId) {
               try {
                 if (widget.courseId != null) {
                   repo.markAsRead(widget.courseId!);
                 } else if (widget.recipientId != null) {
                   repo.markDirectAsRead(widget.recipientId!);
                 }
               } catch (_) {}
            }
          }
        } catch (e) {
          debugPrint('Error parsing websocket message: $e');
        }
      }
    });
  }

  void _sendMessage() {
    final text = _textController.text.trim();
    if (text.isEmpty && _attachmentBytes == null) return;
    
    final repo = ref.read(chatRepositoryProvider);

    if (_editingMessage != null) {
      repo.editMessage(messageId: _editingMessage!.id, content: text);
      setState(() => _editingMessage = null);
    } else if (_attachmentBytes != null && _attachmentName != null) {
      unawaited(_sendAttachment(text));
    } else {
      repo.sendMessage(
        content: text,
        courseId: widget.courseId,
        recipientId: widget.recipientId,
        replyToId: _replyingTo?.id,
      );
      setState(() => _replyingTo = null);
    }

    _textController.clear();
    _clearAttachment();
    _focusNode.unfocus();
  }

  Future<void> _pickAttachment() async {
    final result = await FilePicker.platform.pickFiles(withData: true);
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.bytes == null) return;

    setState(() {
      _attachmentBytes = file.bytes;
      _attachmentName = file.name;
    });
    _focusNode.requestFocus();
  }

  Future<void> _sendAttachment(String caption) async {
    final bytes = _attachmentBytes;
    final name = _attachmentName;
    if (bytes == null || name == null) return;

    final repo = ref.read(chatRepositoryProvider);
    try {
      final msg = await repo.sendAttachmentMessage(
        fileBytes: bytes,
        fileName: name,
        content: caption,
        courseId: widget.courseId,
        recipientId: widget.recipientId,
        replyToId: _replyingTo?.id,
      );
      if (!mounted) return;
      setState(() {
        final index = _messages.indexWhere((m) => m.id == msg.id);
        if (index != -1) {
          _messages[index] = msg;
        } else {
          _messages = [..._messages, msg];
        }
        _replyingTo = null;
      });
      _scrollToBottom();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to send attachment')),
      );
    }
  }

  void _clearAttachment() {
    if (_attachmentBytes == null && _attachmentName == null) return;
    setState(() {
      _attachmentBytes = null;
      _attachmentName = null;
    });
  }

  void _onEdit(ChatMessage msg) {
    setState(() {
      _editingMessage = msg;
      _replyingTo = null;
      _textController.text = msg.content;
    });
    _focusNode.requestFocus();
  }

  void _onDelete(ChatMessage msg) {
    ref.read(chatRepositoryProvider).deleteMessage(msg.id);
  }

  void _onReply(ChatMessage msg) {
    setState(() {
      _replyingTo = msg;
      _editingMessage = null;
    });
    _focusNode.requestFocus();
  }

  void _reactToMessage(String messageId, String reactionType) {
    ref.read(chatRepositoryProvider).sendReaction(
      messageId: messageId,
      reactionType: reactionType,
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _textController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    
    // Clear the active chat tracking immediately and safely
    // Note: We avoid using WidgetsBinding here because it might trigger after unmount
    ref.read(chattingWithProvider.notifier).update(null);
    
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.courseName ?? widget.recipientName ?? (widget.recipientId != null ? 'Direct Message' : 'Chat');
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final subtitle = widget.recipientId != null
        ? 'Private conversation'
        : 'Active now';

    final profile = ref.watch(profileProvider).value;
    final myId = profile?.id ?? ref.read(authRepositoryProvider).currentUserId;
    final isInstructor = profile?.role == 'instructor' || profile?.role == 'admin';
    final activeColor = isInstructor ? AppColors.primary : AppColors.secondary;
    final serverBaseUrl = ref.watch(serverBaseUrlProvider);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text(subtitle, style: const TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.w500)),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.info_outline), onPressed: () {}),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.chat_bubble_outline, size: 48, color: theme.colorScheme.primary),
                            ),
                            const SizedBox(height: 16),
                            const Text('No messages yet', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                            Text(
                              widget.recipientId != null
                                  ? 'Send the first private message.'
                                  : 'Start a conversation with your classmates',
                              style: const TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                        itemCount: _messages.length,
                        itemBuilder: (ctx, i) {
                          final msg = _messages[i];
                          final isMe = msg.senderId == myId;
                          final isSeen = isMe && _peerLastReadAt != null && msg.timestamp.isBefore(_peerLastReadAt!);
                          
                          final bool showSender = !isMe && (i == 0 || _messages[i-1].senderId != msg.senderId);
                          final bool isLastInGroup = i == _messages.length - 1 || _messages[i+1].senderId != msg.senderId;

                          return Padding(
                            padding: EdgeInsets.only(
                              top: (showSender || msg.replyTo != null) ? 12 : 2,
                              bottom: isLastInGroup ? 8 : 0,
                            ),
                            child: Row(
                              mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                if (!isMe) ...[
                                  if (isLastInGroup)
                                    SafeAvatar(
                                      imageUrl: msg.senderAvatarUrl != null && msg.senderAvatarUrl!.isNotEmpty
                                          ? (msg.senderAvatarUrl!.startsWith('http')
                                              ? msg.senderAvatarUrl!
                                              : '$serverBaseUrl${msg.senderAvatarUrl!.startsWith('/') ? '' : '/'}${msg.senderAvatarUrl!}')
                                          : null,
                                      radius: 14,
                                      backgroundColor: theme.colorScheme.outline.withValues(alpha: 0.2),
                                      fallbackText: (msg.senderName ?? '?').isNotEmpty ? msg.senderName![0].toUpperCase() : '?',
                                      fallbackTextColor: theme.colorScheme.onSurfaceVariant,
                                      fontSize: 10,
                                    )
                                  else
                                    const SizedBox(width: 28),
                                  const SizedBox(width: 8),
                                ],
                                
                                if (isMe && msg.isDeleted == null) _buildMoreButton(msg),

                                Flexible(
                                  child: GestureDetector(
                                    onLongPress: () => _showReactionPicker(msg),
                                    child: Column(
                                      crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                      children: [
                                        if (showSender)
                                          Padding(
                                            padding: const EdgeInsets.only(left: 4, bottom: 4),
                                            child: Text(
                                              msg.senderName ?? 'User',
                                              style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                                            ),
                                          ),
                                        
                                        if (msg.replyTo != null)
                                          _buildReplyContext(msg.replyTo!, isDark, isMe),

                                        Stack(
                                          clipBehavior: Clip.none,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                              decoration: BoxDecoration(
                                                color: msg.isDeleted != null
                                                    ? Colors.transparent
                                                    : isMe
                                                        ? activeColor
                                                        : theme.colorScheme.surfaceContainerHigh,
                                                borderRadius: BorderRadius.circular(16),
                                              ),
                                              child: Column(
                                                crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  if (!(msg.attachmentUrl != null && msg.content.trim().toLowerCase() == (msg.attachmentName ?? msg.attachmentUrl!.split('/').last).toLowerCase()))
                                                    Text(
                                                      msg.content,
                                                      style: TextStyle(
                                                        color: msg.isDeleted != null
                                                            ? Colors.grey
                                                            : isMe ? Colors.white : theme.colorScheme.onSurface,
                                                        fontSize: 15,
                                                        fontStyle: msg.isDeleted != null ? FontStyle.italic : FontStyle.normal,
                                                      ),
                                                    ),
                                                  if (msg.attachmentUrl != null && msg.isDeleted == null) ...[
                                                    if (!(msg.attachmentUrl != null && msg.content.trim().toLowerCase() == (msg.attachmentName ?? msg.attachmentUrl!.split('/').last).toLowerCase()))
                                                       const SizedBox(height: 8),
                                                    _buildAttachmentBubble(msg, isMe, serverBaseUrl),
                                                  ],
                                                  if (msg.isEdited != null && msg.isDeleted == null)
                                                    Padding(
                                                      padding: const EdgeInsets.only(top: 2),
                                                      child: Text(
                                                        'edited',
                                                        style: TextStyle(fontSize: 9, color: isMe ? Colors.white70 : theme.colorScheme.onSurfaceVariant),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ),
                                            if (msg.isDeleted == null && (msg.likes.isNotEmpty || msg.dislikes.isNotEmpty))
                                              Positioned(
                                                bottom: -12,
                                                right: isMe ? null : -5,
                                                left: isMe ? -5 : null,
                                                child: _buildReactionBadge(msg, isDark, myId),
                                              ),
                                          ],
                                        ),
                                        if (isLastInGroup)
                                          Padding(
                                            padding: const EdgeInsets.only(top: 4, right: 4, left: 4),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  _formatTime(msg.timestamp),
                                                  style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                                                ),
                                                if (isMe) ...[
                                                  const SizedBox(width: 4),
                                                  Icon(
                                                    Icons.done_all_rounded, 
                                                    size: 12, 
                                                    color: isSeen ? Colors.blue : activeColor.withValues(alpha: 0.6)
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),

                                if (!isMe && msg.isDeleted == null) _buildMoreButton(msg),
                              ],
                            ),
                          );
                        },
                      ),
          ),
          _buildActiveActionPreview(theme, isDark),
          _buildInputArea(context, theme, isDark),
        ],
      ),
    );
  }

  Widget _buildReplyContext(ChatMessageReply reply, bool isDark, bool isMe) {
    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(14),
          topRight: Radius.circular(14),
        ),
      ),
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Text(
            reply.senderName ?? 'User',
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey),
          ),
          Text(
            reply.content,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveActionPreview(ThemeData theme, bool isDark) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      transitionBuilder: (child, animation) {
        return SizeTransition(
          sizeFactor: animation,
          axisAlignment: -1.0,
          child: FadeTransition(opacity: animation, child: child),
        );
      },
      child: (_replyingTo == null && _editingMessage == null)
          ? const SizedBox.shrink()
          : Container(
              key: ValueKey(_editingMessage?.id ?? _replyingTo?.id ?? 'none'),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHigh,
                border: Border(top: BorderSide(color: theme.colorScheme.outlineVariant)),
              ),
              child: Row(
                children: [
                  Icon(
                    _editingMessage != null ? Icons.edit : Icons.reply, 
                    size: 18, 
                    color: theme.colorScheme.primary
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _editingMessage != null 
                              ? 'Editing message' 
                              : 'Replying to ${_replyingTo?.senderName ?? 'User'}',
                          style: TextStyle(
                            fontSize: 12, 
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary
                          ),
                        ),
                        Text(
                          (_editingMessage ?? _replyingTo)?.content ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () {
                      setState(() {
                        _replyingTo = null;
                        if (_editingMessage != null) {
                          _editingMessage = null;
                          _textController.clear();
                        }
                      });
                    },
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildMoreButton(ChatMessage msg) {
    final myId = ref.read(authRepositoryProvider).currentUserId;
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_horiz, size: 18, color: AppColors.textSecondary),
      tooltip: 'Message actions',
      onSelected: (val) {
        if (val == 'react') _showReactionPicker(msg);
        if (val == 'reply') _onReply(msg);
        if (val == 'copy') {
          Clipboard.setData(ClipboardData(text: msg.content));
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Message copied to clipboard')));
        }
        if (val == 'edit') _onEdit(msg);
        if (val == 'delete') _onDelete(msg);
      },
      itemBuilder: (ctx) => [
        const PopupMenuItem(value: 'react', child: Row(children: [Icon(Icons.add_reaction_outlined, size: 18), SizedBox(width: 8), Text('React')])),
        const PopupMenuItem(value: 'reply', child: Row(children: [Icon(Icons.reply_outlined, size: 18), SizedBox(width: 8), Text('Reply')])),
        const PopupMenuItem(value: 'copy', child: Row(children: [Icon(Icons.copy_rounded, size: 18), SizedBox(width: 8), Text('Copy')])),
        if (msg.senderId == myId)
          const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit_outlined, size: 18), SizedBox(width: 8), Text('Edit')])),
        if (msg.senderId == myId)
          const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_outline, size: 18, color: AppColors.danger), SizedBox(width: 8), Text('Delete', style: TextStyle(color: AppColors.danger))])),
      ],
    );
  }

  Widget _buildReactionBadge(ChatMessage msg, bool isDark, String? myId) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white24 : Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (msg.likes.isNotEmpty) ...[
            const Text('👍', style: TextStyle(fontSize: 11)),
            if (msg.likes.length > 1)
              Padding(
                padding: const EdgeInsets.only(left: 3),
                child: Text(
                  '${msg.likes.length}', 
                  style: TextStyle(
                    fontSize: 10, 
                    fontWeight: FontWeight.w900, 
                    color: isDark ? Colors.white : Colors.black87
                  ),
                ),
              ),
          ],
          if (msg.likes.isNotEmpty && msg.dislikes.isNotEmpty) const SizedBox(width: 4),
          if (msg.dislikes.isNotEmpty) ...[
            const Text('👎', style: TextStyle(fontSize: 11)),
            if (msg.dislikes.length > 1)
              Padding(
                padding: const EdgeInsets.only(left: 3),
                child: Text(
                  '${msg.dislikes.length}', 
                  style: TextStyle(
                    fontSize: 10, 
                    fontWeight: FontWeight.w900, 
                    color: isDark ? Colors.white : Colors.black87
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildAttachmentBubble(ChatMessage msg, bool isMe, String serverBaseUrl) {
    final theme = Theme.of(context);
    final attachmentName = msg.attachmentName ?? msg.attachmentUrl!.split('/').last;
    final isImage = (msg.attachmentType ?? '').toLowerCase() == 'image' ||
        attachmentName.toLowerCase().endsWith('.png') ||
        attachmentName.toLowerCase().endsWith('.jpg') ||
        attachmentName.toLowerCase().endsWith('.jpeg') ||
        attachmentName.toLowerCase().endsWith('.webp') ||
        attachmentName.toLowerCase().endsWith('.gif');

    final fullUrl = msg.attachmentUrl!.startsWith('http')
        ? msg.attachmentUrl!
        : '$serverBaseUrl${msg.attachmentUrl!.startsWith('/') ? '' : '/'}${msg.attachmentUrl!}';

    return GestureDetector(
      onTap: () async {
        final uri = Uri.parse(fullUrl);
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      },
      child: Container(
        constraints: const BoxConstraints(maxWidth: 220),
        decoration: BoxDecoration(
          color: isMe 
              ? Colors.white.withValues(alpha: 0.12) 
              : theme.colorScheme.surface.withValues(alpha: theme.brightness == Brightness.dark ? 0.3 : 1.0),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isMe ? Colors.white24 : theme.colorScheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isImage)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  fullUrl,
                  width: 220,
                  height: 140,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_attachmentIcon(msg.attachmentType, attachmentName), size: 16, color: isMe ? Colors.white : AppColors.primary),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      attachmentName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: isMe ? Colors.white : theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showReactionPicker(ChatMessage msg) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Center(
        child: Container(
          margin: const EdgeInsets.all(16),
          constraints: const BoxConstraints(maxWidth: 300, maxHeight: 100),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
          decoration: BoxDecoration(
            color: isDark ? theme.colorScheme.surfaceContainerHigh : Colors.white,
            borderRadius: BorderRadius.circular(40),
            border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _reactionItem('👍', 'like', msg),
              _reactionItem('👎', 'dislike', msg),
            ],
          ),
        ),
      ),
    );
  }

  Widget _reactionItem(String emoji, String type, ChatMessage msg) {
    final myId = ref.read(authRepositoryProvider).currentUserId;
    final hasReacted = type == 'like' 
        ? msg.likes.contains(myId)
        : msg.dislikes.contains(myId);

    return GestureDetector(
      onTap: () {
        _reactToMessage(msg.id, type);
        Navigator.pop(context);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: hasReacted ? AppColors.primary.withValues(alpha: 0.25) : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Transform.scale(
          scale: hasReacted ? 1.2 : 1.0,
          child: Text(emoji, style: const TextStyle(fontSize: 34)),
        ),
      ),
    );
  }

  Widget _buildInputArea(BuildContext context, ThemeData theme, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(top: BorderSide(color: theme.colorScheme.outlineVariant)),
      ),
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 12,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_attachmentBytes != null && _attachmentName != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Icon(_attachmentIcon(null, _attachmentName!), color: theme.colorScheme.primary, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _attachmentName!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: _clearAttachment,
                  ),
                ],
              ),
            ),
          Row(
            children: [
              IconButton(
                tooltip: 'Attach file',
                onPressed: _pickAttachment,
                icon: Icon(Icons.attach_file_rounded, color: theme.colorScheme.primary),
              ),
              Expanded(
                child: TextField(
                  controller: _textController,
                  focusNode: _focusNode,
                  decoration: InputDecoration(
                    hintText: widget.recipientId != null ? 'Message privately...' : 'Type something...',
                    filled: true,
                    fillColor: theme.colorScheme.surfaceContainerHigh,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                icon: Icon(Icons.send_rounded, color: theme.colorScheme.primary),
                onPressed: _sendMessage,
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _attachmentIcon(String? attachmentType, String fileName) {
    final type = (attachmentType ?? '').toLowerCase();
    if (type == 'image') return Icons.image_rounded;
    if (type == 'video') return Icons.videocam_rounded;
    if (type == 'audio') return Icons.audiotrack_rounded;
    if (type == 'document') return Icons.description_rounded;
    final ext = fileName.split('.').last.toLowerCase();
    if (['png', 'jpg', 'jpeg', 'webp', 'gif'].contains(ext)) return Icons.image_rounded;
    if (['mp4', 'mov', 'webm'].contains(ext)) return Icons.videocam_rounded;
    if (['mp3', 'wav', 'm4a', 'aac'].contains(ext)) return Icons.audiotrack_rounded;
    if (['pdf', 'doc', 'docx', 'ppt', 'pptx', 'xls', 'xlsx', 'txt', 'csv'].contains(ext)) return Icons.description_rounded;
    return Icons.attach_file_rounded;
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    return '${dt.month}/${dt.day} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
