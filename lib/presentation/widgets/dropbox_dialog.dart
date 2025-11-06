import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/entities/dropbox_file.dart';
import '../providers/dropbox_provider.dart';

class DropboxDialog extends ConsumerStatefulWidget {
  const DropboxDialog({super.key});

  static Future<List<DropboxFile>?> show(BuildContext context) async {
    return showDialog<List<DropboxFile>>(
      context: context,
      builder: (context) => const DropboxDialog(),
      barrierDismissible: false,
    );
  }

  @override
  ConsumerState<DropboxDialog> createState() => _DropboxDialogState();
}

class _DropboxDialogState extends ConsumerState<DropboxDialog> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final Set<String> _tempSelectedIds = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndInitialize();
    });
  }

  Future<void> _checkAndInitialize() async {
    final dropboxAuthState = ref.read(dropboxAuthStateProvider);

    if (dropboxAuthState is! DropboxAuthAuthenticated) {
      ref.read(dropboxStateProvider.notifier).state =
          const DropboxError('Non sei autenticato con Dropbox. Torna indietro e effettua il login.');
      return;
    }

    try {
      await ref.read(dropboxStateProvider.notifier).initialize();
    } catch (e) {
      if (kDebugMode) {
        print('❌ Errore inizializzazione Dropbox Dialog: $e');
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dropboxState = ref.watch(dropboxStateProvider);
    final selectedFiles = ref.watch(selectedDropboxFilesProvider);

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        width: 800,
        height: 600,
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            _buildHeader(),
            _buildSearchBar(),

            if (dropboxState is DropboxLoaded && dropboxState.breadcrumbs.isNotEmpty)
              _buildBreadcrumbs(dropboxState.breadcrumbs),

            Expanded(
              child: _buildContent(dropboxState),
            ),

            _buildFooter(selectedFiles),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.divider),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.cloud_outlined,
              color: AppColors.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Seleziona file da Dropbox',
                  style: AppTextStyles.heading3,
                ),
                SizedBox(height: 4),
                Text(
                  'Scegli i file da utilizzare come riferimento nella conversazione',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, color: AppColors.iconSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        decoration: InputDecoration(
          hintText: 'Cerca file o cartelle...',
          prefixIcon: const Icon(Icons.search, color: AppColors.iconSecondary),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () {
                    _searchController.clear();
                    ref.read(dropboxStateProvider.notifier).clearSearch();
                    setState(() {});
                  },
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.outline),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.outline),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.primary, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        onSubmitted: (value) {
          if (value.isNotEmpty) {
            ref.read(dropboxStateProvider.notifier).searchFiles(value);
          }
        },
        onChanged: (value) {
          setState(() {});
        },
      ),
    );
  }

  Widget _buildBreadcrumbs(List<BreadcrumbItem> breadcrumbs) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(color: AppColors.divider),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.folder, size: 16, color: AppColors.iconSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: breadcrumbs.length,
              separatorBuilder: (_, __) => const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Icon(Icons.chevron_right, size: 16, color: AppColors.iconSecondary),
              ),
              itemBuilder: (context, index) {
                final item = breadcrumbs[index];
                final isLast = index == breadcrumbs.length - 1;

                return InkWell(
                  onTap: isLast ? null : () {
                    ref.read(dropboxStateProvider.notifier)
                        .navigateToFolder(item.path, item.name);
                  },
                  child: Container(
                    alignment: Alignment.center,
                    child: Text(
                      item.name,
                      style: TextStyle(
                        fontSize: 13,
                        color: isLast ? AppColors.textPrimary : AppColors.primary,
                        fontWeight: isLast ? FontWeight.w500 : FontWeight.normal,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(DropboxState state) {
    return switch (state) {
      DropboxInitial() => const Center(
          child: Text('Inizializzazione...'),
        ),
      DropboxLoading() => const Center(
          child: CircularProgressIndicator(),
        ),
      DropboxError(:final message) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.error),
              const SizedBox(height: 16),
              Text(message, style: const TextStyle(color: AppColors.error)),
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: () {
                  ref.read(dropboxStateProvider.notifier).initialize();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Riprova'),
              ),
            ],
          ),
        ),
      DropboxLoaded(:final files) => files.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.folder_open, size: 48, color: AppColors.iconSecondary.withOpacity(0.5)),
                  const SizedBox(height: 16),
                  const Text(
                    'Nessun file trovato',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: files.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final file = files[index];
                return _buildFileItem(file);
              },
            ),
    };
  }

  Widget _buildFileItem(DropboxFile file) {
    final isSelected = _tempSelectedIds.contains(file.id) ||
                      ref.read(selectedDropboxFilesProvider).any((f) => f.id == file.id);

    return Material(
      color: isSelected ? AppColors.primary.withOpacity(0.05) : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: () {
          if (file.isFolder) {
            ref.read(dropboxStateProvider.notifier)
                .navigateToFolder(file.pathLower, file.name);
          } else {
            setState(() {
              if (_tempSelectedIds.contains(file.id)) {
                _tempSelectedIds.remove(file.id);
              } else {
                _tempSelectedIds.add(file.id);
              }
            });
          }
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.outline,
              width: isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              if (!file.isFolder)
                Checkbox(
                  value: isSelected,
                  onChanged: (value) {
                    setState(() {
                      if (value ?? false) {
                        _tempSelectedIds.add(file.id);
                      } else {
                        _tempSelectedIds.remove(file.id);
                      }
                    });
                  },
                  activeColor: AppColors.primary,
                ),

              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    file.fileTypeIcon,
                    style: const TextStyle(fontSize: 20),
                  ),
                ),
              ),

              const SizedBox(width: 12),

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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      children: [
                        Text(
                          file.fileTypeDescription,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        if (file.formattedSize.isNotEmpty) ...[
                          const Text(
                            ' • ',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textTertiary,
                            ),
                          ),
                          Text(
                            file.formattedSize,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                        if (file.serverModified != null) ...[
                          const Text(
                            ' • ',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textTertiary,
                            ),
                          ),
                          Text(
                            _formatDate(file.serverModified!),
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              if (file.isFolder)
                const Icon(
                  Icons.chevron_right,
                  color: AppColors.iconSecondary,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFooter(List<DropboxFile> alreadySelected) {
    final totalSelected = _tempSelectedIds.length + alreadySelected.length;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: AppColors.divider),
        ),
      ),
      child: Row(
        children: [
          if (totalSelected > 0) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$totalSelected file selezionati',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],

          const Spacer(),

          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annulla'),
          ),

          const SizedBox(width: 12),

          ElevatedButton(
            onPressed: _tempSelectedIds.isEmpty ? null : () {
              final dropboxState = ref.read(dropboxStateProvider);
              if (dropboxState is DropboxLoaded) {
                final selectedFiles = dropboxState.files
                    .where((f) => _tempSelectedIds.contains(f.id))
                    .toList();

                for (final file in selectedFiles) {
                  ref.read(selectedDropboxFilesProvider.notifier).addFile(file);
                }

                Navigator.of(context).pop(selectedFiles);
              }
            },
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('Aggiungi'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Oggi ${DateFormat('HH:mm').format(date)}';
    } else if (difference.inDays == 1) {
      return 'Ieri';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} giorni fa';
    } else {
      return DateFormat('dd/MM/yyyy').format(date);
    }
  }
}
