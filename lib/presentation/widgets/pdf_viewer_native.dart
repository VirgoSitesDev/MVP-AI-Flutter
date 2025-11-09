import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:html' as html;
// ignore: avoid_web_libraries_in_flutter
import 'dart:ui_web' as ui_web;
import '../../../core/theme/colors.dart';

// Native browser PDF viewer using iframe - RELIABLE!
class PdfViewerNative extends StatefulWidget {
  final Uint8List pdfBytes;
  final String title;

  const PdfViewerNative({
    super.key,
    required this.pdfBytes,
    required this.title,
  });

  @override
  State<PdfViewerNative> createState() => _PdfViewerNativeState();
}

class _PdfViewerNativeState extends State<PdfViewerNative> {
  String? _pdfUrl;
  late String _viewType;

  @override
  void initState() {
    super.initState();
    _viewType = 'pdf-viewer-${widget.pdfBytes.hashCode}-${DateTime.now().millisecondsSinceEpoch}';
    _createPdfBlob();
  }

  void _createPdfBlob() {
    if (kIsWeb) {
      try {
        // Create blob URL for the browser's native PDF viewer
        final html.Blob blob = html.Blob([widget.pdfBytes], 'application/pdf');
        final String url = html.Url.createObjectUrlFromBlob(blob);

        debugPrint('✅ Created PDF blob URL: $url for ${widget.title}');

        // Register the iframe view factory
        ui_web.platformViewRegistry.registerViewFactory(
          _viewType,
          (int viewId) {
            final iframe = html.IFrameElement()
              ..src = url
              ..style.border = 'none'
              ..style.width = '100%'
              ..style.height = '100%';

            return iframe;
          },
        );

        if (mounted) {
          setState(() {
            _pdfUrl = url;
          });
        }
      } catch (e) {
        debugPrint('❌ Error creating PDF blob: $e');
      }
    }
  }

  @override
  void dispose() {
    // Clean up the blob URL
    if (_pdfUrl != null && kIsWeb) {
      try {
        html.Url.revokeObjectUrl(_pdfUrl!);
      } catch (e) {
        debugPrint('Error revoking blob URL: $e');
      }
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(16),
          color: AppColors.surface,
          child: Row(
            children: [
              const Icon(
                Icons.picture_as_pdf,
                size: 20,
                color: Colors.red,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),

        // PDF viewer using browser's native viewer
        Expanded(
          child: _pdfUrl != null
              ? HtmlElementView(
                  viewType: _viewType,
                )
              : const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text(
                        'Caricamento PDF...',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}
