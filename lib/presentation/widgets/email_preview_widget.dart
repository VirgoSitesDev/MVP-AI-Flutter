import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import '../../domain/entities/gmail_message.dart';
import '../../core/theme/colors.dart';

class EmailPreviewWidget extends StatelessWidget {
  final GmailMessage email;

  const EmailPreviewWidget({
    super.key,
    required this.email,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          Expanded(
            child: _buildContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.previewBackground,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
        border: Border(
          bottom: BorderSide(color: AppColors.outline),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                email.isUnread ? Icons.mail : Icons.mail_outline,
                color: email.isUnread ? AppColors.primary : AppColors.iconSecondary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  email.subject.isNotEmpty ? email.subject : '(Nessun oggetto)',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (email.isImportant)
                const Icon(Icons.label_important, size: 16, color: AppColors.warning),
              if (email.isStarred)
                const Icon(Icons.star, size: 16, color: AppColors.warning),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Da: ${_extractEmailName(email.from)}',
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                _formatDate(email.date),
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
          if (email.to.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'A: ${email.to}',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textTertiary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildContent() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: email.hasHtmlContent
          ? _buildHtmlContent()
          : _buildTextContent(),
      ),
    );
  }

  Widget _buildHtmlContent() {
    return Html(
      data: email.bodyHtml,
      style: {
        "body": Style(
          margin: Margins.zero,
          padding: HtmlPaddings.zero,
          fontSize: FontSize(14),
          color: AppColors.textPrimary,
          lineHeight: const LineHeight(1.5),
        ),
        "p": Style(
          margin: Margins.only(bottom: 8),
        ),
        "a": Style(
          color: AppColors.primary,
          textDecoration: TextDecoration.underline,
        ),
        "img": Style(
          width: Width(double.infinity),
        ),
      },
      onLinkTap: (url, attributes, element) {
        print('Link clicked: $url');
      },
    );
  }

  Widget _buildTextContent() {
    final content = email.bodyText.isNotEmpty ? email.bodyText : email.snippet;

    return SelectableText(
      content,
      style: const TextStyle(
        fontSize: 14,
        color: AppColors.textPrimary,
        height: 1.5,
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
}