// lib/presentation/widgets/chat/chat_input.dart
import 'package:flutter/material.dart';
import '../../../core/theme/colors.dart';

class ChatInput extends StatefulWidget {
  final Function(String) onSendMessage;
  final VoidCallback? onCancel;
  final bool isEnabled;
  final bool isSending;
  
  const ChatInput({
    super.key,
    required this.onSendMessage,
    this.onCancel,
    this.isEnabled = true,
    this.isSending = false,
  });
  
  @override
  State<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends State<ChatInput> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  
  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _focusNode = FocusNode();
  }
  
  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }
  
  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isNotEmpty && widget.isEnabled) {
      widget.onSendMessage(text);
      _controller.clear();
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(
          top: BorderSide(color: AppColors.outline, width: 1),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.inputBackground,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.inputBorder),
              ),
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                enabled: widget.isEnabled,
                maxLines: null,
                textInputAction: TextInputAction.send,
                decoration: const InputDecoration(
                  hintText: 'Chiedimi qualsiasi cosa...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(
                    color: AppColors.textTertiary,
                    fontSize: 14,
                  ),
                ),
                onSubmitted: widget.isEnabled ? (_) => _sendMessage() : null,
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (widget.isSending)
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.error,
                borderRadius: BorderRadius.circular(24),
              ),
              child: IconButton(
                onPressed: widget.onCancel,
                icon: const Icon(Icons.close, color: Colors.white),
                tooltip: 'Annulla',
              ),
            )
          else
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _controller.text.trim().isNotEmpty && widget.isEnabled
                    ? AppColors.primary
                    : AppColors.outline,
                borderRadius: BorderRadius.circular(24),
              ),
              child: IconButton(
                onPressed: _controller.text.trim().isNotEmpty && widget.isEnabled
                    ? _sendMessage
                    : null,
                icon: const Icon(Icons.send, color: Colors.white),
                tooltip: 'Invia messaggio',
              ),
            ),
        ],
      ),
    );
  }
}