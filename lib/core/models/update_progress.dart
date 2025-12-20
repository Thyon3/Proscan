// core/models/update_progress.dart

/// Represents the current stage of a document update operation
enum UpdateStage {
  /// Creating snapshot for rollback
  creatingSnapshot,
  
  /// Generating PDF from pages
  generatingPdf,
  
  /// Calculating file checksum
  calculatingChecksum,
  
  /// Preparing update with backend
  preparingUpdate,
  
  /// Uploading file to Supabase Storage
  uploadingToStorage,
  
  /// Uploading thumbnail to Supabase Storage
  uploadingThumbnail,
  
  /// Committing update to backend database
  committingUpdate,
  
  /// Updating local Hive database
  updatingLocal,
  
  /// Cleaning up old files
  cleaningUp,
  
  /// Update completed successfully
  completed,
  
  /// Update failed
  failed,
}

/// Represents the progress of a document update operation
class UpdateProgress {
  final String documentId;
  final UpdateStage stage;
  final double progress; // 0.0 to 1.0
  final String? message;
  final String? error;

  UpdateProgress({
    required this.documentId,
    required this.stage,
    required this.progress,
    this.message,
    this.error,
  });

  /// Creates a progress update for a specific stage
  factory UpdateProgress.stage({
    required String documentId,
    required UpdateStage stage,
    double progress = 0.0,
    String? message,
  }) {
    return UpdateProgress(
      documentId: documentId,
      stage: stage,
      progress: _calculateOverallProgress(stage, progress),
      message: message ?? _getDefaultMessage(stage),
    );
  }

  /// Creates a progress update for failure
  factory UpdateProgress.failed({
    required String documentId,
    required String error,
  }) {
    return UpdateProgress(
      documentId: documentId,
      stage: UpdateStage.failed,
      progress: 0.0,
      message: 'Update failed',
      error: error,
    );
  }

  /// Calculates overall progress based on stage and stage progress
  static double _calculateOverallProgress(UpdateStage stage, double stageProgress) {
    // Weight each stage
    const stageWeights = {
      UpdateStage.creatingSnapshot: 0.0, // 0-5%
      UpdateStage.generatingPdf: 0.05, // 5-25%
      UpdateStage.calculatingChecksum: 0.25, // 25-30%
      UpdateStage.preparingUpdate: 0.30, // 30-35%
      UpdateStage.uploadingToStorage: 0.35, // 35-60%
      UpdateStage.uploadingThumbnail: 0.60, // 60-70%
      UpdateStage.committingUpdate: 0.70, // 70-85%
      UpdateStage.updatingLocal: 0.85, // 85-95%
      UpdateStage.cleaningUp: 0.95, // 95-100%
      UpdateStage.completed: 1.0, // 100%
      UpdateStage.failed: 0.0,
    };

    final baseProgress = stageWeights[stage] ?? 0.0;
    
    if (stage == UpdateStage.completed) {
      return 1.0;
    }
    
    // Calculate stage contribution
    double stageContribution = 0.0;
    switch (stage) {
      case UpdateStage.creatingSnapshot:
        stageContribution = stageProgress * 0.05;
        break;
      case UpdateStage.generatingPdf:
        stageContribution = stageProgress * 0.20;
        break;
      case UpdateStage.calculatingChecksum:
        stageContribution = stageProgress * 0.05;
        break;
      case UpdateStage.preparingUpdate:
        stageContribution = stageProgress * 0.05;
        break;
      case UpdateStage.uploadingToStorage:
        stageContribution = stageProgress * 0.25;
        break;
      case UpdateStage.uploadingThumbnail:
        stageContribution = stageProgress * 0.10;
        break;
      case UpdateStage.committingUpdate:
        stageContribution = stageProgress * 0.15;
        break;
      case UpdateStage.updatingLocal:
        stageContribution = stageProgress * 0.10;
        break;
      case UpdateStage.cleaningUp:
        stageContribution = stageProgress * 0.05;
        break;
      default:
        stageContribution = 0.0;
    }
    
    return (baseProgress + stageContribution).clamp(0.0, 1.0);
  }

  /// Gets default message for a stage
  static String _getDefaultMessage(UpdateStage stage) {
    switch (stage) {
      case UpdateStage.creatingSnapshot:
        return 'Preparing rollback...';
      case UpdateStage.generatingPdf:
        return 'Generating PDF...';
      case UpdateStage.calculatingChecksum:
        return 'Verifying integrity...';
      case UpdateStage.preparingUpdate:
        return 'Preparing update...';
      case UpdateStage.uploadingToStorage:
        return 'Uploading to cloud...';
      case UpdateStage.uploadingThumbnail:
        return 'Uploading thumbnail...';
      case UpdateStage.committingUpdate:
        return 'Saving changes...';
      case UpdateStage.updatingLocal:
        return 'Updating local database...';
      case UpdateStage.cleaningUp:
        return 'Cleaning up...';
      case UpdateStage.completed:
        return 'Update completed!';
      case UpdateStage.failed:
        return 'Update failed';
    }
  }

  /// Gets user-friendly percentage string
  String get percentageString => '${(progress * 100).toInt()}%';

  /// Checks if update is in progress
  bool get isInProgress =>
      stage != UpdateStage.completed && stage != UpdateStage.failed;

  /// Checks if update is completed
  bool get isCompleted => stage == UpdateStage.completed;

  /// Checks if update has failed
  bool get isFailed => stage == UpdateStage.failed;
}
