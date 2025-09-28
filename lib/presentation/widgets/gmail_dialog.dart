import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/colors.dart';
import '../../domain/entities/gmail_message.dart';
import '../providers/gmail_provider.dart';

class GmailDialog extends ConsumerStatefulWidget {
  const GmailDialog({super.key});

  @override
  ConsumerState<GmailDialog> createState() => _GmailDialogState();
}

class _GmailDialogState extends ConsumerState<GmailDialog> {

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.mail_outline, color: AppColors.primary, size: 24),
                const SizedBox(width: 12),
                const Text(
                  'Gmail Integration',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: AppColors.iconSecondary),
                ),
              ],
            ),
            const SizedBox(height: 20),

            Expanded(
              child: _buildEmailList(),
            ),

          ],
        ),
      ),
    );
  }

  Widget _buildEmailList() {
    // Show recent emails from inbox
    return _buildMessagesList(const GmailQuery(type: GmailQueryType.inbox, maxResults: 50));
  }

  Widget _buildMessagesList(GmailQuery query) {
    final messagesAsync = ref.watch(gmailMessagesProvider(query));

    return messagesAsync.when(
      data: (messages) {
        if (messages.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.mail_outline, size: 64, color: AppColors.iconSecondary),
                const SizedBox(height: 16),
                const Text(
                  'Nessun messaggio trovato',
                  style: TextStyle(
                    fontSize: 16,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => _requestGmailPermissions(),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Verifica permessi Gmail'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: messages.length,
          itemBuilder: (context, index) {
            final message = messages[index];
            return _buildMessageTile(message);
          },
        );
      },
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
      error: (error, stack) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: AppColors.error),
            const SizedBox(height: 16),
            Text(
              'Errore nel caricamento Gmail: $error',
              style: const TextStyle(color: AppColors.error),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Potrebbe essere necessario autorizzare l\'accesso a Gmail',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _requestGmailPermissions(),
                  icon: const Icon(Icons.security),
                  label: const Text('Autorizza Gmail'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () => ref.invalidate(gmailMessagesProvider(query)),
                  child: const Text('Riprova'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageTile(GmailMessage message) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: Colors.white,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: message.isUnread ? AppColors.primary : AppColors.secondary,
          child: Icon(
            message.isUnread ? Icons.mail : Icons.mail_outline,
            color: Colors.white,
            size: 20,
          ),
        ),
        title: Text(
          message.subject.isNotEmpty ? message.subject : '(Nessun oggetto)',
          style: TextStyle(
            fontWeight: message.isUnread ? FontWeight.w600 : FontWeight.w400,
            color: AppColors.textPrimary,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Da: ${_extractEmailName(message.from)}',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              message.snippet,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textTertiary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              _formatDate(message.date),
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textTertiary,
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (message.isImportant)
                  const Icon(Icons.label_important, size: 16, color: AppColors.warning),
                if (message.isStarred)
                  const Icon(Icons.star, size: 16, color: AppColors.warning),
              ],
            ),
          ],
        ),
        onTap: () => _useEmailInChat(message),
      ),
    );
  }

  String _extractEmailName(String email) {
    final match = RegExp(r'^(.+?)\s*<(.+)>$').firstMatch(email);
    if (match != null) {
      return match.group(1)?.trim() ?? email;
    }
    return email.split('@').first;
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return 'Ieri';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}g fa';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  void _useEmailInChat(GmailMessage message) {
    // Return the Gmail message object so it can be added to smart preview
    Navigator.of(context).pop(message);
  }


  Future<void> _requestGmailPermissions() async {
    try {
      final gmailService = ref.read(gmailServiceProvider);

      await gmailService.initialize();

      ref.invalidate(gmailMessagesProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gmail autorizzato! Ricaricamento messaggi...'),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore autorizzazione Gmail: $e'),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }
}

