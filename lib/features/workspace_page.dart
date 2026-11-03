import 'package:flutter/material.dart';

import '../core/app_controller.dart';
import '../core/tokens.dart';
import '../ui/components.dart';
import '../ui/dashboard_components.dart';
import '../ui/growvia_components.dart';
import '../ui/growvia_icon.dart';
import 'account_page.dart';
import 'activity_page.dart';
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
  static const _icons = ['grid', 'clock', 'book', 'settings'];

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
    }) => ListTile(
      leading: GrowviaIcon(
        icon,
        size: 18,
        color: selected ? t.navActive : t.secondary,
      ),
      title: Text(title),
      selected: selected,
      onTap: () {
        Navigator.pop(context);
        action();
      },
    );

    Widget label(String text, {bool spaced = false}) => Padding(
      padding: EdgeInsets.fromLTRB(24, spaced ? 26 : 8, 24, 8),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          letterSpacing: 1.2,
          color: t.muted,
        ),
      ),
    );

    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 16),
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Brand(),
            ),
            // Padanan `.workspace-label` di sidebar web.
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: t.soft,
                  border: Border.all(color: t.line),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: t.paleGreen,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Center(
                        child: GrowviaIcon('leaf', size: 18, color: t.green),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Rumah kaca',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: t.ink,
                            ),
                          ),
                          Text(
                            'Ruang kerja Growvia',
                            style: TextStyle(fontSize: 12, color: t.secondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            label('Ruang kerja'),
            link(
              'Ringkasan',
              'grid',
              () => setState(() => _tab = 0),
              selected: _tab == 0,
            ),
            link(
              'Iklim rumah kaca',
              'sun',
              () => _open(NodeDetailPage(controller: c, node: 'node1')),
            ),
            link(
              'Tanah & air',
              'drop',
              () => _open(NodeDetailPage(controller: c, node: 'node2')),
            ),
            label('Kebun', spaced: true),
            link(
              'Riwayat sensor',
              'clock',
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
                'Pengaturan',
                'settings',
                () => _open(SystemSettingsPage(controller: c)),
              ),
            ],
            label('Akun', spaced: true),
            if (c.session != null) ...[
              link(
                'Profil & keamanan',
                'shield',
                () => _open(AccountPage(controller: c)),
              ),
              // Web menaruh "Sesi perangkat" di sidebar, bukan hanya di profil.
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
            // Padanan `.sidebar-note` di web.
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GrowviaIcon('connection', size: 18, color: t.green),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ruang untuk bertumbuh.',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: t.green,
                          ),
                        ),
                        Text(
                          'Data kebun, di satu tempat.',
                          style: TextStyle(fontSize: 12, color: t.secondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 32),
            if (c.session != null) _accountTile(c),
            link(
              c.preview ? 'Keluar pratinjau' : 'Keluar akun',
              'logout',
              _exit,
            ),
          ],
        ),
      ),
    );
  }

  /// Padanan `.sidebar-account`: avatar, nama, peran.
  Widget _accountTile(AppController c) {
    final t = GrowviaTokens.of(context);
    final name = c.session!.name;
    return InkWell(
      onTap: () => _open(AccountPage(controller: c)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: t.avatarSurface,
                shape: BoxShape.circle,
                border: Border.all(color: t.avatarLine),
              ),
              child: Center(
                child: Text(
                  name.isEmpty ? '?' : name.characters.first.toUpperCase(),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
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
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: t.ink,
                    ),
                  ),
                  Text(
                    c.isAdmin ? 'Administrator' : 'Petani',
                    style: TextStyle(fontSize: 12, color: t.secondary),
                  ),
                ],
              ),
            ),
            GrowviaIcon('settings', size: 16, color: t.secondary),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => PopScope(
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
          _PreferencesPage(controller: c),
        ];
        return Scaffold(
          drawer: _drawer(),
          appBar: AppBar(
            title: const Brand(),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(
                height: 1,
                color: GrowviaTokens.of(context).line,
              ),
            ),
            actions: [
              if (c.session != null)
                IconButton(
                  tooltip: 'Profil & keamanan',
                  onPressed: () => _open(AccountPage(controller: c)),
                  icon: const GrowviaIcon('shield', size: 22),
                ),
              IconButton(
                tooltip: c.preview ? 'Keluar pratinjau' : 'Keluar akun',
                onPressed: _exit,
                icon: const GrowviaIcon('logout', size: 22),
              ),
              const SizedBox(width: 4),
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
                          label: Text(_labels[i]),
                        ),
                    ],
                  ),
                  const VerticalDivider(width: 1),
                ],
                Expanded(
                  child: IndexedStack(index: _tab, children: pages),
                ),
              ],
            ),
          ),
          bottomNavigationBar: wide
              ? null
              : Builder(
                  builder: (context) {
                    // Label destinasi ikut membesar bersama text scale, jadi
                    // tinggi tetap 76px akan memotongnya. Tinggi mengikuti
                    // skala agar tidak overflow di pengaturan aksesibilitas.
                    final navScale =
                        MediaQuery.textScalerOf(context).scale(12) / 12;
                    return NavigationBar(
                      height: navScale <= 1.2 ? 76 : 76 + (navScale - 1) * 44,
                      selectedIndex: _tab,
                      onDestinationSelected: (value) =>
                          setState(() => _tab = value),
                      destinations: [
                        for (var i = 0; i < _labels.length; i++)
                          NavigationDestination(
                            icon: GrowviaIcon(_icons[i]),
                            label: _labels[i],
                          ),
                      ],
                    );
                  },
                ),
        );
      },
    ),
  );
}

class _PreferencesPage extends StatelessWidget {
  const _PreferencesPage({required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    // Satu area gulir untuk tile akun + pengaturan.
    //
    // Sebelumnya tile akun berdiri sendiri di atas `Expanded`, sehingga pada
    // text scale besar atau layar pendek (landscape) tingginya melebihi ruang
    // yang tersisa dan RenderFlex melaporkan overflow.
    return PageBody(
      children: [
        if (controller.session != null) ...[
          GrowviaLinkTile(
            title: 'Profil & keamanan',
            subtitle:
                'Kelola akun dan sesi, terpisah dari preferensi perangkat.',
            icon: 'shield',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => AccountPage(controller: controller),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
        SettingsPage(preferences: controller.preferences, embedded: true),
      ],
    );
  }
}
