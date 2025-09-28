import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/app_theme.dart';
import '../../data/datasources/remote/google_drive_service.dart';
import '../providers/google_drive_provider.dart';

class GoogleDriveDialog extends ConsumerStatefulWidget {
  const GoogleDriveDialog({super.key});
  
  static Future<List<DriveFile>?> show(BuildContext context) async {
    return showDialog<List<DriveFile>>(
      context: context,
      builder: (context) => const GoogleDriveDialog(),
      barrierDismissible: false,
    );
  }

  @override
  ConsumerState<GoogleDriveDialog> createState() => _GoogleDriveDialogState();
}

class _GoogleDriveDialogState extends ConsumerState<GoogleDriveDialog> {
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
    final googleAuthState = ref.read(googleAuthStateProvider);

    if (googleAuthState is! GoogleAuthAuthenticated) {
      ref.read(googleDriveStateProvider.notifier).state =
          const GoogleDriveError('Non sei autenticato con Google. Torna indietro e effettua il login.');
      return;
    }

    try {
      await ref.read(googleDriveStateProvider.notifier).initialize();
    } catch (e) {
      if (kDebugMode) {
        print('❌ Errore inizializzazione Drive Dialog: $e');
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
    final driveState = ref.watch(googleDriveStateProvider);
    final selectedFiles = ref.watch(selectedDriveFilesProvider);
    
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

            if (driveState is GoogleDriveLoaded && driveState.breadcrumbs.isNotEmpty)
              _buildBreadcrumbs(driveState.breadcrumbs),

            Expanded(
              child: _buildContent(driveState),
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
              Icons.add_to_drive,
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
                  'Seleziona file da Google Drive',
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
                    ref.read(googleDriveStateProvider.notifier).clearSearch();
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
            ref.read(googleDriveStateProvider.notifier).searchFiles(value);
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
                    ref.read(googleDriveStateProvider.notifier)
                        .navigateToFolder(item.id, item.name);
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
  
  Widget _buildContent(GoogleDriveState state) {
    return switch (state) {
      GoogleDriveInitial() => const Center(
          child: Text('Inizializzazione...'),
        ),
      GoogleDriveLoading() => const Center(
          child: CircularProgressIndicator(),
        ),
      GoogleDriveError(:final message) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.error),
              const SizedBox(height: 16),
              Text(message, style: const TextStyle(color: AppColors.error)),
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: () {
                  ref.read(googleDriveStateProvider.notifier).initialize();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Riprova'),
              ),
            ],
          ),
        ),
      GoogleDriveLoaded(:final files) => files.isEmpty
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
  
  Widget _buildFileItem(DriveFile file) {
    final isSelected = _tempSelectedIds.contains(file.id) || 
                      ref.read(selectedDriveFilesProvider).any((f) => f.id == file.id);
    
    return Material(
      color: isSelected ? AppColors.primary.withOpacity(0.05) : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: () {
          if (file.isFolder) {
            ref.read(googleDriveStateProvider.notifier)
                .navigateToFolder(file.id, file.name);
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
                  color: file.isFolder 
                      ? Colors.amber.withOpacity(0.1)
                      : AppColors.surface,
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
                    Row(
                      children: [
                        Text(
                          file.fileTypeDescription,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        if (file.size != null && file.size!.isNotEmpty) ...[
                          const Text(
                            ' • ',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textTertiary,
                            ),
                          ),
                          Text(
                            file.size!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                        if (file.modifiedTime != null) ...[
                          const Text(
                            ' • ',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textTertiary,
                            ),
                          ),
                          Text(
                            _formatDate(file.modifiedTime!),
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
  
  Widget _buildFooter(List<DriveFile> alreadySelected) {
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
              final driveState = ref.read(googleDriveStateProvider);
              if (driveState is GoogleDriveLoaded) {
                final selectedFiles = driveState.files
                    .where((f) => _tempSelectedIds.contains(f.id))
                    .toList();

                for (final file in selectedFiles) {
                  ref.read(selectedDriveFilesProvider.notifier).addFile(file);
                }

                Navigator.of(context).pop(selectedFiles);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: Text(
              _tempSelectedIds.isEmpty 
                  ? 'Seleziona almeno un file'
                  : 'Aggiungi ${_tempSelectedIds.length} file',
            ),
          ),
        ],
      ),
    );
  }
  
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays == 0) {
      return 'Oggi';
    } else if (difference.inDays == 1) {
      return 'Ieri';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} giorni fa';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}