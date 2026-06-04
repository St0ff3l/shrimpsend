import 'package:flutter/material.dart';
import '../services/update_manager.dart';

class UpdateBanner extends StatelessWidget {
  const UpdateBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: UpdateManager(),
      builder: (context, _) {
        final manager = UpdateManager();

        return switch (manager.status) {
          UpdateStatus.updateAvailable => _AvailableBanner(manager: manager),
          UpdateStatus.updating => _UpdatingBanner(progress: manager.progress),
          UpdateStatus.readyToRestart => _ReadyToRestartBanner(
              onRestart: manager.restartApp,
            ),
          UpdateStatus.restarting => const _RestartingBanner(),
          _ => const SizedBox.shrink(),
        };
      },
    );
  }
}

class _AvailableBanner extends StatelessWidget {
  final UpdateManager manager;

  const _AvailableBanner({required this.manager});

  @override
  Widget build(BuildContext context) {
    final info = manager.updateInfo!;
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.system_update, color: Colors.blue.shade700, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Update Available',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.blue.shade900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Version ${info.version} • ${(info.fileSize / 1024 / 1024).toStringAsFixed(1)} MB',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
              ],
            ),
          ),
          if (info.updateRequired != null && !info.updateRequired!) ...[
            TextButton(onPressed: manager.dismiss, child: const Text('Later')),
            const SizedBox(width: 4),
          ],
          ElevatedButton(
            onPressed: manager.startUpdate,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade700,
              foregroundColor: Colors.white,
            ),
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }
}

class _UpdatingBanner extends StatelessWidget {
  final double progress;

  const _UpdatingBanner({required this.progress});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              value: progress,
              color: Colors.blue.shade700,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Updating...',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.blue.shade900,
                  ),
                ),
                const SizedBox(height: 4),
                LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.blue.shade100,
                  color: Colors.blue.shade700,
                ),
                const SizedBox(height: 4),
                Text(
                  '${(progress * 100).toStringAsFixed(0)}%',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RestartingBanner extends StatelessWidget {
  const _RestartingBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.blue.shade700,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Restarting…',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.blue.shade900,
                  ),
                ),
                const SizedBox(height: 4),
                LinearProgressIndicator(
                  backgroundColor: Colors.blue.shade100,
                  color: Colors.blue.shade700,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReadyToRestartBanner extends StatelessWidget {
  final VoidCallback onRestart;

  const _ReadyToRestartBanner({required this.onRestart});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle, color: Colors.green.shade700, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Update Ready',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.green.shade900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Tap below to quit and restart automatically (a few seconds)',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: onRestart,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade700,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.restart_alt, size: 18),
            label: const Text('Quit & Restart'),
          ),
        ],
      ),
    );
  }
}
