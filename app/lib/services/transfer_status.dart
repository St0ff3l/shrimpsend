/// Canonical status values stored in `transfer_records.status` and exchanged
/// across the transfer state machine. Centralised so callers do not duplicate
/// magic strings.
///
/// Semantics (post pause_resume overhaul):
/// - `inProgress`: actively sending/receiving.
/// - `paused`: user cancelled OR the runtime decided to stop. Partial data on
///   disk is preserved and the transfer is resumable.
/// - `failed`: a non-user error tore down the transfer. Partial data may be
///   preserved for retry; UI shows "Retry".
/// - `completed`: terminal success. Record is normally deleted by the manager.
class TransferStatus {
  static const String inProgress = 'in_progress';
  static const String paused = 'paused';
  static const String failed = 'failed';
  static const String completed = 'completed';

  /// Legacy value still recognised when reading old DB rows. New writes should
  /// use [paused] instead so the UI shows a "Continue" affordance.
  static const String cancelled = 'cancelled';

  /// Statuses that can be resumed via retry / cold-start restore.
  static bool isResumable(String status) {
    return status == inProgress ||
        status == paused ||
        status == cancelled ||
        status == failed;
  }

  /// Statuses where no further work can be done on the record.
  static bool isTerminal(String status) => status == completed;

  /// True when the transfer was stopped by the user (rather than by an error).
  /// Used by the UI to decide between "Continue" and "Retry" wording.
  static bool isUserPaused(String status) =>
      status == paused || status == cancelled;
}
