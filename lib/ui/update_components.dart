import 'package:flutter/material.dart';

import '../core/tokens.dart';
import '../data/app_updater.dart';
import 'growvia_components.dart';
import 'growvia_icon.dart';

class AppUpdateBanner extends StatelessWidget {
  const AppUpdateBanner({
    required this.updater,
    required this.onOpenUpdate,
    super.key,
  });

  final AppUpdateController updater;
  final VoidCallback onOpenUpdate;

  @override
  Widget build(BuildContext context) {
    final release = updater.latestRelease;
    if (release == null || !updater.showBanner) {
      return const SizedBox.shrink();
    }
    final t = GrowviaTokens.of(context);
    final downloading = updater.status == AppUpdateStatus.downloading;
    final pct = updater.progress != null
        ? '${(updater.progress! * 100).round()}%'
        : null;

    return Material(
      color: t.paleGreen,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: t.successLine)),
        ),
        child: Wrap(
          spacing: 10,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          alignment: WrapAlignment.spaceBetween,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GrowviaIcon('refresh', size: 17, color: t.green),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    downloading
                        ? 'Mengunduh ${release.version.label}${pct != null ? ' ($pct)' : '…'}'
                        : 'Pembaruan ${release.version.label} tersedia',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: t.ink,
                    ),
                  ),
                ),
              ],
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                FilledButton(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 38),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                  ),
                  onPressed: onOpenUpdate,
                  child: Text(downloading ? 'Lihat progres' : 'Perbarui'),
                ),
                const SizedBox(width: 4),
                IconButton(
                  tooltip: 'Tutup pemberitahuan pembaruan',
                  visualDensity: VisualDensity.compact,
                  onPressed: updater.dismissBanner,
                  icon: GrowviaIcon('close', size: 16, color: t.secondary),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

void showAppUpdateSheet(BuildContext context, AppUpdateController updater) {
  final t = GrowviaTokens.of(context);
  showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: t.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) => FractionallySizedBox(
      heightFactor: 0.78,
      child: SafeArea(
        child: ListenableBuilder(
          listenable: updater,
          builder: (context, _) => _AppUpdateSheetBody(updater: updater),
        ),
      ),
    ),
  );
}

class _AppUpdateSheetBody extends StatelessWidget {
  const _AppUpdateSheetBody({required this.updater});

  final AppUpdateController updater;

  @override
  Widget build(BuildContext context) {
    final t = GrowviaTokens.of(context);
    final release = updater.latestRelease;
    final status = updater.status;
    final downloading = status == AppUpdateStatus.downloading;
    final needsPermission = status == AppUpdateStatus.permissionRequired;
    final pct = updater.progress;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
      children: [
        Center(
          child: Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: t.line,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          alignment: WrapAlignment.spaceBetween,
          children: [
            Text(
              'Pembaruan aplikasi',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: t.ink,
              ),
            ),
            if (release != null)
              GrowviaBadge(
                release.version.label,
                tone: updater.hasUpdate ? 'green' : 'neutral',
                uppercase: false,
                dot: updater.hasUpdate,
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          release != null && updater.hasUpdate
              ? 'Terpasang ${updater.installedVersion.label} -> Terbaru ${release.version.label} (${formatFileSize(release.apkSizeBytes)})'
              : 'Versi terpasang saat ini: ${updater.installedVersion.fullLabel}',
          style: TextStyle(
            fontSize: 13,
            color: t.secondary,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 14),
        if (release != null && release.notes.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: t.soft,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: t.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Catatan rilis',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: t.muted,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  release.notes,
                  style: TextStyle(
                    fontSize: 13,
                    color: t.ink,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],
        if (downloading) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: t.soft,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: t.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  pct != null
                      ? 'Mengunduh ${(pct * 100).round()}% · ${formatFileSize(updater.downloadedBytes)} / ${formatFileSize(updater.totalBytes)}'
                      : 'Mengunduh ${formatFileSize(updater.downloadedBytes)}…',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: t.ink,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: pct,
                    minHeight: 8,
                    backgroundColor: t.line,
                    color: t.green,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],
        if (needsPermission) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: t.paleAmber,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: t.amber.withValues(alpha: 0.35)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Izin pemasangan diperlukan',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: t.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Aktifkan "Izinkan dari sumber ini" untuk Growvia di pengaturan Android, lalu tekan Pasang sekarang.',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: t.secondary,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],
        if (updater.errorMessage != null) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: t.paleRed,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: t.dangerLine),
            ),
            child: Text(
              updater.errorMessage!,
              style: TextStyle(fontSize: 13, color: t.red, height: 1.4),
            ),
          ),
          const SizedBox(height: 14),
        ] else if (updater.statusMessage != null && !downloading && !needsPermission) ...[
          Text(
            updater.statusMessage!,
            style: TextStyle(fontSize: 13, color: t.secondary),
          ),
          const SizedBox(height: 14),
        ],
        if (downloading)
          OutlinedButton(
            onPressed: updater.cancelDownload,
            child: const Text('Batalkan unduhan'),
          )
        else if (needsPermission) ...[
          FilledButton(
            onPressed: updater.openInstallSettings,
            child: const Text('Buka izin pemasangan'),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: updater.installDownloaded,
            child: const Text('Pasang sekarang'),
          ),
        ] else if (release != null && updater.hasUpdate) ...[
          FilledButton(
            onPressed: updater.downloadedApkPath != null
                ? updater.installDownloaded
                : updater.downloadAndInstall,
            child: Text(
              updater.downloadedApkPath != null
                  ? 'Pasang ${release.version.label}'
                  : 'Unduh & pasang ${release.version.label}',
            ),
          ),
        ] else ...[
          FilledButton(
            onPressed: status == AppUpdateStatus.checking
                ? null
                : () => updater.checkForUpdate(silent: false),
            child: Text(
              status == AppUpdateStatus.checking
                  ? 'Memeriksa…'
                  : 'Cek pembaruan lagi',
            ),
          ),
        ],
        const SizedBox(height: 10),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Tutup'),
        ),
      ],
    );
  }
}
