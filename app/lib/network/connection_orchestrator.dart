import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/generated/app_localizations.dart';
import '../providers/app_locale.dart';
import '../providers/device_provider.dart';
import 'connection_resolution.dart';

class ConnectionOrchestratorState {
  const ConnectionOrchestratorState({
    required this.manualLocked,
    required this.activeMode,
    required this.candidates,
    required this.statusTitle,
    required this.statusSubtitle,
    required this.fallbackToS3,
    required this.showS3SetupEntry,
  });

  final bool manualLocked;
  final SendMode? activeMode;
  final List<ConnectionCandidate> candidates;
  final String statusTitle;
  final String statusSubtitle;
  final bool fallbackToS3;
  final bool showS3SetupEntry;

  static const empty = ConnectionOrchestratorState(
    manualLocked: false,
    activeMode: null,
    candidates: [],
    statusTitle: '',
    statusSubtitle: '',
    fallbackToS3: false,
    showS3SetupEntry: false,
  );
}

final connectionManualOverrideProvider = StateProvider<bool>((_) => false);
final connectionManualModeProvider = StateProvider<SendMode?>((_) => null);

final connectionOrchestratorProvider = Provider<ConnectionOrchestratorState>((
  ref,
) {
  final l10n = lookupAppLocalizations(ref.watch(appLocaleProvider));
  final manualLocked = ref.watch(connectionManualOverrideProvider);
  final manualMode = ref.watch(connectionManualModeProvider);
  final context = watchSelectedConnectionContext(ref);
  if (context == null) {
    return ConnectionOrchestratorState.empty;
  }

  final candidates = buildConnectionCandidates(context: context);

  SendMode? activeMode;
  var fallbackToS3 = false;
  var showS3SetupEntry = false;
  var statusTitle = '';
  var statusSubtitle = '';

  if (manualLocked && manualMode != null) {
    activeMode = manualMode;
    ConnectionCandidate? c;
    for (final x in candidates) {
      if (x.mode == manualMode) {
        c = x;
        break;
      }
    }
    final ok =
        c?.available ??
        (manualMode == SendMode.s3
            ? context.s3Online && allowsAccountTransferModes(context)
            : false);
    final modeLabel =
        connectionModeLabel(manualMode, localOs: context.localOs, l10n: l10n);
    statusTitle = ok
        ? l10n.connectionOrchestratorManualOk(modeLabel)
        : l10n.connectionOrchestratorManualUnavailable(modeLabel);
    statusSubtitle =
        ok ? '' : (c?.reason ?? l10n.connectionOrchestratorLinkUnavailable);
  } else {
    ConnectionCandidate? best;
    for (final c in candidates) {
      if (best != null) break;
      if (c.available) {
        best = c;
        break;
      }
    }
    if (best != null) {
      activeMode = best.mode;
      if (best.mode == SendMode.s3) {
        statusTitle = l10n.connectionOrchestratorAutoS3;
        statusSubtitle = l10n.connectionOrchestratorS3FallbackSubtitle;
        fallbackToS3 = true;
      } else {
        statusTitle = l10n.connectionOrchestratorAutoMode(
          connectionModeLabel(best.mode, localOs: context.localOs, l10n: l10n),
        );
        statusSubtitle = '';
      }
    } else if (!context.isLoggedIn) {
      fallbackToS3 = false;
      activeMode = null;
      showS3SetupEntry = false;
      statusTitle = l10n.connectionOrchestratorNoDirect;
      statusSubtitle = l10n.connectionOrchestratorLoginPromptSubtitle;
    } else if (!context.isRegisteredPeer) {
      fallbackToS3 = false;
      activeMode = null;
      showS3SetupEntry = false;
      statusTitle = l10n.connectionOrchestratorNoDirect;
      statusSubtitle = '';
    } else {
      fallbackToS3 = true;
      if (context.s3Online) {
        activeMode = SendMode.s3;
        statusTitle = l10n.connectionOrchestratorAutoS3;
        statusSubtitle = l10n.connectionOrchestratorNoDirectS3Fallback;
      } else if (context.s3Configured) {
        activeMode = null;
        showS3SetupEntry = false;
        statusTitle = l10n.connectionOrchestratorNoDirect;
        statusSubtitle = l10n.connectionOrchestratorS3Unavailable;
      } else {
        activeMode = null;
        showS3SetupEntry = true;
        statusTitle = l10n.connectionOrchestratorNoDirect;
        statusSubtitle = l10n.connectionOrchestratorS3NotConfigured;
      }
    }
  }

  return ConnectionOrchestratorState(
    manualLocked: manualLocked,
    activeMode: activeMode,
    candidates: candidates,
    statusTitle: statusTitle,
    statusSubtitle: statusSubtitle,
    fallbackToS3: fallbackToS3,
    showS3SetupEntry: showS3SetupEntry,
  );
});
