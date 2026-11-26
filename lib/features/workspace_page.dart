import 'package:flutter/material.dart';

import '../core/app_controller.dart';
import '../core/tokens.dart';
import '../ui/components.dart';
import '../ui/dashboard_components.dart';
import '../ui/growvia_components.dart';
import '../ui/growvia_icon.dart';
import '../ui/update_components.dart';
import 'account_page.dart';
import 'activity_page.dart';
import 'backup_page.dart';
import 'dashboard_page.dart';
import 'guide_page.dart';
import 'history_page.dart';
import 'node_detail_page.dart';
import 'sessions_page.dart';
import 'settings_page.dart';
import 'system_settings_page.dart';
import 'users_page.dart';

class WorkspacePage extends StatefulWidget {
  const WorkspacePage({required this.controller, super.key});
  final AppController controller;
  @override
  State<WorkspacePage> createState() => _WorkspacePageState();
}

class _WorkspacePageState extends State<WorkspacePage> {
  int _tab = 0;
  static const _labels = ['Kebun', 'Riwayat', 'Edukasi', 'Pengaturan'];
  // Ikon Growvia yang sama dengan <x-icon> di web.
  static const _icons = ['grid', 'chart', 'book', 'settings'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.controller.session != null) {
        loadWorkspaceForDisplay(widget.controller);
      }
    });
  }

  void _open(Widget page) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

  Future<void> _exit() async {
    if (widget.controller.preview) {
      await widget.controller.logout();
      return;
    }
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const GrowviaIcon('logout', size: 26),
        title: const Text('Keluar dari akun?'),
        content: const Text(
          'Data akun akan dihapus dari tampilan perangkat ini. Token sesi juga akan dicabut di server jika koneksi tersedia.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );
    if (approved == true) await widget.controller.logout();
  }

  Widget _drawer() {
    final c = widget.controller;
    final t = GrowviaTokens.of(context);
    Widget link(
      String title,
      String icon,
      VoidCallback action, {
      bool selected = false,
    }) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: selected ? t.paleGreen : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            Navigator.pop(context);
            action();
          },
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 46),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  GrowviaIcon(
                    icon,
                    size: 18,
                    color: selected ? t.green : t.secondary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.w500,
                        color: selected ? t.navActive : t.ink,
                      ),
                    ),
                  ),
                  if (selected)
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: t.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    Widget label(String text, {bool spaced = false}) => Padding(
      padding: EdgeInsets.fromLTRB(24, spaced ? 16 : 10, 24, 6),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
          color: t.muted,
        ),
      ),
    );

    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: t.line)),
              ),
              child: Row(
                children: [
                  const Expanded(child: Brand()),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: t.soft,
                      border: Border.all(color: t.line),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      c.isAdmin ? 'ADMIN' : 'PETANI',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.7,
                        color: t.secondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            label('Ruang kerja'),
            link(
              'Ringkasan',
              'grid',
              () => setState(() => _tab = 0),
              selected: _tab == 0,
            ),
            link(
              'Iklim · Device 1',
              'sun',
              () => _open(NodeDetailPage(controller: c, node: 'node1')),
            ),
            link(
              'Tanah & air · Device 2',
              'drop',
              () => _open(NodeDetailPage(controller: c, node: 'node2')),
            ),
            link(
              'Riwayat sensor',
              'chart',
              () => setState(() => _tab = 1),
              selected: _tab == 1,
            ),
            link(
              'Edukasi',
              'book',
              () => setState(() => _tab = 2),
              selected: _tab == 2,
            ),
            if (c.isAdmin) ...[
              label('Kelola', spaced: true),
              link('Pengguna', 'users', () => _open(UsersPage(controller: c))),
              link(
                'Aktivitas',
                'clock',
                () => _open(ActivityPage(controller: c)),
              ),
              link(
                'Pengaturan sistem',
                'settings',
                () => _open(SystemSettingsPage(controller: c)),
              ),
              link(
                'Backup database',
                'archive',
                () => _open(BackupPage(controller: c)),
              ),
            ],
            label('Akun & perangkat', spaced: true),
            if (c.session != null) ...[
              link(
                'Profil & keamanan',
                'shield',
                () => _open(AccountPage(controller: c)),
              ),
              link(
                'Sesi perangkat',
                'display',
                () => _open(SessionsPage(controller: c)),
              ),
            ],
            link(
              'Preferensi perangkat',
              'settings',
              () => setState(() => _tab = 3),
              selected: _tab == 3,
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 16),
              child: _accountDock(c),
            ),
          ],
        ),
      ),
    );
  }

  /// Dock akun + keluar di bagian bawah drawer, cerminan `.sidebar-userbar` web.
  Widget _accountDock(AppController c) {
    final t = GrowviaTokens.of(context);
    final name = c.session?.name ?? 'Pratinjau';
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: t.soft,
        border: Border.all(color: t.line),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          if (c.session != null)
            Expanded(
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () {
                    Navigator.pop(context);
                    _open(AccountPage(controller: c));
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: t.surface,
                            shape: BoxShape.circle,
                            border: Border.all(color: t.avatarLine),
                          ),
                          child: Center(
                            child: Text(
                              name.isEmpty
                                  ? '?'
                                  : name.characters.first.toUpperCase(),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: t.avatarInk,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: t.ink,
                                ),
                              ),
                              Text(
                                c.isAdmin ? 'Administrator' : 'Petani',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 11, color: t.muted),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            )
          else
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  'Mode pratinjau',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: t.secondary,
                  ),
                ),
              ),
            ),
          Tooltip(
            message: c.preview ? 'Keluar pratinjau' : 'Keluar akun',
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () {
                Navigator.pop(context);
                _exit();
              },
              child: SizedBox(
                width: 44,
                height: 44,
                child: Center(
                  child: GrowviaIcon('logout', size: 18, color: t.secondary),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = GrowviaTokens.of(context);
    return PopScope(
      canPop: _tab == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _tab != 0) setState(() => _tab = 0);
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide =
              constraints.maxWidth >= 1000 &&
              MediaQuery.textScalerOf(context).scale(14) < 25;
          final c = widget.controller;
          final pages = [
            DashboardPage(controller: c),
            HistoryPage(controller: c),
            const GuidePage(),
            _PreferencesPage(controller: c, active: _tab == 3),
          ];
          return Scaffold(
            drawer: _drawer(),
            appBar: AppBar(
              leading: Builder(
                builder: (context) => IconButton(
                  tooltip: MaterialLocalizations.of(context).openAppDrawerTooltip,
                  onPressed: () => Scaffold.of(context).openDrawer(),
                  icon: const GrowviaIcon('menu', size: 20),
                ),
              ),
              title: const Brand(compact: true),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(1),
                child: Container(height: 1, color: t.line),
              ),
              actions: [
                if (c.session != null)
                  Tooltip(
                    message: 'Profil & keamanan',
                    child: InkWell(
                      borderRadius: BorderRadius.circular(999),
                      onTap: () => _open(AccountPage(controller: c)),
                      child: SizedBox(
                        width: 44,
                        height: 44,
                        child: Center(
                          child: Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: t.avatarSurface,
                              shape: BoxShape.circle,
                              border: Border.all(color: t.avatarLine),
                            ),
                            child: Center(
                              child: Text(
                                c.session!.name.isEmpty
                                    ? '?'
                                    : c.session!.name.characters.first
                                          .toUpperCase(),
                                textScaler: TextScaler.noScaling,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: t.avatarInk,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                IconButton(
                  tooltip: c.preview ? 'Keluar pratinjau' : 'Keluar akun',
                  onPressed: _exit,
                  icon: const GrowviaIcon('logout', size: 20),
                ),
                const SizedBox(width: 6),
              ],
            ),
            body: SafeArea(
              top: false,
              child: Row(
                children: [
                  if (wide) ...[
                    NavigationRail(
                      selectedIndex: _tab,
                      labelType: NavigationRailLabelType.all,
                      onDestinationSelected: (value) =>
                          setState(() => _tab = value),
                      destinations: [
                        for (var i = 0; i < _labels.length; i++)
                          NavigationRailDestination(
                            icon: GrowviaIcon(_icons[i]),
                            selectedIcon: GrowviaIcon(
                              _icons[i],
                              color: t.navActive,
                            ),
                            label: Text(_labels[i]),
                          ),
                      ],
                    ),
                    const VerticalDivider(width: 1),
                  ],
                  Expanded(
                    child: Column(
                      children: [
                        ListenableBuilder(
                          listenable: c.updater,
                          builder: (context, _) => AppUpdateBanner(
                            updater: c.updater,
                            onOpenUpdate: () =>
                                showAppUpdateSheet(context, c.updater),
                          ),
                        ),
                        Expanded(
                          child: IndexedStack(index: _tab, children: pages),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            bottomNavigationBar: wide
                ? null
                : Builder(
                    builder: (context) {
                      final navScale =
                          MediaQuery.textScalerOf(context).scale(12) / 12;
                      return DecoratedBox(
                        decoration: BoxDecoration(
                          color: t.surface,
                          border: Border(top: BorderSide(color: t.line)),
                        ),
                        child: NavigationBar(
                          height: navScale <= 1.2
                              ? 74
                              : 74 + (navScale - 1) * 44,
                          selectedIndex: _tab,
                          onDestinationSelected: (value) =>
                              setState(() => _tab = value),
                          destinations: [
                            for (var i = 0; i < _labels.length; i++)
                              NavigationDestination(
                                icon: GrowviaIcon(
                                  _icons[i],
                                  color: t.secondary,
                                ),
                                selectedIcon: GrowviaIcon(
                                  _icons[i],
                                  color: t.navActive,
                                ),
                                label: _labels[i],
                              ),
                          ],
                        ),
                      );
                    },
                  ),
          );
        },
      ),
    );
  }
}

class _PreferencesPage extends StatelessWidget {
  const _PreferencesPage({required this.controller, required this.active});
  final AppController controller;
  final bool active;

  Future<void> _pushPage(BuildContext context, Widget page) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => page),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final session = c.session;

    return PageBody(
      children: [
        PageIntro(
          eyebrow: c.isAdmin
              ? 'Kelola / Pengaturan'
              : 'Panel petani / Pengaturan',
          title: session != null ? 'Atur-atur kebunmu.' : 'Preferensi aplikasi.',
          description: session != null
              ? 'Urus akun, koneksi, dan settingan tempat tumbuh langsung di sini.'
              : 'Atur koneksi server, tema tampilan, dan informasi versi aplikasi.',
        ),
        const SizedBox(height: 16),
        if (session == null) ...[
          const Notice(
            title: 'Mode pratinjau',
            message:
                'Profil, sesi perangkat, dan konfigurasi kebun tersedia setelah masuk dengan akun.',
          ),
          const SizedBox(height: 16),
        ] else ...[
          _AccountSummaryCard(
            name: session.name,
            email: session.email,
            isAdmin: c.isAdmin,
            onTap: () => _pushPage(context, AccountPage(controller: c)),
          ),
          const SizedBox(height: 14),
          GrowviaPanel(
            title: 'Akun & keamanan',
            subtitle: 'Identitas akun, kata sandi, dan sesi aktif.',
            padding: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SettingsNavRow(
                  number: '01',
                  icon: 'users',
                  tone: 'green',
                  title: 'Profil kamu',
                  subtitle: 'Nama tampilan dan alamat email akun',
                  onTap: () => _pushPage(context, AccountPage(controller: c)),
                ),
                _SettingsNavRow(
                  number: '02',
                  icon: 'shield',
                  tone: 'blue',
                  title: 'Kata sandi',
                  subtitle: 'Perbarui sandi akun secara berkala',
                  onTap: () => _pushPage(
                    context,
                    AccountPage(controller: c, focusPassword: true),
                  ),
                ),
                _SettingsNavRow(
                  number: '03',
                  icon: 'clock',
                  tone: 'neutral',
                  title: 'Sesi perangkat',
                  subtitle: 'Cek dan keluarkan perangkat yang terhubung',
                  isLast: !(c.isAdmin && !c.preview),
                  onTap: () => _pushPage(context, SessionsPage(controller: c)),
                ),
                if (c.isAdmin && !c.preview)
                  _SettingsNavRow(
                    number: '08',
                    icon: 'archive',
                    tone: 'neutral',
                    title: 'Backup database',
                    subtitle: 'Unduh cadangan SQL dan atur jadwal otomatis',
                    isLast: true,
                    onTap: () => _pushPage(context, BackupPage(controller: c)),
                  ),
              ],
            ),
          ),
          if (c.isAdmin && !c.preview) ...[
            const SizedBox(height: 14),
            SystemSettingsPage(
              controller: c,
              embedded: true,
              active: active,
            ),
          ],
          const SizedBox(height: 14),
          const _SecurityTipsCard(),
          const SizedBox(height: 20),
        ],
        SettingsPage(
          preferences: c.preferences,
          updater: c.updater,
          embedded: true,
        ),
      ],
    );
  }
}

class _AccountSummaryCard extends StatelessWidget {
  const _AccountSummaryCard({
    required this.name,
    required this.email,
    required this.isAdmin,
    required this.onTap,
  });

  final String name;
  final String email;
  final bool isAdmin;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = GrowviaTokens.of(context);
    final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
    final initial = name.isEmpty ? '?' : name.characters.first.toUpperCase();
    final roleBadge = GrowviaBadge(
      isAdmin ? 'Administrator' : 'Petani',
      tone: isAdmin ? 'green' : 'blue',
      dot: true,
    );

    return Material(
      color: t.surface,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: t.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: t.avatarSurface,
                      shape: BoxShape.circle,
                      border: Border.all(color: t.avatarLine, width: 1.5),
                    ),
                    child: Center(
                      child: Text(
                        initial,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: t.avatarInk,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Text(
                                'AKUN AKTIF',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.9,
                                  color: t.muted,
                                ),
                              ),
                            ),
                            if (scale <= 1.3) ...[
                              const SizedBox(width: 8),
                              roleBadge,
                            ],
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                            color: t.ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            GrowviaIcon('mail', size: 13, color: t.muted),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                email,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: t.secondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (scale > 1.3) ...[
                const SizedBox(height: 10),
                Align(alignment: Alignment.centerLeft, child: roleBadge),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsNavRow extends StatelessWidget {
  const _SettingsNavRow({
    required this.number,
    required this.icon,
    required this.tone,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.isLast = false,
  });

  final String number;
  final String icon;
  final String tone;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final t = GrowviaTokens.of(context);
    final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
    final numberChip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: t.soft,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: t.line),
      ),
      child: Text(
        number,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: t.muted,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 56),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                child: Row(
                  children: [
                    GrowviaIconTile(icon: icon, tone: tone, size: 36),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (scale > 1.35) ...[
                            numberChip,
                            const SizedBox(height: 6),
                          ],
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w600,
                              color: t.ink,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: t.secondary,
                              height: 1.35,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (scale <= 1.35) ...[
                      const SizedBox(width: 8),
                      numberChip,
                    ],
                    const SizedBox(width: 6),
                    GrowviaIcon('arrow', size: 15, color: t.muted),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (!isLast) Divider(height: 1, color: t.line),
      ],
    );
  }
}

class _SecurityTipsCard extends StatelessWidget {
  const _SecurityTipsCard();

  @override
  Widget build(BuildContext context) {
    final t = GrowviaTokens.of(context);
    const tips = <(String, String)>[
      ('shield', 'Pakai kata sandi unik yang tidak digunakan di layanan lain.'),
      (
        'clock',
        'Periksa daftar sesi secara berkala dan keluarkan perangkat tak dikenal.',
      ),
      ('mail', 'Email aktif dipakai untuk kirim tautan pemulihan kata sandi.'),
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: t.soft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: t.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GrowviaIcon('leaf', size: 16, color: t.green),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Jaga akunmu tetap aman',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: t.ink,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < tips.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: GrowviaIcon(tips[i].$1, size: 14, color: t.muted),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    tips[i].$2,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: t.secondary,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
