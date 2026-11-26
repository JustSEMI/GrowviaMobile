import 'package:flutter/material.dart';

import '../core/preferences.dart';
import '../core/tokens.dart';
import '../data/app_updater.dart';
import '../ui/components.dart';
import '../ui/growvia_components.dart';
import '../ui/growvia_icon.dart';
import '../ui/update_components.dart';

/// Pengaturan perangkat (alamat API, tema).
///
/// [embedded] dipakai bila halaman ini disisipkan ke halaman lain yang sudah
/// memiliki area gulir sendiri (mis. tab Preferensi di ruang kerja). Tanpa
/// flag itu, halaman ini membungkus isinya dengan [PageBody] seperti biasa.
class SettingsPage extends StatefulWidget {
  const SettingsPage({
    required this.preferences,
    this.updater,
    this.embedded = false,
    super.key,
  });

  final AppPreferences preferences;
  final AppUpdateController? updater;
  final bool embedded;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _url;
  late ThemeMode _theme;
  bool _busy = false;
  String? _receipt;
  String? _error;

  @override
  void initState() {
    super.initState();
    _url = TextEditingController(text: widget.preferences.apiUrl);
    _theme = widget.preferences.themeMode;
  }

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate() || _busy) return;
    setState(() {
      _busy = true;
      _receipt = null;
      _error = null;
    });
    try {
      await widget.preferences.save(_url.text, _theme);
      if (!mounted) return;
      setState(
        () => _receipt =
            'Tersimpan di perangkat ini. Koneksi belum diverifikasi; verifikasi akun dilakukan saat masuk.',
      );
    } catch (error) {
      debugPrint('GROWVIA_PREFS_SAVE_FAIL: $error');
      if (mounted) {
        setState(() => _error = 'Pengaturan belum tersimpan. Coba kembali.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final preferences = widget.preferences;
    final t = GrowviaTokens.of(context);
    final content = <Widget>[
      const PageIntro(
        eyebrow: 'Preferensi lokal',
        title: 'Pengaturan perangkat ini',
        description: 'Atur alamat server dan tema tampilan aplikasi.',
      ),
      const SizedBox(height: 16),
      if (preferences.storageError != null) ...[
        Notice(
          title: 'Preferensi lokal',
          message: preferences.storageError!,
          error: true,
        ),
        const SizedBox(height: 14),
      ],
      Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GrowviaPanel(
              padding: 18,
              title: 'Koneksi REST API',
              subtitle: 'Perubahan alamat berlaku untuk login berikutnya.',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    key: const Key('api-url'),
                    controller: _url,
                    decoration: InputDecoration(
                      labelText: 'Alamat API',
                      hintText: 'https://domain-kamu/api/v1',
                      helperText: preferences.endpointPolicy.localHttpAllowed
                          ? 'USB: http://127.0.0.1:8000/api/v1 · Emulator: http://10.0.2.2:8000/api/v1'
                          : null,
                      helperMaxLines: 3,
                    ),
                    keyboardType: TextInputType.url,
                    autocorrect: false,
                    enableSuggestions: false,
                    validator: (value) => preferences.endpointPolicy.validate(
                      value ?? '',
                      allowEmpty: true,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            GrowviaPanel(
              padding: 18,
              title: 'Tema tampilan',
              subtitle: 'Pilih mode warna yang nyaman di layar perangkat.',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Semantics(
                    key: const Key('theme-choice'),
                    label: 'Pilihan tema',
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        const modes = <(ThemeMode, String, String)>[
                          (ThemeMode.system, 'display', 'Sistem'),
                          (ThemeMode.light, 'sun', 'Terang'),
                          (ThemeMode.dark, 'moon', 'Gelap'),
                        ];
                        final narrow = constraints.maxWidth < 290;
                        final scale =
                            MediaQuery.textScalerOf(context).scale(13) / 13;
                        if (narrow || scale > 1.4) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (final (mode, icon, label) in modes) ...[
                                _ThemeOptionTile(
                                  optionKey: Key(
                                    'theme-choice-option-${mode.name}',
                                  ),
                                  icon: icon,
                                  label: label,
                                  selected: _theme == mode,
                                  enabled: !_busy,
                                  onTap: () => setState(() => _theme = mode),
                                ),
                                const SizedBox(height: 8),
                              ],
                            ],
                          );
                        }
                        return Row(
                          children: [
                            for (var i = 0; i < modes.length; i++) ...[
                              if (i > 0) const SizedBox(width: 8),
                              Expanded(
                                child: _ThemeOptionTile(
                                  optionKey: Key(
                                    'theme-choice-option-${modes[i].$1.name}',
                                  ),
                                  icon: modes[i].$2,
                                  label: modes[i].$3,
                                  selected: _theme == modes[i].$1,
                                  enabled: !_busy,
                                  onTap: () =>
                                      setState(() => _theme = modes[i].$1),
                                ),
                              ),
                            ],
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _busy ? null : _save,
                    child: Text(_busy ? 'Menyimpan…' : 'Simpan di perangkat'),
                  ),
                ],
              ),
            ),
            if (_receipt != null) ...[
              const SizedBox(height: 14),
              Notice(
                title: 'Pengaturan disimpan',
                message: _receipt!,
                success: true,
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 14),
              Notice(title: 'Belum tersimpan', message: _error!, error: true),
            ],
          ],
        ),
      ),
      const SizedBox(height: 16),
      _AboutGrowviaPanel(apiUrl: preferences.apiUrl, updater: widget.updater),
      const SizedBox(height: 10),
      if (widget.updater != null)
        ListenableBuilder(
          listenable: widget.updater!,
          builder: (context, _) => Text(
            'Growvia Mobile · ${widget.updater!.installedVersion.versionName} · Bahasa Indonesia · Android',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: t.muted),
          ),
        )
      else
        Text(
          'Growvia Mobile · $kFallbackAppVersion · Bahasa Indonesia · Android',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: t.muted),
        ),
    ];

    if (widget.embedded) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: content,
      );
    }
    return PageBody(children: content);
  }
}

class _AboutGrowviaPanel extends StatelessWidget {
  const _AboutGrowviaPanel({required this.apiUrl, this.updater});

  final String apiUrl;
  final AppUpdateController? updater;

  static const _fallbackVersion = AppVersion(
    major: 0,
    minor: 1,
    patch: 0,
    buildNumber: kFallbackBuildNumber,
  );

  String get _hostSummary {
    final trimmed = apiUrl.trim();
    if (trimmed.isEmpty) return 'Belum diatur';
    final uri = Uri.tryParse(trimmed);
    if (uri == null || uri.host.isEmpty) return trimmed;
    return uri.hasPort ? '${uri.host}:${uri.port}' : uri.host;
  }

  void _openReleaseDetails(BuildContext context, AppVersion currentVersion) {
    final t = GrowviaTokens.of(context);
    final version = currentVersion.versionName;
    final buildNumber = currentVersion.buildNumber.toString();
    final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: t.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => FractionallySizedBox(
        heightFactor: 0.78,
        child: SafeArea(
          child: ListView(
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
                spacing: 12,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                alignment: WrapAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const _BrandMark(),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Growvia Mobile',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: t.ink,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Versi $version · Build $buildNumber',
                              style: TextStyle(
                                fontSize: 13,
                                color: t.muted,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (scale <= 1.35)
                    const GrowviaBadge('Stabil', tone: 'green', dot: true),
                ],
              ),
              if (scale > 1.35) ...[
                const SizedBox(height: 10),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: GrowviaBadge('Stabil', tone: 'green', dot: true),
                ),
              ],
              const SizedBox(height: 14),
              Text(
                'Aplikasi pendamping kebun pintar Growvia untuk memantau Device 1 (iklim) & Device 2 (tanah, tandon, pompa), memeriksa riwayat pembacaan, serta menyinkronkan konfigurasi ke backend Laravel.',
                style: TextStyle(
                  fontSize: 13,
                  color: t.secondary,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: t.soft,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: t.line),
                ),
                child: Column(
                  children: [
                    _SpecDetailRow(
                      label: 'Versi rilis',
                      value: 'v$version+$buildNumber',
                    ),
                    const SizedBox(height: 9),
                    _SpecDetailRow(
                      label: 'Platform & bahasa',
                      value: 'Android · Bahasa Indonesia',
                    ),
                    const SizedBox(height: 9),
                    _SpecDetailRow(
                      label: 'Protokol telemetri',
                      value: 'REST API v1 & Live MQTT',
                    ),
                    const SizedBox(height: 9),
                    _SpecDetailRow(
                      label: 'Penyimpanan sesi',
                      value: 'Terenkripsi di perangkat',
                    ),
                    const SizedBox(height: 9),
                    _SpecDetailRow(
                      label: 'Server API aktif',
                      value: _hostSummary,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (updater != null) ...[
                OutlinedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    if (updater!.hasUpdate) {
                      showAppUpdateSheet(context, updater!);
                    } else {
                      updater!.checkForUpdate(silent: false);
                      showAppUpdateSheet(context, updater!);
                    }
                  },
                  child: Text(
                    updater!.hasUpdate
                        ? 'Pasang pembaruan ${updater!.latestRelease!.version.label}'
                        : 'Cek pembaruan di GitHub',
                  ),
                ),
                const SizedBox(height: 10),
              ],
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Tutup'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeUpdater = updater;
    if (activeUpdater == null) {
      return _buildCard(context, _fallbackVersion, null);
    }
    return ListenableBuilder(
      listenable: activeUpdater,
      builder: (context, _) => _buildCard(
        context,
        activeUpdater.installedVersion,
        activeUpdater,
      ),
    );
  }

  Widget _buildCard(
    BuildContext context,
    AppVersion currentVersion,
    AppUpdateController? activeUpdater,
  ) {
    final t = GrowviaTokens.of(context);
    final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
    final version = currentVersion.versionName;
    final buildNumber = currentVersion.buildNumber.toString();
    return GrowviaPanel(
      padding: 18,
      footer: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 310 || scale > 1.35) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ruang kerja kebun · Dirawat bareng.',
                  style: TextStyle(fontSize: 12, color: t.muted),
                ),
                const SizedBox(height: 4),
                TextButton(
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                  ),
                  onPressed: () => _openReleaseDetails(context, currentVersion),
                  child: const Text('Detail rilis'),
                ),
              ],
            );
          }
          return Row(
            children: [
              Expanded(
                child: Text(
                  'Ruang kerja kebun · Dirawat bareng.',
                  style: TextStyle(fontSize: 12, color: t.muted),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, 48),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                ),
                onPressed: () => _openReleaseDetails(context, currentVersion),
                child: const Text('Detail rilis'),
              ),
            ],
          );
        },
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final versionPill = GrowviaBadge(
                'v$version+$buildNumber',
                tone: 'green',
                uppercase: false,
              );
              final headerCopy = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tentang aplikasi',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.7,
                      color: t.muted,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Growvia Mobile',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                      color: t.ink,
                    ),
                  ),
                  Text(
                    'Pendamping ruang kerja rumah kaca',
                    style: TextStyle(fontSize: 12.5, color: t.secondary),
                  ),
                ],
              );
              if (constraints.maxWidth < 290 || scale > 1.35) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const _BrandMark(),
                        const SizedBox(width: 12),
                        Expanded(child: headerCopy),
                      ],
                    ),
                    const SizedBox(height: 10),
                    versionPill,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _BrandMark(),
                  const SizedBox(width: 12),
                  Expanded(child: headerCopy),
                  const SizedBox(width: 8),
                  versionPill,
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          Divider(height: 1, color: t.line),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final specs = [
                ('Versi rilis', 'v$version (Build $buildNumber)'),
                ('Server API', _hostSummary),
                ('Protokol', 'REST v1 · Live MQTT'),
                ('Platform', 'Android · Indonesia'),
              ];
              if (constraints.maxWidth < 310 || scale > 1.35) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < specs.length; i++) ...[
                      if (i > 0) const SizedBox(height: 8),
                      _AboutSpecTile(label: specs[i].$1, value: specs[i].$2),
                    ],
                  ],
                );
              }
              return Column(
                children: [
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: _AboutSpecTile(
                            label: specs[0].$1,
                            value: specs[0].$2,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _AboutSpecTile(
                            label: specs[1].$1,
                            value: specs[1].$2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: _AboutSpecTile(
                            label: specs[2].$1,
                            value: specs[2].$2,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _AboutSpecTile(
                            label: specs[3].$1,
                            value: specs[3].$2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
          if (activeUpdater != null) ...[
            const SizedBox(height: 12),
            if (activeUpdater.hasUpdate)
              FilledButton.icon(
                key: const Key('app-update-action'),
                onPressed: () => showAppUpdateSheet(context, activeUpdater),
                icon: const GrowviaIcon('refresh', size: 17),
                label: Text(
                  activeUpdater.status == AppUpdateStatus.downloading
                      ? 'Lihat progres unduhan'
                      : 'Perbarui ke ${activeUpdater.latestRelease!.version.label}',
                ),
              )
            else
              OutlinedButton.icon(
                key: const Key('app-update-action'),
                onPressed: activeUpdater.status == AppUpdateStatus.checking
                    ? null
                    : () => activeUpdater.checkForUpdate(silent: false),
                icon: const GrowviaIcon('refresh', size: 17),
                label: Text(
                  activeUpdater.status == AppUpdateStatus.checking
                      ? 'Memeriksa pembaruan…'
                      : 'Cek pembaruan aplikasi',
                ),
              ),
            if (activeUpdater.errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                activeUpdater.errorMessage!,
                style: TextStyle(fontSize: 12, color: t.red),
              ),
            ] else if (activeUpdater.statusMessage != null &&
                activeUpdater.status != AppUpdateStatus.idle) ...[
              const SizedBox(height: 8),
              Text(
                activeUpdater.statusMessage!,
                style: TextStyle(
                  fontSize: 12,
                  color: activeUpdater.hasUpdate ? t.green : t.secondary,
                  fontWeight: activeUpdater.hasUpdate
                      ? FontWeight.w600
                      : FontWeight.w400,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    final t = GrowviaTokens.of(context);
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: t.brandSurface,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Center(
        child: GrowviaIcon('leaf', size: 20, color: t.brandInk),
      ),
    );
  }
}

class _AboutSpecTile extends StatelessWidget {
  const _AboutSpecTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final t = GrowviaTokens.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: t.soft,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: t.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: t.muted,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: t.ink,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _SpecDetailRow extends StatelessWidget {
  const _SpecDetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final t = GrowviaTokens.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(label, style: TextStyle(fontSize: 13, color: t.muted)),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: t.ink,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }
}

class _ThemeOptionTile extends StatelessWidget {
  const _ThemeOptionTile({
    required this.optionKey,
    required this.icon,
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final Key optionKey;
  final String icon;
  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = GrowviaTokens.of(context);
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? t.paleGreen : t.soft,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: optionKey,
          onTap: enabled ? onTap : null,
          child: Container(
            constraints: const BoxConstraints(minHeight: 54),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? t.green : t.line,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GrowviaIcon(
                  icon,
                  size: 18,
                  color: selected ? t.green : t.secondary,
                ),
                const SizedBox(height: 5),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? t.navActive : t.ink,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
