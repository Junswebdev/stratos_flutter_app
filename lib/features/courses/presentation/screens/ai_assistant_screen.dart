import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../data/course_repository.dart';
import '../../../../core/theme.dart';
import '../../../../features/home/application/home_providers.dart';

class AIAssistantScreen extends ConsumerStatefulWidget {
  const AIAssistantScreen({super.key, required this.courseId, required this.courseTitle});

  final String courseId;
  final String courseTitle;

  @override
  ConsumerState<AIAssistantScreen> createState() => _AIAssistantScreenState();
}

class _AIAssistantScreenState extends ConsumerState<AIAssistantScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<_ChatMessage> _messages = [];
  bool _isLoading = false;
  final ScrollController _scrollController = ScrollController();
  static const List<String> _suggestions = [
    'Summarize the key ideas',
    'Quiz me on this lesson',
    'Explain it in simple terms',
  ];

  @override
  void initState() {
    super.initState();
    _messages.add(_ChatMessage(
      text: "Hi! I'm your Stratos AI assistant for **${widget.courseTitle}**. Ask me anything about the course material!",
      isAi: true,
      isStreaming: false,
    ));
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isLoading) return;

    setState(() {
      _messages.add(_ChatMessage(text: text, isAi: false));
      _controller.clear();
      _isLoading = true;
    });
    _scrollToBottom();

    try {
      final answer = await ref.read(courseRepositoryProvider).askAI(
        courseId: widget.courseId,
        question: text,
      );
      if (mounted) {
        setState(() {
          _isLoading = false;
          _messages.add(_ChatMessage(text: "", isAi: true, isStreaming: true));
        });
        _scrollToBottom();
        _streamText(answer);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add(_ChatMessage(text: "Sorry, I couldn't process that. Make sure your MISTRAL_API_KEY is set up correctly in the backend .env file.", isAi: true));
          _isLoading = false;
        });
      }
    }
    _scrollToBottom();
  }

  void _streamText(String fullText) async {
    final words = fullText.split(' ');
    String currentText = "";
    final int messageIndex = _messages.length - 1;

    for (var i = 0; i < words.length; i++) {
      await Future.delayed(const Duration(milliseconds: 30));
      if (!mounted) return;
      
      currentText += (i == 0 ? "" : " ") + words[i];
      setState(() {
        _messages[messageIndex] = _ChatMessage(
          text: currentText, 
          isAi: true, 
          isStreaming: i < words.length - 1
        );
      });
      _scrollToBottom();
    }
  }

  void _clearChat() {
    setState(() {
      _messages
        ..clear()
        ..add(_ChatMessage(
          text: "Hi! I'm your Stratos AI assistant for **${widget.courseTitle}**. Ask me anything about the course material!",
          isAi: true,
          isStreaming: false,
        ));
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final profile = ref.watch(profileProvider).asData?.value;
    final isInstructor = profile?.role == 'instructor' || profile?.role == 'admin';
    final accentColor = isInstructor ? AppColors.primary : AppColors.secondary;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(isInstructor ? "AI Teaching Assistant" : "AI Study Buddy", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
            Text(widget.courseTitle, style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.black54)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Clear chat',
            onPressed: _clearChat,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                return _ChatBubble(message: msg, accentColor: accentColor);
              },
            ),
          ),
          if (_isLoading)
            _ThinkingIndicator(accentColor: accentColor),
          if (_messages.length <= 1)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _suggestions
                    .map(
                      (text) => ActionChip(
                        label: Text(text),
                        onPressed: () {
                          _controller.text = text;
                          _sendMessage();
                        },
                      ),
                    )
                    .toList(),
              ),
            ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : Colors.white,
              border: Border(top: BorderSide(color: AppColors.border.withValues(alpha: 0.5))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    onSubmitted: (_) => _sendMessage(),
                    decoration: InputDecoration(
                      hintText: "Ask about the course...",
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                      filled: true,
                      fillColor: isDark ? Colors.black12 : Colors.grey[100],
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: accentColor,
                  child: IconButton(
                    onPressed: _sendMessage,
                    icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatMessage {
  final String text;
  final bool isAi;
  final bool isStreaming;
  _ChatMessage({required this.text, required this.isAi, this.isStreaming = false});
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.message, required this.accentColor});
  final _ChatMessage message;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Align(
      alignment: message.isAi ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.85),
        decoration: BoxDecoration(
          color: message.isAi 
              ? (isDark ? AppColors.darkCard : Colors.grey[200]) 
              : accentColor,
          borderRadius: BorderRadius.circular(20).copyWith(
            bottomLeft: message.isAi ? Radius.zero : null,
            bottomRight: message.isAi ? null : Radius.zero,
          ),
          boxShadow: [
            if (!message.isAi)
              BoxShadow(
                color: accentColor.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              )
          ],
        ),
        child: message.isAi 
          ? MarkdownBody(
              data: message.text,
              selectable: true,
              styleSheet: MarkdownStyleSheet(
                p: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontSize: 14,
                ),
              ),
            )
          : Text(
              message.text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
      ),
    );
  }
}

class _ThinkingIndicator extends StatefulWidget {
  const _ThinkingIndicator({required this.accentColor});
  final Color accentColor;

  @override
  State<_ThinkingIndicator> createState() => _ThinkingIndicatorState();
}

class _ThinkingIndicatorState extends State<_ThinkingIndicator> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(left: 16, bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.grey[200],
          borderRadius: BorderRadius.circular(20).copyWith(bottomLeft: Radius.zero),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            return AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                final delay = index * 0.2;
                final value = ( (_controller.value + delay) % 1.0 );
                final verticalOffset = -5 * (1.0 - (value - 0.5).abs() * 2);
                
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Transform.translate(
                    offset: Offset(0, verticalOffset),
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: widget.accentColor.withValues(alpha: 0.6),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                );
              },
            );
          }),
        ),
      ),
    );
  }
}
