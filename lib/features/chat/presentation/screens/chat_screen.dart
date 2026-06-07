import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
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
  ConsumerState<ChatScreen> createState() => ChatScreenState();
}

class ChatScreenState extends ConsumerState<ChatScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();
  
  List<ChatMessage> _messages = [];
  List<ChatMessage> _filteredMessages = [];
  StreamSubscription? _subscription;
  bool _isLoading = true;
  bool _isSearching = false;
  final _searchController = TextEditingController();
  DateTime? _peerLastReadAt;
  final List<String> _pinnedMessageIds = [];
  
  // Pagination logic
  int _visibleCount = 20;
  bool _loadingMore = false;

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
    
    _scrollController.addListener(_onScroll);

    // Track which chat is active to suppress notifications
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(chattingWithProvider.notifier).update(widget.courseId ?? widget.recipientId);
      }
    });
  }

  void _onScroll() {
    if (_scrollController.position.pixels <= _scrollController.position.minScrollExtent + 100) {
      if (!_loadingMore && _visibleCount < _filteredMessages.length && !_isSearching) {
        _loadMoreMessages();
      }
    }
  }

  void _loadMoreMessages() {
    setState(() {
      _loadingMore = true;
    });

    // Simulate a small delay for smooth feel or just update immediately
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() {
        _visibleCount += 20;
        _loadingMore = false;
      });
    });
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    try {
      final repo = ref.read(chatRepositoryProvider);
      ChatHistory history;
      if (widget.courseId != null && widget.courseId!.isNotEmpty) {
        debugPrint('LOADING COURSE HISTORY: ${widget.courseId}');
        history = await repo.getCourseMessages(widget.courseId!);
        await repo.markAsRead(widget.courseId!);
      } else if (widget.recipientId != null && widget.recipientId!.isNotEmpty) {
        debugPrint('LOADING DIRECT HISTORY: ${widget.recipientId}');
        history = await repo.getDirectMessages(widget.recipientId!);
        await repo.markDirectAsRead(widget.recipientId!);
      } else {
        history = const ChatHistory(messages: []);
      }
      if (!mounted) return;
      
      setState(() {
        _messages = List.from(history.messages);
        _filteredMessages = _messages;
        _peerLastReadAt = history.peerLastReadAt;
        _isLoading = false;
        // Start with 20 or actual count if less
        _visibleCount = 20;
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

  void _runSearch(String query) {
    if (query.isEmpty) {
      setState(() {
        _filteredMessages = _messages;
      });
      return;
    }
    
    setState(() {
      _filteredMessages = _messages.where((m) => 
        m.content.toLowerCase().contains(query.toLowerCase())
      ).toList();
    });
  }

  void _togglePin(String messageId) {
    setState(() {
      if (_pinnedMessageIds.contains(messageId)) {
        _pinnedMessageIds.remove(messageId);
      } else {
        _pinnedMessageIds.add(messageId);
      }
    });
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
                if (!_isSearching) {
                  _filteredMessages = _messages;
                  _scrollToBottom();
                } else {
                  _runSearch(_searchController.text);
                }
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
        if (!_isSearching) _filteredMessages = _messages;
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
    _searchController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    
    // Clear the active chat tracking immediately and safely
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
        : 'Active discussion';

    final profile = ref.watch(profileProvider).value;
    final myId = profile?.id ?? ref.read(authRepositoryProvider).currentUserId;
    final isInstructor = profile?.role == 'instructor' || profile?.role == 'admin';
    final activeColor = AppColors.primary;
    final serverBaseUrl = ref.watch(serverBaseUrlProvider);

    return Scaffold(
      appBar: AppBar(
        title: _isSearching 
          ? TextField(
              controller: _searchController,
              autofocus: true,
              style: const TextStyle(fontSize: 14),
              decoration: const InputDecoration(
                hintText: 'Search in conversation...',
                border: InputBorder.none,
              ),
              onChanged: _runSearch,
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                Text(subtitle, style: TextStyle(fontSize: 10, color: isDark ? Colors.white54 : Colors.black45, fontWeight: FontWeight.w600, letterSpacing: 0.2)),
              ],
            ),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close_rounded : Icons.search_rounded, size: 20), 
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchController.clear();
                  _filteredMessages = _messages;
                }
              });
            }
          ),
          IconButton(
            icon: Icon(
              _pinnedMessageIds.isNotEmpty ? Icons.push_pin_rounded : Icons.push_pin_outlined, 
              size: 20,
              color: _pinnedMessageIds.isNotEmpty ? AppColors.primary : null,
            ), 
            onPressed: () {
              if (_pinnedMessageIds.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Long press a message to pin it'))
                );
              } else {
                // Scroll to first pin or show pinned list
                final firstPinIndex = _messages.indexWhere((m) => _pinnedMessageIds.contains(m.id));
                if (firstPinIndex != -1) {
                  // In a real app we'd scroll to it
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('You have ${_pinnedMessageIds.length} pinned messages'))
                  );
                }
              }
            }
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkBackground : AppColors.background,
        ),
        child: Column(
          children: [
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                  : _filteredMessages.isEmpty
                      ? _buildChatEmptyState(theme, isDark)
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                          itemCount: (_filteredMessages.length > _visibleCount ? _visibleCount : _filteredMessages.length) + 1,
                          itemBuilder: (ctx, i) {
                            if (i == 0) {
                              // Top indicator for loading more
                              if (_filteredMessages.length > _visibleCount) {
                                return Center(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    child: _loadingMore 
                                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                      : Text(
                                          'Scroll up to load older messages', 
                                          style: TextStyle(fontSize: 10, color: isDark ? Colors.white24 : Colors.black26, fontWeight: FontWeight.bold)
                                        ),
                                  ),
                                );
                              }
                              return const SizedBox.shrink();
                            }

                            // Adjust index because of the top indicator
                            final displayIndex = i - 1;
                            
                            // Get the subset of messages (the most recent ones)
                            final startIndex = _filteredMessages.length - (_filteredMessages.length > _visibleCount ? _visibleCount : _filteredMessages.length);
                            final msg = _filteredMessages[startIndex + displayIndex];
                            
                            final isMe = msg.senderId == myId;
                            final isSeen = isMe && _peerLastReadAt != null && msg.timestamp.isBefore(_peerLastReadAt!);
                            final isPinned = _pinnedMessageIds.contains(msg.id);
                            
                            final bool showSender = !isMe && (displayIndex == 0 || _filteredMessages[startIndex + displayIndex - 1].senderId != msg.senderId);
                            final bool isLastInGroup = displayIndex == ( ( _filteredMessages.length > _visibleCount ? _visibleCount : _filteredMessages.length ) - 1 ) || _filteredMessages[startIndex + displayIndex + 1].senderId != msg.senderId;

                            return Padding(
                              padding: EdgeInsets.only(
                                top: (showSender || msg.replyTo != null) ? 16 : 4,
                                bottom: isLastInGroup ? 12 : 0,
                              ),
                              child: Row(
                                mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                                crossAxisAlignment: CrossAxisAlignment.end,
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
                                        backgroundColor: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                                        fallbackText: (msg.senderName ?? '?').isNotEmpty ? msg.senderName![0].toUpperCase() : '?',
                                        fallbackTextColor: isDark ? Colors.white70 : Colors.black54,
                                        fontSize: 10,
                                      )
                                    else
                                      const SizedBox(width: 28),
                                    const SizedBox(width: 12),
                                  ],
                                  
                                  Flexible(
                                    child: Column(
                                      crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                      children: [
                                        if (showSender)
                                          Padding(
                                            padding: const EdgeInsets.only(left: 4, bottom: 6),
                                            child: Text(
                                              msg.senderName ?? 'User',
                                              style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.black45, fontWeight: FontWeight.w700),
                                            ),
                                          ),
                                        
                                        if (msg.replyTo != null)
                                          _buildModernReplyPreview(msg.replyTo!, isDark, isMe),

                                        GestureDetector(
                                          onLongPress: () => _showReactionPicker(msg),
                                          child: Stack(
                                            clipBehavior: Clip.none,
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                                decoration: BoxDecoration(
                                                  color: msg.isDeleted != null
                                                      ? Colors.transparent
                                                      : isMe
                                                          ? activeColor
                                                          : isDark ? AppColors.darkSurface : Colors.white,
                                                  borderRadius: BorderRadius.only(
                                                    topLeft: const Radius.circular(16),
                                                    topRight: const Radius.circular(16),
                                                    bottomLeft: Radius.circular(isMe ? 16 : (isLastInGroup ? 4 : 16)),
                                                    bottomRight: Radius.circular(isMe ? (isLastInGroup ? 4 : 16) : 16),
                                                  ),
                                                  border: isPinned 
                                                      ? Border.all(color: AppColors.primary, width: 2)
                                                      : (msg.isDeleted != null 
                                                          ? null 
                                                          : Border.all(color: isMe ? Colors.transparent : (isDark ? AppColors.darkBorder : AppColors.border))),
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
                                                              : isMe ? Colors.black : theme.colorScheme.onSurface,
                                                          fontSize: 14,
                                                          fontWeight: isMe ? FontWeight.w600 : FontWeight.w500,
                                                          fontStyle: msg.isDeleted != null ? FontStyle.italic : FontStyle.normal,
                                                        ),
                                                      ),
                                                    if (msg.attachmentUrl != null && msg.attachmentUrl!.isNotEmpty && msg.isDeleted == null) ...[
                                                      if (!(msg.attachmentUrl != null && msg.attachmentUrl!.isNotEmpty && msg.content.trim().toLowerCase() == (msg.attachmentName ?? msg.attachmentUrl!.split('/').last).toLowerCase()))
                                                         const SizedBox(height: 8),
                                                      _buildModernAttachment(msg, isMe, serverBaseUrl),
                                                    ],
                                                  ],
                                                ),
                                              ),
                                              if (msg.isDeleted == null && (msg.likes.isNotEmpty || msg.dislikes.isNotEmpty))
                                                Positioned(
                                                  bottom: -10,
                                                  right: isMe ? null : -4,
                                                  left: isMe ? -4 : null,
                                                  child: _buildModernReactionBadge(msg, isDark, myId),
                                                ),
                                            ],
                                          ),
                                        ),
                                        if (isLastInGroup)
                                          Padding(
                                            padding: const EdgeInsets.only(top: 6, right: 4, left: 4),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                if (isPinned)
                                                  const Padding(
                                                    padding: EdgeInsets.only(right: 4),
                                                    child: Icon(Icons.push_pin_rounded, size: 10, color: AppColors.primary),
                                                  ),
                                                Text(
                                                  _formatTime(msg.timestamp),
                                                  style: TextStyle(fontSize: 9, color: isDark ? Colors.white24 : Colors.black26, fontWeight: FontWeight.bold),
                                                ),
                                                if (isMe) ...[
                                                  const SizedBox(width: 4),
                                                  Icon(
                                                    Icons.done_all_rounded, 
                                                    size: 11, 
                                                    color: isSeen ? Colors.blue : (isDark ? Colors.white10 : Colors.black12)
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  
                                  if (isMe) const SizedBox(width: 8),
                                  if (isLastInGroup)
                                     PopupMenuButton<String>(
                                      icon: Icon(Icons.more_horiz, size: 14, color: isDark ? Colors.white24 : Colors.black26),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onSelected: (val) {
                                        if (val == 'edit') _onEdit(msg);
                                        if (val == 'delete') _onDelete(msg);
                                        if (val == 'copy') {
                                          Clipboard.setData(ClipboardData(text: msg.content));
                                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied')));
                                        }
                                        if (val == 'reply') _onReply(msg);
                                        if (val == 'pin') _togglePin(msg.id);
                                        if (val == 'react') _showReactionPicker(msg);
                                      },
                                      itemBuilder: (ctx) => [
                                        const PopupMenuItem(value: 'reply', child: Text('Reply')),
                                        const PopupMenuItem(value: 'react', child: Text('React')),
                                        const PopupMenuItem(value: 'copy', child: Text('Copy')),
                                        PopupMenuItem(value: 'pin', child: Text(isPinned ? 'Unpin' : 'Pin')),
                                        if (isMe) const PopupMenuItem(value: 'edit', child: Text('Edit')),
                                        if (isMe) const PopupMenuItem(value: 'delete', child: Text('Delete')),
                                      ],
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
            ),
            _buildActiveActionPreview(theme, isDark),
            _buildModernInputArea(context, theme, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildChatEmptyState(ThemeData theme, bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.03),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _isSearching ? Icons.search_off_rounded : Icons.chat_bubble_outline_rounded, 
              size: 48, 
              color: isDark ? Colors.white24 : Colors.black12
            ),
          ),
          const SizedBox(height: 24),
          Text(
            _isSearching ? 'No results found' : 'No messages here yet',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700, color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          Text(
            _isSearching 
              ? 'Try a different keyword.' 
              : (widget.recipientId != null ? 'Start a private conversation.' : 'Be the first to share a thought!'),
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5), fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildModernReplyPreview(ChatMessageReply reply, bool isDark, bool isMe) {
    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Text(
            reply.senderName ?? 'User',
            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: AppColors.primary),
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

  Widget _buildModernInputArea(BuildContext context, ThemeData theme, bool isDark) {
    return Container(
      padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).padding.bottom + 20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        border: Border(top: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_attachmentBytes != null)
             _buildSelectedAttachmentPreview(isDark),
          Row(
            children: [
              IconButton(
                onPressed: _pickAttachment,
                icon: const Icon(Icons.add_circle_outline_rounded, size: 24),
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.05) : AppColors.background,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: isDark ? Colors.white10 : AppColors.border),
                  ),
                  child: TextField(
                    controller: _textController,
                    focusNode: _focusNode,
                    style: const TextStyle(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                onPressed: _sendMessage,
                icon: const Icon(Icons.send_rounded, size: 22),
                color: AppColors.primary,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedAttachmentPreview(bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.03) : AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.file_present_rounded, color: AppColors.primary, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(_attachmentName ?? 'File', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
          IconButton(icon: const Icon(Icons.close, size: 18), onPressed: _clearAttachment),
        ],
      ),
    );
  }

  Widget _buildModernReactionBadge(ChatMessage msg, bool isDark, String? myId) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? Colors.white10 : AppColors.border),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (msg.likes.isNotEmpty) const Text('👍', style: TextStyle(fontSize: 10)),
          if (msg.dislikes.isNotEmpty) const Text('👎', style: TextStyle(fontSize: 10)),
          if (msg.likes.length + msg.dislikes.length > 1)
             Padding(
               padding: const EdgeInsets.only(left: 4),
               child: Text('${msg.likes.length + msg.dislikes.length}', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
             ),
        ],
      ),
    );
  }

  Widget _buildModernAttachment(ChatMessage msg, bool isMe, String serverBaseUrl) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final attachmentName = msg.attachmentName ?? msg.attachmentUrl!.split('/').last;
    final isImage = (msg.attachmentType ?? '').toLowerCase() == 'image' ||
        ['.png', '.jpg', '.jpeg', '.webp', '.gif'].any((ext) => attachmentName.toLowerCase().endsWith(ext));

    final fullUrl = msg.attachmentUrl!.startsWith('http')
        ? msg.attachmentUrl!
        : '$serverBaseUrl${msg.attachmentUrl!.startsWith('/') ? '' : '/'}${msg.attachmentUrl!}';

    return GestureDetector(
      onTap: () async {
        final uri = Uri.parse(fullUrl);
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      },
      child: Container(
        constraints: const BoxConstraints(maxWidth: 240),
        decoration: BoxDecoration(
          color: isMe ? Colors.black12 : (isDark ? Colors.white.withValues(alpha: 0.05) : AppColors.background),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isImage)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  fullUrl,
                  width: 240,
                  height: 160,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_attachmentIcon(msg.attachmentType, attachmentName), size: 16, color: isMe ? Colors.black87 : AppColors.primary),
                  const SizedBox(width: 8),
                  Flexible(child: Text(attachmentName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
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
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(40),
            border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 30, offset: const Offset(0, 10)),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _reactionItem('👍', 'like', msg),
              const SizedBox(width: 12),
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
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: hasReacted ? AppColors.primary.withValues(alpha: 0.15) : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Text(emoji, style: const TextStyle(fontSize: 28)),
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
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(dt.year, dt.month, dt.day);
    
    final diff = now.difference(dt);
    
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    
    if (messageDate == today) {
      return DateFormat('HH:mm').format(dt);
    }
    
    final yesterday = today.subtract(const Duration(days: 1));
    if (messageDate == yesterday) {
      return 'Yesterday ${DateFormat('HH:mm').format(dt)}';
    }
    
    if (now.year == dt.year) {
      return DateFormat('MMM d, HH:mm').format(dt);
    }
    
    return DateFormat('MM/dd/yy HH:mm').format(dt);
  }
}

