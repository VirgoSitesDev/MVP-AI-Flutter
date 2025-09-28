import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../core/theme/colors.dart';
import '../../domain/entities/gmail_message.dart';
import '../../data/datasources/remote/supabase_service.dart';
import '../../domain/entities/chat_session.dart';
import '../../domain/entities/message.dart';
import '../providers/chat_provider.dart';
import '../providers/gmail_provider.dart';
import '../../data/datasources/remote/google_drive_service.dart';
import '../../data/datasources/remote/google_drive_content_extractor.dart';
import '../providers/google_drive_provider.dart';
import '../widgets/google_drive_dialog.dart';
import '../widgets/gmail_dialog.dart';

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _messageFocusNode = FocusNode();
  bool _isPersonalPinsExpanded = true;
  bool _isOrgPinsExpanded = true;
  bool _isUtilitiesExpanded = false;
  bool _isPreviewFullscreen = false;

  DriveFile? _selectedFileForPreview;
  String? _previewContent;
  StructuredContent? _structuredPreviewContent;
  bool _isLoadingPreview = false;
  final GoogleDriveContentExtractor _contentExtractor = GoogleDriveContentExtractor();

  List<String> selectedEmails = [];
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });

    _messageController.addListener(() {
      setState(() {});
    });
  }
  
  @override
  void dispose() {
    _messageController.dispose();
    _messageFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }
  
  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }
  
  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isNotEmpty) {
      final messageState = ref.read(messageStateProvider);
      if (messageState is! AppMessageStateSending) {
        ref.read(currentChatSessionProvider.notifier).sendMessage(text);
        _messageController.clear();
        _messageFocusNode.requestFocus();
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final chatSession = ref.watch(currentChatSessionProvider);
    final messageState = ref.watch(messageStateProvider);

    ref.listen(currentChatSessionProvider, (previous, next) {
      if (next != null && previous != null) {
        if (next.messages.length > previous.messages.length) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _scrollToBottom();
          });
        }
      }
    });
    
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _buildCustomHeader(),

          Expanded(
            child: _isPreviewFullscreen
                ? Row(
                    children: [
                      Expanded(
                        flex: 7,
                        child: Column(
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  _buildLeftSidebar(),
                                  Expanded(
                                    child: _buildChatArea(chatSession, messageState),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 5,
                        child: _buildSmartPreviewWindow(),
                      ),
                    ],
                  )
                : Row(
                    children: [
                      _buildLeftSidebar(),

                      Expanded(
                        child: Column(
                          children: [
                            _buildSmartPreviewWindow(),

                            Expanded(
                              child: _buildChatArea(chatSession, messageState),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildCustomHeader() {
    return Container(
      height: 48,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: AppColors.divider, width: 1),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 320,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Image.asset(
                  'assets/images/logo_virgo.png',
                  width: 28,
                  height: 28,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Text(
                          'V',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    );
                  },
                ),

                const Spacer(),

                const Text(
                  'v.0.0.1',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textTertiary,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(width: 8),

                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color.fromARGB(255, 255, 229, 232),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'beta',
                    style: TextStyle(
                      color: Color.fromARGB(255, 223, 4, 95),
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Expanded(
            child: SizedBox(),
          ),

          Container(
            width: 320,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Consumer(
                  builder: (context, ref, _) {
                    final googleAuthState = ref.watch(googleAuthStateProvider);
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: switch (googleAuthState) {
                          GoogleAuthAuthenticated() => AppColors.success.withOpacity(0.1),
                          GoogleAuthLoading() => AppColors.warning.withOpacity(0.1),
                          GoogleAuthError() => AppColors.error.withOpacity(0.1),
                          _ => AppColors.textTertiary.withOpacity(0.1),
                        },
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: switch (googleAuthState) {
                            GoogleAuthAuthenticated() => AppColors.success,
                            GoogleAuthLoading() => AppColors.warning,
                            GoogleAuthError() => AppColors.error,
                            _ => AppColors.textTertiary,
                          },
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.drive_file_rename_outline,
                            size: 12,
                            color: switch (googleAuthState) {
                              GoogleAuthAuthenticated() => AppColors.success,
                              GoogleAuthLoading() => AppColors.warning,
                              GoogleAuthError() => AppColors.error,
                              _ => AppColors.textTertiary,
                            },
                          ),
                          const SizedBox(width: 4),
                          Text(
                            switch (googleAuthState) {
                              GoogleAuthAuthenticated() => 'Drive OK',
                              GoogleAuthLoading() => 'Drive...',
                              GoogleAuthError() => 'Drive KO',
                              _ => 'Drive OFF',
                            },
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: switch (googleAuthState) {
                                GoogleAuthAuthenticated() => AppColors.success,
                                GoogleAuthLoading() => AppColors.warning,
                                GoogleAuthError() => AppColors.error,
                                _ => AppColors.textTertiary,
                              },
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),

                const SizedBox(width: 12),

                PopupMenuButton(
                  icon: const Icon(Icons.more_vert, size: 20, color: AppColors.iconPrimary),
                  itemBuilder: (context) => [
                    if (kDebugMode)
                      PopupMenuItem(
                        onTap: () {
                          ref.read(googleAuthStateProvider.notifier).refresh();
                        },
                        child: const Row(
                          children: [
                            Icon(Icons.refresh, size: 16),
                            SizedBox(width: 8),
                            Text('Refresh Google Status'),
                          ],
                        ),
                      ),
                    if (kDebugMode)
                      PopupMenuItem(
                        onTap: () async {
                          final service = ref.read(googleAuthServiceProvider);
                          await service.resetAuthentication();
                          ref.read(googleAuthStateProvider.notifier).refresh();
                        },
                        child: const Row(
                          children: [
                            Icon(Icons.clear_all, size: 16),
                            SizedBox(width: 8),
                            Text('Reset Google Auth'),
                          ],
                        ),
                      ),
                    PopupMenuItem(
                      onTap: () {
                        ref.read(authStateProvider.notifier).signOut();
                      },
                      child: const Row(
                        children: [
                          Icon(Icons.logout, size: 16),
                          SizedBox(width: 8),
                          Text('Logout App'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildLeftSidebar() {
      final chatSessionsAsync = ref.watch(chatSessionsProvider);
      final currentSession = ref.watch(currentChatSessionProvider);
      
      return Container(
        width: 320,
        decoration: const BoxDecoration(
          color: AppColors.sidebarBackground,
          border: Border(
            right: BorderSide(color: AppColors.sidebarBorder, width: 1),
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Riferimenti della Sessione',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: AppColors.textTertiary,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1, color: AppColors.divider),
                  const SizedBox(height: 12),

                  Consumer(
                    builder: (context, ref, _) {
                      final selectedFiles = ref.watch(selectedDriveFilesProvider);
                      final selectedEmails = ref.watch(selectedGmailMessagesProvider);

                      if (selectedFiles.isEmpty && selectedEmails.isEmpty && currentSession == null) {
                        return const Text(
                          'Nessun riferimento attivo',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textTertiary,
                            fontStyle: FontStyle.italic,
                          ),
                        );
                      }

                      return Column(
                        children: [
                          ...selectedFiles.map((file) => _buildDriveFileReference(file)),
                          ...selectedEmails.map((email) => _buildGmailMessageReference(email)),

                          if (currentSession != null)
                            _buildReferenceItem(
                              title: currentSession.title,
                              badge: 'ATTIVA',
                              badgeColor: AppColors.success,
                            ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Riferimenti Permanenti',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: AppColors.textTertiary,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Divider(height: 1, color: AppColors.divider),
                      const SizedBox(height: 8),

                      _buildGoogleConnectionSection(),

                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFAFBFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppColors.outline,
                            width: 1,
                          ),
                        ),
                        child: _buildExpandableSection(
                          icon: Icons.person_outline,
                          title: 'Le tue conversazioni',
                          isExpanded: _isPersonalPinsExpanded,
                          onToggle: () => setState(() => _isPersonalPinsExpanded = !_isPersonalPinsExpanded),
                          children: chatSessionsAsync.when(
                            data: (sessions) {
                              if (sessions.isEmpty) {
                                return [
                                  const Padding(
                                    padding: EdgeInsets.all(8.0),
                                    child: Text(
                                      'Nessuna conversazione salvata',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textTertiary,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ),
                                ];
                              }
                              return sessions.map((session) => _buildChatItem(
                                session: session,
                                isActive: currentSession?.id == session.id,
                              )).toList();
                            },
                            loading: () => [
                              const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(8.0),
                                  child: SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                ),
                              ),
                            ],
                            error: (error, _) => [
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Text(
                                  'Errore nel caricamento',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.error,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFAFBFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppColors.outline,
                            width: 1,
                          ),
                        ),
                        child: _buildExpandableSection(
                          icon: Icons.business_outlined,
                          title: 'Pin della tua organizzazione',
                          isExpanded: _isOrgPinsExpanded,
                          onToggle: () => setState(() => _isOrgPinsExpanded = !_isOrgPinsExpanded),
                          children: [],
                        ),
                      ),

                      const SizedBox(height: 24),

                      _buildExpandableSection(
                        icon: Icons.lightbulb_outline,
                        title: 'Scopri le funzionalità',
                        isExpanded: _isUtilitiesExpanded,
                        onToggle: () => setState(() => _isUtilitiesExpanded = !_isUtilitiesExpanded),
                        children: [
                          _buildUtilityItem(Icons.add_comment, 'Nuova conversazione'),
                          _buildUtilityItem(Icons.article_outlined, 'Riassunto sessione'),
                          _buildUtilityItem(Icons.close, 'Termina sessione', isRed: true),
                        ],
                      ),

                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    Widget _buildSmartPreviewWindow() {
      final selectedFiles = ref.watch(selectedDriveFilesProvider);
      final selectedEmails = ref.watch(selectedGmailMessagesProvider);

      return AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        height: _isPreviewFullscreen ? double.infinity : 250,
        decoration: BoxDecoration(
          color: AppColors.previewBackground,
          border: _isPreviewFullscreen
              ? const Border(
                  left: BorderSide(color: AppColors.previewBorder, width: 1),
                )
              : const Border(
                  bottom: BorderSide(color: AppColors.previewBorder, width: 1),
                ),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  bottom: BorderSide(color: AppColors.divider, width: 1),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.preview_outlined,
                    size: 18,
                    color: AppColors.iconPrimary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    selectedEmails.isNotEmpty
                        ? 'Smart Preview - Documenti e Email Condivisi'
                        : 'Smart Preview - Documenti Condivisi',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  if (selectedFiles.isNotEmpty || selectedEmails.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${selectedFiles.length + selectedEmails.length} elementi',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Tooltip(
                    message: _isPreviewFullscreen
                        ? 'Esci dalla modalità schermo intero'
                        : 'Modalità schermo intero',
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _isPreviewFullscreen = !_isPreviewFullscreen;
                          });
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.all(8.0),
                          decoration: BoxDecoration(
                            color: _isPreviewFullscreen
                                ? AppColors.primary.withOpacity(0.1)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _isPreviewFullscreen
                                  ? AppColors.primary.withOpacity(0.3)
                                  : Colors.transparent,
                            ),
                          ),
                          child: Icon(
                            _isPreviewFullscreen
                                ? Icons.close_fullscreen
                                : Icons.open_in_full,
                            size: 20,
                            color: _isPreviewFullscreen
                                ? AppColors.primary
                                : AppColors.iconPrimary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: (selectedFiles.isNotEmpty || selectedEmails.isNotEmpty)
                  ? _buildPreviewArea(selectedFiles, selectedEmails)
                  : const Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.preview_outlined,
                            size: 32,
                            color: AppColors.iconSecondary,
                          ),
                          SizedBox(width: 12),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Nessun documento o email condiviso',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Aggiungi file da Drive o email da Gmail',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textTertiary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      );
    }

    Widget _buildPreviewArea(List<DriveFile> selectedFiles, List<GmailMessage> selectedEmails) {
      if (selectedFiles.isNotEmpty) {
        if (_selectedFileForPreview != null &&
            !selectedFiles.any((file) => file.id == _selectedFileForPreview!.id)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _selectedFileForPreview = null;
                _previewContent = null;
                _structuredPreviewContent = null;
                _isLoadingPreview = false;
              });
            }
          });
        }

        final fileToPreview = _selectedFileForPreview ?? selectedFiles.first;

        if (_selectedFileForPreview == null || _selectedFileForPreview!.id != fileToPreview.id) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && (_selectedFileForPreview == null || _selectedFileForPreview!.id != fileToPreview.id)) {
              _loadFileContent(fileToPreview);
            }
          });
        }

        return Column(
          children: [
            _buildCompactFileSelector(selectedFiles, fileToPreview),
            const Divider(height: 1, color: AppColors.divider),
            Expanded(
              child: _buildFilePreviewSimple(fileToPreview),
            ),
          ],
        );
      } else if (selectedEmails.isNotEmpty) {
        final emailToPreview = selectedEmails.first;
        return Column(
          children: [
            _buildCompactEmailSelector(selectedEmails),
            const Divider(height: 1, color: AppColors.divider),
            Expanded(
              child: _buildEmailPreview(emailToPreview),
            ),
          ],
        );
      }

      return const SizedBox();
    }

    Widget _buildFilePreviewSimple(DriveFile file) {

      return Container(
        color: Colors.white,
        child: _isLoadingPreview
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text(
                      'Caricamento anteprima...',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              )
            : _structuredPreviewContent != null
                ? _buildStructuredContent(_structuredPreviewContent!)
                : _previewContent != null && _previewContent!.isNotEmpty
                    ? SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: SelectableText(
                          _previewContent!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textPrimary,
                            fontFamily: 'monospace',
                            height: 1.5,
                          ),
                        ),
                      )
                    : _buildPreviewContent(file),
      );
    }

    Widget _buildCompactFileSelector(List<DriveFile> files, DriveFile currentFile) {
      return Container(
        height: 60,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        color: AppColors.surface,
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Center(
                child: Text(
                  currentFile.fileTypeIcon,
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    currentFile.name,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    currentFile.fileTypeDescription,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (files.length > 1) ...[
              Container(
                height: 32,
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.outline),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: DropdownButton<DriveFile>(
                  value: currentFile,
                  items: files.map((file) => DropdownMenuItem(
                    value: file,
                    child: SizedBox(
                      width: 200,
                      child: Row(
                        children: [
                          Text(
                            file.fileTypeIcon,
                            style: const TextStyle(fontSize: 14),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              file.name,
                              style: const TextStyle(fontSize: 12),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )).toList(),
                  onChanged: (DriveFile? newFile) {
                    if (newFile != null) {
                      setState(() {
                        _selectedFileForPreview = newFile;
                      });
                      _loadFileContent(newFile);
                    }
                  },
                  underline: const SizedBox(),
                  icon: const Icon(Icons.expand_more, size: 18),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textPrimary,
                  ),
                  dropdownColor: Colors.white,
                ),
              ),
            ],
          ],
        ),
      );
    }



    Future<void> _loadFileContent(DriveFile file) async {
      _selectedFileForPreview = file;

      if (mounted) {
        setState(() {
          _isLoadingPreview = true;
          _previewContent = null;
          _structuredPreviewContent = null;
        });
      }

      try {
        final structuredContent = await _contentExtractor.extractStructuredContent(file);

        if (mounted) {
          setState(() {
            _structuredPreviewContent = structuredContent;
            _isLoadingPreview = false;
          });
        }
      } catch (e, stackTrace) {
        if (mounted) {
          setState(() {
            _previewContent = 'Errore nel caricamento del contenuto:\n\n${e.toString()}\n\nDettagli:\n- File: ${file.name}\n- ID: ${file.id}\n- Tipo: ${file.mimeType}';
            _structuredPreviewContent = null;
            _isLoadingPreview = false;
          });
        }
      }
    }

    Widget _buildStructuredContent(StructuredContent content) {
      if (content.isTable && content.tableData != null && content.headers != null) {
        return _buildTableView(content);
      } else {
        return _buildTextView(content);
      }
    }

    Widget _buildTableView(StructuredContent content) {
      final headers = content.headers!;
      final tableData = content.tableData!;

      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              content.title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Tabella con ${tableData.length} righe e ${headers.length} colonne',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),

            Container(
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.outline),
                borderRadius: BorderRadius.circular(8),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: MaterialStateProperty.all(AppColors.surface),
                  border: TableBorder.all(
                    color: AppColors.outline,
                    width: 0.5,
                  ),
                  columnSpacing: 16,
                  headingTextStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                  dataTextStyle: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textPrimary,
                  ),
                  columns: headers.map((header) => DataColumn(
                    label: Expanded(
                      child: Text(
                        header.isNotEmpty ? header : 'Colonna',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )).toList(),
                  rows: tableData.take(100).map((row) {
                    final adjustedRow = List<String>.filled(headers.length, '');
                    for (int i = 0; i < row.length && i < headers.length; i++) {
                      adjustedRow[i] = row[i];
                    }

                    return DataRow(
                      cells: adjustedRow.map((cell) => DataCell(
                        Container(
                          constraints: const BoxConstraints(maxWidth: 200),
                          child: Text(
                            cell.isNotEmpty ? cell : '-',
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )).toList(),
                    );
                  }).toList(),
                ),
              ),
            ),

            if (tableData.length > 100) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.warning.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.warning.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 16,
                      color: AppColors.warning,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Visualizzate le prime 100 righe di ${tableData.length} totali per prestazioni ottimali',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.warning,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      );
    }

    Widget _buildTextView(StructuredContent content) {
      final text = content.text ?? 'Contenuto non disponibile';

      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              content.title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),

            SelectableText(
              text,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textPrimary,
                fontFamily: 'monospace',
                height: 1.5,
              ),
            ),
          ],
        ),
      );
    }

    Widget _buildPreviewContent(DriveFile file) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Text(file.fileTypeIcon, style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          file.name,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          file.fileTypeDescription,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Clicca per caricare l\'anteprima del contenuto',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      );
    }


    String _formatDateTime(DateTime date) {
      return '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    }

  Widget _buildChatArea(chatSession, messageState) {
    return Column(
      children: [
        Expanded(
          child: Container(
            color: Colors.white,
            child: chatSession != null && chatSession.messages.isNotEmpty
                ? ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(24),
                    itemCount: chatSession.messages.length,
                    itemBuilder: (context, index) {
                      final message = chatSession.messages[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _buildSimpleMessage(message),
                      );
                    },
                  )
                : Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset(
                          'assets/images/logo_virgo_extended.png',
                          width: 200,
                          height: 80,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return const Text(
                              'VIRGO',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Inizia una conversazione',
                          style: TextStyle(
                            fontSize: 16,
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ),

        Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(
              top: BorderSide(color: AppColors.outline, width: 1),
            ),
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: AppColors.inputBackground,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.inputBorder),
            ),
            child: Row(
              children: [
                Expanded(
                  child: KeyboardListener(
                    focusNode: FocusNode(),
                    onKeyEvent: (KeyEvent event) {
                      if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.enter) {
                        if (_messageController.text.trim().isNotEmpty) {
                          _sendMessage();
                        }
                      }
                    },
                    child: TextField(
                      controller: _messageController,
                      focusNode: _messageFocusNode,
                      enabled: messageState is! AppMessageStateSending,
                      maxLines: 1,
                      textInputAction: TextInputAction.send,
                      decoration: const InputDecoration(
                        hintText: 'Chiedimi qualsiasi cosa',
                        border: InputBorder.none,
                        hintStyle: TextStyle(
                          color: AppColors.textTertiary,
                          fontSize: 14,
                        ),
                      ),
                      style: const TextStyle(
                        color: Color.fromARGB(255, 80, 80, 80),
                        fontSize: 14,
                      ),
                      onSubmitted: (text) {
                        _sendMessage();
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (messageState is AppMessageStateSending)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  IconButton(
                    onPressed: _messageController.text.trim().isNotEmpty ? _sendMessage : null,
                    icon: Icon(
                      Icons.send,
                      color: _messageController.text.trim().isNotEmpty 
                          ? AppColors.primary 
                          : AppColors.iconSecondary,
                      size: 20,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildSimpleMessage(Message message) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: message.isUser 
            ? const Color(0xFFE8E9EB)
            : AppColors.assistantMessageBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (message.isUser)
                Icon(
                  Icons.person,
                  size: 16,
                  color: AppColors.textSecondary,
                )
              else
                Image.asset(
                  'assets/images/logo_virgo.png',
                  width: 16,
                  height: 16,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Text(
                          'V',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              const SizedBox(width: 8),
              Text(
                message.isUser ? 'Tu' : 'Virgo',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (message.status == MessageStatus.sending)
            Row(
              children: [
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Digitando...',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textTertiary,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            )
          else
            Text(
              message.content,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textPrimary,
                height: 1.5,
              ),
            ),
        ],
      ),
    );
  }
  
  Widget _buildReferenceItem({
    required String title,
    required String badge,
    required Color badgeColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: badgeColor,
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(
              badge,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildExpandableSection({
    required IconData icon,
    required String title,
    required bool isExpanded,
    required VoidCallback onToggle,
    required List<Widget> children,
  }) {
    return Column(
      children: [
        InkWell(
          onTap: onToggle,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            child: Row(
              children: [
                Icon(icon, size: 18, color: AppColors.iconPrimary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                Icon(
                  isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  size: 18,
                  color: AppColors.iconSecondary,
                ),
              ],
            ),
          ),
        ),
        if (isExpanded && children.isNotEmpty) 
          Padding(
            padding: const EdgeInsets.only(left: 26, right: 12, bottom: 10),
            child: Column(children: children),
          ),
      ],
    );
  }
  
  Widget _buildChatItem({
    required ChatSession session,
    required bool isActive,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: isActive ? AppColors.hoverLight : Colors.transparent,
        borderRadius: BorderRadius.circular(4),
      ),
      child: InkWell(
        onTap: () {
          ref.read(currentChatSessionProvider.notifier).loadSession(session);
        },
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session.title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isActive ? FontWeight.w500 : FontWeight.w400,
                        color: isActive ? AppColors.primary : AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatSessionDate(session.updatedAt),
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              if (isActive)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.success,
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: const Text(
                    'ATTIVA',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              const SizedBox(width: 4),
              PopupMenuButton<String>(
                icon: const Icon(
                  Icons.more_vert,
                  size: 14,
                  color: AppColors.iconSecondary,
                ),
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline, size: 16, color: AppColors.error),
                        SizedBox(width: 8),
                        Text('Elimina', style: TextStyle(color: AppColors.error)),
                      ],
                    ),
                  ),
                ],
                onSelected: (value) {
                  if (value == 'delete') {
                    _showDeleteConfirmation(session);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  void _showDeleteConfirmation(ChatSession session) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Elimina conversazione'),
        content: Text('Sei sicuro di voler eliminare "${session.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              final currentSession = ref.read(currentChatSessionProvider);
              if (currentSession?.id == session.id) {
                ref.read(currentChatSessionProvider.notifier).deleteCurrentSession();
              } else {
                SupabaseService.deleteChatSession(session.id).then((_) {
                  ref.invalidate(chatSessionsProvider);
                });
              }
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );
  }
  
  String _formatSessionDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inMinutes < 1) {
      return 'Adesso';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes} min fa';
    } else if (difference.inDays < 1) {
      return '${difference.inHours} ore fa';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} giorni fa';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  Widget _buildUtilityItem(IconData icon, String title, {bool isRed = false}) {
    return InkWell(
      onTap: () {
        if (title == 'Nuova conversazione') {
          ref.read(currentChatSessionProvider.notifier).createNewSession();
        } else if (title == 'Riassunto sessione') {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Funzionalità in arrivo!')),
          );
        } else if (title == 'Termina sessione') {
          ref.read(currentChatSessionProvider.notifier).clearSession();
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: isRed ? AppColors.iconError : AppColors.iconSecondary,
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: isRed ? AppColors.iconError : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

Widget _buildGoogleConnectionSection() {
    final googleAuthState = ref.watch(googleAuthStateProvider);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFBFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.outline,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SvgPicture.asset(
                'assets/icons/google_logo.svg',
                width: 16,
                height: 16,
              ),
              const SizedBox(width: 8),
              const Text(
                'Google Workspace',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              _buildGoogleStatusBadge(googleAuthState),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Accesso separato per Drive, Gmail e altri servizi Google',
            style: TextStyle(
              fontSize: 10,
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: 12),

          _buildGoogleConnectionContent(googleAuthState),
        ],
      ),
    );
  }

  Widget _buildGoogleStatusBadge(GoogleAuthState state) {
    switch (state) {
      case GoogleAuthAuthenticated():
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.success,
            borderRadius: BorderRadius.circular(3),
          ),
          child: const Text(
            'CONNESSO',
            style: TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      case GoogleAuthLoading():
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.warning,
            borderRadius: BorderRadius.circular(3),
          ),
          child: const Text(
            'CONNESSIONE...',
            style: TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      case GoogleAuthError():
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.error,
            borderRadius: BorderRadius.circular(3),
          ),
          child: const Text(
            'ERRORE',
            style: TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      default:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.textTertiary,
            borderRadius: BorderRadius.circular(3),
          ),
          child: const Text(
            'NON CONNESSO',
            style: TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
    }
  }

  Widget _buildGoogleConnectionContent(GoogleAuthState state) {
    switch (state) {
      case GoogleAuthAuthenticated(:final email):
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              email,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    onPressed: () {
                      _showGoogleDriveSearch();
                    },
                    icon: const Icon(Icons.folder_open, size: 16),
                    label: const Text(
                      'Drive',
                      style: TextStyle(fontSize: 12),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      minimumSize: const Size(0, 36),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextButton.icon(
                    onPressed: () {
                      _showGmailDialog();
                    },
                    icon: const Icon(Icons.email, size: 16),
                    label: const Text(
                      'Gmail',
                      style: TextStyle(fontSize: 12),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      minimumSize: const Size(0, 36),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: () {
                  ref.read(googleAuthStateProvider.notifier).signOut();
                },
                icon: const Icon(Icons.logout, size: 14),
                label: const Text(
                  'Disconnetti Google Workspace',
                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  minimumSize: const Size(0, 32),
                ),
              ),
            ),
          ],
        );
      case GoogleAuthError(:final message):
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.error,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: () {
                  ref.read(googleAuthStateProvider.notifier).signIn();
                },
                icon: const Icon(Icons.login, size: 16),
                label: const Text(
                  'Connetti Google Workspace',
                  style: TextStyle(fontSize: 12),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  minimumSize: const Size(0, 36),
                ),
              ),
            ),
          ],
        );
      case GoogleAuthLoading():
        return const Center(
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        );
      default:
        return SizedBox(
          width: double.infinity,
          child: TextButton.icon(
            onPressed: () {
              ref.read(googleAuthStateProvider.notifier).signIn();
            },
            icon: const Icon(Icons.login, size: 16),
            label: const Text(
              'Connetti Google Workspace',
              style: TextStyle(fontSize: 12),
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              minimumSize: const Size(0, 36),
            ),
          ),
        );
    }
  }

  void _showGoogleDriveSearch() async {
    try {
      final selectedFiles = await GoogleDriveDialog.show(context);

      if (selectedFiles != null && selectedFiles.isNotEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${selectedFiles.length} file aggiunti ai riferimenti'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Errore apertura Google Drive: $e');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore nell\'accesso a Google Drive: ${e.toString()}'),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Riprova',
              textColor: Colors.white,
              onPressed: () => _showGoogleDriveSearch(),
            ),
          ),
        );
      }
    }
  }

  void _showGmailDialog() async {
    try {
      final selectedMessage = await showDialog<GmailMessage>(
        context: context,
        builder: (context) => const GmailDialog(),
      );

      if (selectedMessage != null) {
        // Add email to smart preview
        ref.read(selectedGmailMessagesProvider.notifier).addMessage(selectedMessage);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Email aggiunta a Smart Preview'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore accesso Gmail: $e'),
            backgroundColor: AppColors.error,
            action: SnackBarAction(
              label: 'Riprova',
              textColor: Colors.white,
              onPressed: () => _showGmailDialog(),
            ),
          ),
        );
      }
    }
  }

  Widget _buildDriveFileReference(DriveFile file) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.outline),
      ),
      child: Row(
        children: [
          Text(
            file.fileTypeIcon,
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  file.name,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  file.fileTypeDescription,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.badgeGoogleDrive,
              borderRadius: BorderRadius.circular(3),
            ),
            child: const Text(
              'G DRIVE',
              style: TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 4),
          InkWell(
            onTap: () {
              ref.read(selectedDriveFilesProvider.notifier).removeFile(file.id);
            },
            child: const Icon(
              Icons.close,
              size: 14,
              color: AppColors.iconSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactEmailSelector(List<GmailMessage> emails) {
    if (emails.isEmpty) {
      return const SizedBox();
    }
    final currentEmail = emails.first;

    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppColors.surface,
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Center(
              child: Icon(
                Icons.email,
                size: 16,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  currentEmail.subject.isNotEmpty ? currentEmail.subject : '(Nessun oggetto)',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Email da ${_extractEmailName(currentEmail.from)}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (emails.length > 1) ...[
            Container(
              height: 32,
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.outline),
                borderRadius: BorderRadius.circular(6),
              ),
              child: DropdownButton<GmailMessage>(
                value: currentEmail,
                items: emails.map((email) => DropdownMenuItem(
                  value: email,
                  child: SizedBox(
                    width: 200,
                    child: Row(
                      children: [
                        const Icon(
                          Icons.email,
                          size: 14,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            email.subject.isNotEmpty ? email.subject : '(Nessun oggetto)',
                            style: const TextStyle(fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                )).toList(),
                onChanged: (GmailMessage? newEmail) {
                  // For now, just keep the first email selected
                  // Could implement email switching in the future
                },
                underline: const SizedBox(),
                icon: const Icon(Icons.expand_more, size: 18),
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textPrimary,
                ),
                dropdownColor: Colors.white,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmailPreview(GmailMessage email) {
    return Container(
      color: Colors.white,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.email, size: 20, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          email.subject.isNotEmpty ? email.subject : '(Nessun oggetto)',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.warning,
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: const Text(
                          'GMAIL',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: () {
                          ref.read(selectedGmailMessagesProvider.notifier).removeMessage(email.id);
                        },
                        child: const Icon(
                          Icons.close,
                          size: 16,
                          color: AppColors.iconSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Da: ${_extractEmailName(email.from)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    'Data: ${_formatEmailDate(email.date)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.outline),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Contenuto:',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    email.bodyText.isNotEmpty ? email.bodyText : email.snippet,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textPrimary,
                      height: 1.5,
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

  String _extractEmailName(String email) {
    final match = RegExp(r'^(.+?)\s*<(.+)>$').firstMatch(email);
    if (match != null) {
      return match.group(1)?.trim() ?? email;
    }
    return email.split('@').first;
  }

  String _formatEmailDate(DateTime date) {
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

  Widget _buildGmailMessageReference(GmailMessage email) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.outline),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.email,
            size: 16,
            color: AppColors.warning,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  email.subject.isNotEmpty ? email.subject : '(Nessun oggetto)',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Da: ${_extractEmailName(email.from)}',
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.warning,
              borderRadius: BorderRadius.circular(3),
            ),
            child: const Text(
              'GMAIL',
              style: TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 4),
          InkWell(
            onTap: () {
              ref.read(selectedGmailMessagesProvider.notifier).removeMessage(email.id);
            },
            child: const Icon(
              Icons.close,
              size: 14,
              color: AppColors.iconSecondary,
            ),
          ),
        ],
      ),
    );
  }
}