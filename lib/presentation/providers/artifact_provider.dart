import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/document_artifact.dart';

final selectedArtifactsProvider = StateNotifierProvider<SelectedArtifactsNotifier, List<DocumentArtifact>>((ref) {
  return SelectedArtifactsNotifier();
});

class SelectedArtifactsNotifier extends StateNotifier<List<DocumentArtifact>> {
  SelectedArtifactsNotifier() : super([]);

  void setArtifact(DocumentArtifact artifact) {
    // Replace the current artifact with the new one (only show one at a time)
    state = [artifact];
  }

  void addArtifact(DocumentArtifact artifact) {
    if (!state.any((a) => a.id == artifact.id)) {
      state = [...state, artifact];
    }
  }

  void removeArtifact(String artifactId) {
    state = state.where((a) => a.id != artifactId).toList();
  }

  void toggleArtifact(DocumentArtifact artifact) {
    if (state.any((a) => a.id == artifact.id)) {
      removeArtifact(artifact.id);
    } else {
      addArtifact(artifact);
    }
  }

  void clearArtifacts() {
    state = [];
  }
}
