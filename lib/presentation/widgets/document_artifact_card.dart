import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:typed_data';
import '../../domain/entities/document_artifact.dart';
import '../../core/theme/colors.dart';
import '../../utils/excel_generator.dart';

// Conditional import for web downloads
import 'stub_download.dart' if (dart.library.html) 'dart:html' as html;

class DocumentArtifactCard extends StatelessWidget {
  final DocumentArtifact artifact;
  final VoidCallback? onTap;

  const DocumentArtifactCard({
    super.key,
    required this.artifact,
    this.onTap,
  });

  IconData get _fileIcon {
    // Check language first for more specific icons
    final lang = artifact.language?.toLowerCase() ?? '';

    if (lang == 'text' || lang == 'txt') {
      return Icons.description;
    } else if (lang == 'markdown' || lang == 'md') {
      return Icons.article;
    } else if (lang == 'html') {
      return Icons.web;
    } else if (lang == 'json') {
      return Icons.data_object;
    } else if (lang == 'csv' || lang == 'excel') {
      return Icons.table_chart;
    } else if (lang == 'python' || lang == 'javascript' || lang == 'java' ||
               lang == 'dart' || lang == 'typescript') {
      return Icons.code;
    }

    // Fallback to type
    switch (artifact.type) {
      case 'code':
        return Icons.code;
      case 'markdown':
        return Icons.article;
      case 'html':
        return Icons.web;
      case 'json':
        return Icons.data_object;
      case 'text':
      default:
        return Icons.description;
    }
  }

  Color get _fileColor {
    // Check language first for more specific colors
    final lang = artifact.language?.toLowerCase() ?? '';

    if (lang == 'text' || lang == 'txt') {
      return const Color(0xFF607D8B); // Blue grey
    } else if (lang == 'markdown' || lang == 'md') {
      return const Color(0xFF2196F3); // Blue
    } else if (lang == 'html') {
      return const Color(0xFFFF9800); // Orange
    } else if (lang == 'json') {
      return const Color(0xFF9C27B0); // Purple
    } else if (lang == 'csv' || lang == 'excel') {
      return const Color(0xFF4CAF50); // Green
    } else if (lang == 'python') {
      return const Color(0xFF4CAF50); // Green
    } else if (lang == 'javascript' || lang == 'typescript') {
      return const Color(0xFFFFC107); // Yellow/amber
    } else if (lang == 'java' || lang == 'dart') {
      return const Color(0xFF00BCD4); // Cyan
    }

    // Fallback to type
    switch (artifact.type) {
      case 'code':
        return const Color(0xFF4CAF50);
      case 'markdown':
        return const Color(0xFF2196F3);
      case 'html':
        return const Color(0xFFFF9800);
      case 'json':
        return const Color(0xFF9C27B0);
      case 'text':
      default:
        return AppColors.iconSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _fileColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  _fileIcon,
                  size: 24,
                  color: _fileColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      artifact.title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${artifact.fileName} • ${_formatFileSize(artifact.content.length)}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildActionButton(
                    icon: Icons.remove_red_eye_outlined,
                    tooltip: 'Visualizza',
                    onPressed: onTap,
                  ),
                  const SizedBox(width: 4),
                  _buildActionButton(
                    icon: Icons.file_download_outlined,
                    tooltip: 'Scarica',
                    onPressed: () => _downloadFile(context),
                  ),
                  const SizedBox(width: 4),
                  _buildActionButton(
                    icon: Icons.content_copy,
                    tooltip: 'Copia',
                    onPressed: () => _copyToClipboard(context),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.all(6),
          child: Icon(
            icon,
            size: 16,
            color: AppColors.iconSecondary,
          ),
        ),
      ),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _copyToClipboard(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: artifact.content));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Contenuto copiato negli appunti'),
          backgroundColor: AppColors.success,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _downloadFile(BuildContext context) async {
    try {
      if (kIsWeb) {
        // Web download using blob
        _downloadForWeb();
      } else {
        // Mobile/Desktop download - not implemented for this platform
        throw UnimplementedError('Download non disponibile per questa piattaforma');
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('File scaricato: ${artifact.fileName}'),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore nel download: $e'),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _downloadForWeb() {
    if (kIsWeb) {
      Uint8List bytes;
      String mimeType = 'text/plain';

      // For table artifacts (CSV/Excel), generate Excel file
      if (artifact.isTable && artifact.headers != null && artifact.tableData != null) {
        debugPrint('📊 Generating Excel file for table artifact: ${artifact.title}');

        final excelBytes = ExcelGenerator.generateExcel(
          headers: artifact.headers!,
          data: artifact.tableData!,
          sheetName: artifact.title.replaceAll(RegExp(r'[^\w\s-]'), ''),
        );

        if (excelBytes != null) {
          bytes = excelBytes;
          mimeType = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
        } else {
          // Fallback to CSV if Excel generation fails
          debugPrint('⚠️ Excel generation failed, falling back to CSV');
          bytes = utf8.encode(artifact.content);
          mimeType = 'text/csv';
        }
      } else {
        // For non-table artifacts, download as text
        bytes = utf8.encode(artifact.content);

        // Set appropriate MIME type based on file extension
        if (artifact.fileName.endsWith('.json')) {
          mimeType = 'application/json';
        } else if (artifact.fileName.endsWith('.html')) {
          mimeType = 'text/html';
        } else if (artifact.fileName.endsWith('.csv')) {
          mimeType = 'text/csv';
        }
      }

      // Create blob and trigger download
      final blob = html.Blob([bytes], mimeType);
      final url = html.Url.createObjectUrlFromBlob(blob);

      final anchor = html.document.createElement('a') as html.AnchorElement
        ..href = url
        ..style.display = 'none'
        ..download = artifact.fileName;

      html.document.body?.children.add(anchor);
      anchor.click();
      html.document.body?.children.remove(anchor);
      html.Url.revokeObjectUrl(url);
    }
  }
}
