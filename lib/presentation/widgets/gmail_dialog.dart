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

class _GmailDialogState extends ConsumerState<GmailDialog> with TickerProviderStateMixin {
  late TabController _tabController;
  GmailMessage? _selectedMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

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

            TabBar(
              controller: _tabController,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textSecondary,
              indicatorColor: AppColors.primary,
              tabs: const [
                Tab(text: 'Inbox'),
                Tab(text: 'Non lette'),
                Tab(text: 'Importanti'),
                Tab(text: 'Recenti'),
              ],
            ),

            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildInboxTab(),
                  _buildUnreadTab(),
                  _buildImportantTab(),
                  _buildRecentTab(),
                ],
              ),
            ),

            if (_selectedMessage != null) ...[
              const Divider(),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _useEmailInChat(_selectedMessage!),
                      icon: const Icon(Icons.chat),
                      label: const Text('Usa nell\'AI Chat'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () => _showEmailPreview(_selectedMessage!),
                    icon: const Icon(Icons.preview),
                    label: const Text('Anteprima'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.secondary,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInboxTab() {
    return _buildMessagesList(const GmailQuery(type: GmailQueryType.inbox));
  }

  Widget _buildUnreadTab() {
    return _buildMessagesList(const GmailQuery(type: GmailQueryType.unread));
  }

  Widget _buildImportantTab() {
    return _buildMessagesList(const GmailQuery(type: GmailQueryType.important));
  }

  Widget _buildRecentTab() {
    return _buildMessagesList(const GmailQuery(type: GmailQueryType.recent, days: 7));
  }

  Widget _buildMessagesList(GmailQuery query) {
    final messagesAsync = ref.watch(gmailMessagesProvider(query));

    return messagesAsync.when(
      data: (messages) {
        if (messages.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.mail_outline, size: 64, color: AppColors.iconSecondary),
                SizedBox(height: 16),
                Text(
                  'Nessun messaggio trovato',
                  style: TextStyle(
                    fontSize: 16,
                    color: AppColors.textSecondary,
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
              'Errore nel caricamento: $error',
              style: const TextStyle(color: AppColors.error),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => ref.invalidate(gmailMessagesProvider(query)),
              child: const Text('Riprova'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageTile(GmailMessage message) {
    final isSelected = _selectedMessage?.id == message.id;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: isSelected ? AppColors.primary.withOpacity(0.1) : null,
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
        onTap: () {
          setState(() {
            _selectedMessage = isSelected ? null : message;
          });
        },
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
    final gmailService = ref.read(gmailServiceProvider);
    final content = gmailService.formatEmailContent(message);

    Navigator.of(context).pop(content);
  }

  void _showEmailPreview(GmailMessage message) {
    showDialog(
      context: context,
      builder: (context) => EmailPreviewDialog(message: message),
    );
  }
}

class EmailPreviewDialog extends StatelessWidget {
  final GmailMessage message;

  const EmailPreviewDialog({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.7,
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.mail, color: AppColors.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    message.subject.isNotEmpty ? message.subject : '(Nessun oggetto)',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: AppColors.iconSecondary),
                ),
              ],
            ),
            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.backgroundSecondary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoRow('Da:', message.from),
                  _buildInfoRow('A:', message.to),
                  _buildInfoRow('Data:', message.date.toString()),
                ],
              ),
            ),

            const SizedBox(height: 16),
            const Text(
              'Contenuto:',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),

            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.outline),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    message.bodyText.isNotEmpty ? message.bodyText : message.snippet,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textPrimary,
                      height: 1.5,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 60,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}