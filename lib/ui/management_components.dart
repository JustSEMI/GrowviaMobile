import 'package:flutter/material.dart';

import '../core/app_controller.dart';
import '../data/api_client.dart';
import '../ui/components.dart';
import '../ui/growvia_icon.dart';

/// Penjaga berbasis identitas: refresh token/profil tidak boleh menutup halaman aktif.
abstract class ProtectedManagementState<T extends StatefulWidget>
    extends State<T> {
  AppController get controller;
  bool get adminOnly => false;
  int? _identity;
  bool _invalidated = false;
  int generation = 0;
  bool busy = false;
  ManagementFailure? failure;
  String? receipt;
  final pageScroll = ScrollController();
  ManagementFailure? _shownFailure;
  String? _shownReceipt;

  void revealFeedback() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && pageScroll.hasClients) pageScroll.jumpTo(0);
    });
  }

  bool get authorized =>
      !_invalidated &&
      !controller.preview &&
      controller.session != null &&
      controller.session!.userId == _identity &&
      controller.session!.isActive &&
      (!adminOnly || controller.isAdmin);
  bool current(int ticket) => mounted && authorized && ticket == generation;

  @override
  void initState() {
    super.initState();
    _identity = controller.session?.userId;
    controller.addListener(_sessionChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && authorized) initializeProtected();
    });
  }

  void initializeProtected() {}
  void clearPrivateData() {}

  void _sessionChanged() {
    if (!mounted) return;
    if (_identity != null &&
        (controller.session?.userId != _identity ||
            controller.preview ||
            controller.session?.isActive != true ||
            (adminOnly && !controller.isAdmin))) {
      _invalidated = true;
      generation++;
      clearPrivateData();
      failure = null;
      receipt = null;
      busy = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
      });
    }
    setState(() {});
  }

  Future<bool> write(Future<void> Function() action, String success) async {
    if (!authorized || busy) return false;
    final ticket = generation;
    setState(() {
      busy = true;
      failure = null;
      receipt = null;
    });
    try {
      await action();
      if (!current(ticket)) return false;
      setState(() {
        receipt = success;
      });
      return true;
    } catch (error) {
      if (current(ticket)) {
        setState(() {
          failure = ManagementFailure.from(error);
        });
      }
      return false;
    } finally {
      if (current(ticket)) {
        setState(() {
          busy = false;
        });
      }
    }
  }

  Widget protectedPage(String title, List<Widget> Function() content) {
    if (!authorized) {
      return ManagementScaffold(
        title: title,
        children: [
          Notice(
            title: controller.preview
                ? 'Mode pratinjau'
                : controller.session == null || _invalidated
                ? 'Masuk diperlukan'
                : 'Akses administrator diperlukan',
            message: controller.preview
                ? 'Pengelolaan akun tidak tersedia dalam pratinjau. Tidak ada permintaan dikirim.'
                : 'Masuk dengan akun aktif yang memiliki izin untuk membuka halaman ini.',
            error: !controller.preview,
          ),
        ],
      );
    }
    if (failure != _shownFailure || receipt != _shownReceipt) {
      _shownFailure = failure;
      _shownReceipt = receipt;
      if (failure != null || receipt != null) revealFeedback();
    }
    return ManagementScaffold(
      title: title,
      controller: pageScroll,
      children: content(),
    );
  }

  List<Widget> get feedback => [
    if (failure != null) ManagementError(failure: failure!),
    if (receipt != null)
      Semantics(
        liveRegion: true,
        child: Notice(
          key: const Key('management-receipt'),
          title: 'Tersimpan',
          message: receipt!,
          success: true,
        ),
      ),
    if (busy)
      const LinearProgressIndicator(semanticsLabel: 'Menyimpan perubahan'),
  ];

  @override
  void dispose() {
    generation++;
    controller.removeListener(_sessionChanged);
    pageScroll.dispose();
    super.dispose();
  }
}

class ManagementFailure {
  const ManagementFailure(this.message, [this.fields = const {}]);
  final String message;
  final Map<String, List<String>> fields;
  factory ManagementFailure.from(Object error) => error is ApiException
      ? ManagementFailure(error.message, error.fieldErrors)
      : const ManagementFailure(
          'Permintaan belum berhasil. Periksa koneksi lalu coba lagi.',
        );
  String? field(String name) =>
      (fields[name] ?? fields['values.$name'])?.join('\n');
}

class ManagementError extends StatelessWidget {
  const ManagementError({required this.failure, this.retry, super.key});
  final ManagementFailure failure;
  final VoidCallback? retry;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Notice(
        key: const Key('management-errors'),
        title: 'Periksa kembali',
        error: true,
        message: [
          failure.message,
          ...failure.fields.values.expand((v) => v),
        ].join('\n'),
      ),
      if (retry != null)
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            key: const Key('management-retry'),
            onPressed: retry,
            icon: const GrowviaIcon('refresh'),
            label: const Text('Coba lagi'),
          ),
        ),
    ],
  );
}

class ManagementScaffold extends StatelessWidget {
  const ManagementScaffold({
    required this.title,
    required this.children,
    this.controller,
    super.key,
  });
  final String title;
  final List<Widget> children;
  final ScrollController? controller;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis),
      toolbarHeight: MediaQuery.textScalerOf(context).scale(20) > 30 ? 88 : 64,
    ),
    body: SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView.builder(
            controller: controller,
            key: const Key('management-scroll'),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            itemCount: children.length,
            itemBuilder: (_, index) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: children[index],
            ),
          ),
        ),
      ),
    ),
  );
}

class ManagementField extends StatefulWidget {
  const ManagementField({
    required this.id,
    required this.label,
    required this.controller,
    this.error,
    this.hint,
    this.secret = false,
    this.enabled = true,
    this.keyboard,
    this.autofill,
    this.onChanged,
    super.key,
  });
  final String id, label;
  final TextEditingController controller;
  final String? error, hint;
  final bool secret, enabled;
  final TextInputType? keyboard;
  final Iterable<String>? autofill;
  final ValueChanged<String>? onChanged;
  @override
  State<ManagementField> createState() => _ManagementFieldState();
}

class _ManagementFieldState extends State<ManagementField> {
  bool visible = false;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextField(
      key: Key(widget.id),
      controller: widget.controller,
      enabled: widget.enabled,
      obscureText: widget.secret && !visible,
      keyboardType: widget.keyboard,
      autofillHints: widget.autofill,
      enableSuggestions: !widget.secret,
      autocorrect: !widget.secret,
      onChanged: widget.onChanged,
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(
        label: Text(widget.label, maxLines: 1, overflow: TextOverflow.ellipsis),
        helperText: widget.hint,
        helperMaxLines: 5,
        errorText: widget.error,
        errorMaxLines: 8,
        constraints: const BoxConstraints(minHeight: 48),
        suffixIcon: widget.secret
            ? IconButton(
                constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
                tooltip: visible
                    ? 'Sembunyikan kata sandi'
                    : 'Tampilkan kata sandi',
                onPressed: () => setState(() {
                  visible = !visible;
                }),
                icon: Icon(
                  visible
                      ? Icons.visibility_rounded
                      : Icons.visibility_off_rounded,
                ),
              )
            : null,
      ),
    ),
  );
}

class ManagementSelector extends StatelessWidget {
  const ManagementSelector({
    required this.id,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.enabled = true,
    super.key,
  });
  final String id, label, value;
  final Map<String, String> options;
  final ValueChanged<String> onChanged;
  final bool enabled;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: OutlinedButton(
      key: Key(id),
      onPressed: !enabled
          ? null
          : () async {
              final selected = await showModalBottomSheet<String>(
                context: context,
                useSafeArea: true,
                isScrollControlled: true,
                backgroundColor: Theme.of(context).colorScheme.surface,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                ),
                builder: (context) => FractionallySizedBox(
                  heightFactor: .85,
                  child: SafeArea(
                    child: ListView(
                      padding: const EdgeInsets.only(bottom: 16),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Text(
                            label,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        ...options.entries.map(
                          (entry) => ListTile(
                            key: Key('$id-option-${entry.key}'),
                            minVerticalPadding: 16,
                            leading: GrowviaIcon(
                              entry.key == value ? 'check' : 'grid',
                            ),
                            title: Text(entry.value),
                            onTap: () => Navigator.pop(context, entry.key),
                          ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Batal'),
                        ),
                      ],
                    ),
                  ),
                ),
              );
              if (context.mounted && selected != null) onChanged(selected);
            },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Text('$label: ${options[value] ?? value}', softWrap: true),
            ),
            const SizedBox(width: 8),
            const GrowviaIcon('chevron-down'),
          ],
        ),
      ),
    ),
  );
}

Future<bool> confirmManagement(
  BuildContext context, {
  required String title,
  required String message,
  String confirm = 'Konfirmasi',
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: GrowviaIcon('shield', size: 32),
                ),
                const SizedBox(height: 16),
                Text(title, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                Text(message),
                const SizedBox(height: 24),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Batal'),
                    ),
                    FilledButton(
                      key: const Key('management-confirm'),
                      onPressed: () => Navigator.pop(context, true),
                      child: Text(confirm),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ) ??
    false;

class ManagementPagination extends StatelessWidget {
  const ManagementPagination({
    required this.page,
    required this.lastPage,
    required this.total,
    required this.onPage,
    this.busy = false,
    super.key,
  });
  final int page, lastPage, total;
  final ValueChanged<int> onPage;
  final bool busy;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text('Halaman $page dari $lastPage · $total hasil'),
      const SizedBox(height: 8),
      Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          OutlinedButton(
            key: const Key('page-previous'),
            onPressed: !busy && page > 1 ? () => onPage(page - 1) : null,
            child: const Text('Sebelumnya'),
          ),
          OutlinedButton(
            key: const Key('page-next'),
            onPressed: !busy && page < lastPage ? () => onPage(page + 1) : null,
            child: const Text('Berikutnya'),
          ),
        ],
      ),
    ],
  );
}

String utcLabel(DateTime? value) {
  if (value == null) return 'Tidak tersedia (UTC)';
  final date = value.toUtc();
  String pad(int v) => v.toString().padLeft(2, '0');
  return '${date.year}-${pad(date.month)}-${pad(date.day)} ${pad(date.hour)}:${pad(date.minute)} UTC';
}

bool validEmail(String value) =>
    !RegExp(r'[\x00-\x20\x7f]').hasMatch(value) &&
    value.length <= 254 &&
    RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value);
Map<String, List<String>> requiredFields(Map<String, String> fields) => {
  for (final field in fields.entries)
    if (field.value.trim().isEmpty) field.key: ['Kolom ini wajib diisi.'],
};
Widget managementHeading(BuildContext context, String title) => Padding(
  padding: const EdgeInsets.only(bottom: 16),
  child: Text(title, style: Theme.of(context).textTheme.titleLarge),
);
