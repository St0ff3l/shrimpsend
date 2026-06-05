import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/generated/app_localizations.dart';
import '../providers/app_locale.dart';
import '../providers/device_provider.dart';
import 'connection_orchestrator.dart';
import 'connection_resolution.dart';
import 'link_models.dart';
import 'link_recommender.dart';

class ConnectionSwitchProbeState {
  const ConnectionSwitchProbeState({
    required this.peerId,
    required this.mode,
    required this.hint,
  });

  final String peerId;
  final SendMode mode;
  final String hint;
}

final connectionSwitchProbeProvider =
    StateProvider<ConnectionSwitchProbeState?>((_) => null);

class ConnectionBarModeItem {
  const ConnectionBarModeItem({
    required this.mode,
    required this.label,
    required this.available,
    required this.attemptable,
    required this.isSelected,
    this.reachKnownOnline,
    this.reachPullOnly = false,
  });

  final SendMode mode;
  final String label;
  final bool available;
  final bool attemptable;
  final bool isSelected;

  /// Per-mode probe result. `null` on WebRTC means skipped / not probed yet.
  final bool? reachKnownOnline;

  /// HTTP verified only via reverse pull (asymmetric link).
  final bool reachPullOnly;
}

class ConnectionBarViewModel {
  const ConnectionBarViewModel({
    required this.title,
    required this.subtitle,
    required this.manualLocked,
    required this.probing,
    required this.uiTone,
    required this.modeItems,
    this.primaryActionLabel,
    this.showS3SetupEntry = false,
  });

  final String title;
  final String subtitle;
  final bool manualLocked;
  final bool probing;
  final SmartLinkUiTone uiTone;
  final List<ConnectionBarModeItem> modeItems;
  final String? primaryActionLabel;
  final bool showS3SetupEntry;
}

final connectionBarViewModelProvider = Provider<ConnectionBarViewModel?>((ref) {
  final context = watchSelectedConnectionContext(ref);
  if (context == null) {
    return null;
  }

  final l10n = lookupAppLocalizations(ref.watch(appLocaleProvider));
  final orchestrator = ref.watch(connectionOrchestratorProvider);
  final recommendation = ref.watch(linkRecommendationProvider);
  final probing = ref.watch(devicesProbingProvider);
  final sendMode = ref.watch(selectedSendModeProvider);
  final switchProbe = ref.watch(connectionSwitchProbeProvider);
  final probeHint =
      switchProbe != null && switchProbe.peerId == context.selectedDeviceId
      ? '${l10n.connectionBarManualPrefix}${switchProbe.hint}'
      : null;

  return ConnectionBarViewModel(
    title: orchestrator.statusTitle,
    subtitle: mergeConnectionSubtitle(orchestrator.statusSubtitle, probeHint),
    manualLocked: orchestrator.manualLocked,
    probing: probing,
    uiTone: recommendation?.uiTone ?? SmartLinkUiTone.neutral,
    modeItems: buildConnectionBarModeItems(
      candidates: orchestrator.candidates,
      currentMode: sendMode,
      localOs: context.localOs,
      isLoggedIn: context.isLoggedIn,
      isRegisteredPeer: context.isRegisteredPeer,
      l10n: l10n,
    ),
    primaryActionLabel:
        orchestrator.showS3SetupEntry ? l10n.connectionBarGoToS3Setup : null,
    showS3SetupEntry: orchestrator.showS3SetupEntry,
  );
});

List<ConnectionBarModeItem> buildConnectionBarModeItems({
  required List<ConnectionCandidate> candidates,
  required SendMode currentMode,
  required AppLocalizations l10n,
  String? localOs,
  bool isLoggedIn = true,
  bool isRegisteredPeer = true,
  bool transferBarLabels = false,
  DeviceReachDetail? reach,
}) {
  final visible = visibleConnectionCandidatesForUi(
    candidates: candidates,
    isLoggedIn: isLoggedIn,
    isRegisteredPeer: isRegisteredPeer,
  );
  final accountModes = isLoggedIn && isRegisteredPeer;
  final modeForSelection = accountModes ? currentMode : SendMode.nearby;

  final byMode = <SendMode, ConnectionBarModeItem>{};
  final reachDetail = reach ?? DeviceReachDetail.offlineDetail;
  for (final candidate in visible) {
    final reachKnownOnline = switch (candidate.mode) {
      SendMode.webrtc => reach?.webrtc,
      SendMode.lan => httpTransferAvailable(reachDetail),
      _ => candidate.available,
    };
    final reachPullOnly = candidate.mode == SendMode.lan &&
        httpPullOnlyAvailable(reachDetail);
    byMode.putIfAbsent(
      candidate.mode,
      () => ConnectionBarModeItem(
        mode: candidate.mode,
        label: transferBarLabels
            ? transferModeBarLabel(candidate.mode, l10n: l10n)
            : connectionModeLabel(candidate.mode, localOs: localOs, l10n: l10n),
        available: candidate.available,
        attemptable: candidate.attemptable,
        isSelected: candidate.mode == modeForSelection,
        reachKnownOnline: reachKnownOnline,
        reachPullOnly: reachPullOnly,
      ),
    );
  }

  byMode.putIfAbsent(
    modeForSelection,
    () => ConnectionBarModeItem(
      mode: modeForSelection,
      label: transferBarLabels
          ? transferModeBarLabel(modeForSelection, l10n: l10n)
          : connectionModeLabel(modeForSelection, localOs: localOs, l10n: l10n),
      available: false,
      attemptable: modeForSelection == SendMode.lan && isLoggedIn,
      isSelected: true,
      reachKnownOnline: switch (modeForSelection) {
        SendMode.webrtc => reach?.webrtc,
        SendMode.lan => httpTransferAvailable(reachDetail),
        _ => false,
      },
      reachPullOnly: modeForSelection == SendMode.lan &&
          httpPullOnlyAvailable(reachDetail),
    ),
  );

  final items = byMode.values.toList();
  items.sort((a, b) => _modeOrder(a.mode).compareTo(_modeOrder(b.mode)));
  return items;
}

String mergeConnectionSubtitle(String base, String? hint) {
  final hasBase = base.trim().isNotEmpty;
  final hasHint = hint != null && hint.trim().isNotEmpty;
  if (hasBase && hasHint) return '$base · $hint';
  if (hasHint) return hint.trim();
  return base;
}

int _modeOrder(SendMode mode) {
  switch (mode) {
    case SendMode.lan:
      return 0;
    case SendMode.webrtc:
      return 1;
    case SendMode.nearby:
      return 2;
    case SendMode.s3:
      return 3;
  }
}
