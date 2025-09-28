import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/colors.dart';
import '../../../domain/entities/message.dart';

class MessageBubble extends StatelessWidget {
  final Message message;
  final bool showTimestamp;
  final VoidCallback? onRetry;
  
  const MessageBubble({
    super.key,
    required this.message,
    this.showTimestamp = false,
    this.onRetry,
  });
  
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
      child: Column(
        crossAxisAlignment: message.isUser 
            ? CrossAxisAlignment.end 
            : CrossAxisAlignment.start,
        children: [
          if (showTimestamp) _buildTimestamp(context),
          Row(
            mainAxisAlignment: message.isUser 
                ? MainAxisAlignment.end 
                : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!message.isUser) _buildAvatar(),
              if (!message.isUser) const SizedBox(width: 8),
              Flexible(child: _buildBubble(context)),
              if (message.isUser) const SizedBox(width: 8),
              if (message.isUser) _buildAvatar(),
            ],
          ),
          if (message.status == MessageStatus.error && onRetry != null)
            _buildRetryButton(),
        ],
      ),
    );
  }
  
  Widget _buildTimestamp(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        _formatTimestamp(message.timestamp),
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: AppColors.textTertiary,
          fontSize: 11,
        ),
        textAlign: message.isUser ? TextAlign.end : TextAlign.start,
      ),
    );
  }
  
  Widget _buildAvatar() {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: message.isUser ? AppColors.primary : AppColors.success,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Icon(
        message.isUser ? Icons.person : Icons.smart_toy,
        color: Colors.white,
        size: 16,
      ),
    );
  }
  
  Widget _buildBubble(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.7,
      ),
      decoration: BoxDecoration(
        color: _getBubbleColor(),
        borderRadius: _getBubbleBorderRadius(),
        border: message.status == MessageStatus.error
            ? Border.all(color: AppColors.error, width: 1)
            : null,
      ),
      child: InkWell(
        onLongPress: () => _showContextMenu(context),
        borderRadius: _getBubbleBorderRadius(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildMessageContent(context),
              if (message.status == MessageStatus.sending)
                _buildTypingIndicator(),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildMessageContent(BuildContext context) {
    if (message.content.isEmpty && message.status == MessageStatus.sending) {
      return const SizedBox.shrink();
    }
    
    return SelectableText(
      message.content,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: message.isUser ? Colors.white : AppColors.textPrimary,
        height: 1.4,
      ),
    );
  }
  
  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: message.isUser ? Colors.white : AppColors.primary,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Sta digitando...',
            style: TextStyle(
              fontSize: 12,
              color: message.isUser ? Colors.white70 : AppColors.textSecondary,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRetryButton() {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: TextButton.icon(
        onPressed: onRetry,
        icon: const Icon(Icons.refresh, size: 16),
        label: const Text('Riprova'),
        style: TextButton.styleFrom(
          foregroundColor: AppColors.error,
          minimumSize: Size.zero,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        ),
      ),
    );
  }
  
  Color _getBubbleColor() {
    switch (message.status) {
      case MessageStatus.error:
        return AppColors.error.withOpacity(0.1);
      case MessageStatus.system:
        return AppColors.warning.withOpacity(0.1);
      default:
        return message.isUser 
            ? AppColors.primary 
            : AppColors.chatBubbleBg;
    }
  }
  
  BorderRadius _getBubbleBorderRadius() {
    return BorderRadius.only(
      topLeft: const Radius.circular(16),
      topRight: const Radius.circular(16),
      bottomLeft: Radius.circular(message.isUser ? 16 : 4),
      bottomRight: Radius.circular(message.isUser ? 4 : 16),
    );
  }
  
  void _showContextMenu(BuildContext context) {
    HapticFeedback.mediumImpact();
    
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('Copia messaggio'),
              onTap: () {
                Clipboard.setData(ClipboardData(text: message.content));
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Messaggio copiato')),
                );
              },
            ),
            if (message.status == MessageStatus.error && onRetry != null)
              ListTile(
                leading: const Icon(Icons.refresh),
                title: const Text('Riprova'),
                onTap: () {
                  Navigator.pop(context);
                  onRetry?.call();
                },
              ),
          ],
        ),
      ),
    );
  }
  
  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    
    if (difference.inMinutes < 1) {
      return 'Ora';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m fa';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h fa';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
  }
}