import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_controller.dart';
import '../data/workspace_models.dart';
import '../ui/components.dart';
import '../ui/growvia_icon.dart';
import '../ui/management_components.dart';

class UsersPage extends StatefulWidget {
  const UsersPage({required this.controller, super.key});
  final AppController controller;
  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends ProtectedManagementState<UsersPage> {
  @override
  AppController get controller => widget.controller;
  @override
  bool get adminOnly => true;
  final q = TextEditingController(),
      name = TextEditingController(),
      email = TextEditingController(),
      password = TextEditingController(),
      adminPassword = TextEditingController();
  String role = '', status = '', sort = 'newest', editRole = 'user';
  String appliedQ = '',
      appliedRole = '',
      appliedStatus = '',
      appliedSort = 'newest';
  ApiPage<UserAccount>? result;
  UserAccount? editing;
  bool editorOpen = false, loading = false;
  int readGeneration = 0;
  ManagementFailure? loadFailure;
  @override
  void initializeProtected() {
    load();
  }

  @override
  void clearPrivateData() {
    readGeneration++;
    result = null;
    editing = null;
    editorOpen = false;
    for (final field in [q, name, email, password, adminPassword]) {
      field.clear();
    }
    loadFailure = null;
  }

  Future<void> load([int page = 1]) async {
    if (!authorized) return;
    final ticket = generation, read = ++readGeneration;
    setState(() {
      loading = true;
      loadFailure = null;
      result = null;
    });
    try {
      final next = await controller.loadUsers(
        q: appliedQ,
        role: appliedRole,
        status: appliedStatus,
        sort: appliedSort,
        page: page,
      );
      if (current(ticket) && read == readGeneration) {
        setState(() {
          result = next;
        });
      }
    } catch (error) {
      if (current(ticket) && read == readGeneration) {
        setState(() {
          loadFailure = ManagementFailure.from(error);
        });
      }
    } finally {
      if (current(ticket) && read == readGeneration) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  void apply() {
    appliedQ = q.text.trim();
    appliedRole = role;
    appliedStatus = status;
    appliedSort = sort;
    load();
  }

  void edit([UserAccount? user]) {
    revealFeedback();
    setState(() {
      editing = user;
      editorOpen = true;
      name.text = user?.name ?? '';
      email.text = user?.email ?? '';
      editRole = user?.role ?? 'user';
      password.clear();
      adminPassword.clear();
      failure = null;
      receipt = null;
    });
  }

  Future<void> save() async {
    final errors = requiredFields({
      'name': name.text,
      'email': email.text,
      if (editing == null) 'password': password.text,
    });
    if (email.text.isNotEmpty && !validEmail(email.text.trim())) {
      errors['email'] = ['Masukkan alamat email yang valid.'];
    }
    if (password.text.isNotEmpty && password.text.length < 8) {
      errors['password'] = ['Gunakan setidaknya 8 karakter.'];
    }
    final sensitive =
        editing != null &&
        (editing!.email != email.text.trim() || password.text.isNotEmpty);
    if (sensitive && adminPassword.text.isEmpty) {
      errors['admin_password'] = [
        'Kata sandi administrator saat ini wajib untuk perubahan email atau kata sandi.',
      ];
    }
    if (errors.isNotEmpty) {
      setState(() {
        receipt = null;
        failure = ManagementFailure('Perubahan belum dikirim.', errors);
      });
      return;
    }
    final success = await write(
      () => controller.saveUser(
        id: editing?.id,
        name: name.text.trim(),
        email: email.text.trim(),
        role: editing?.id == controller.session?.userId ? 'admin' : editRole,
        password: password.text.isEmpty ? null : password.text,
        adminPassword: sensitive ? adminPassword.text : null,
      ),
      editing == null
          ? 'Pengguna baru berhasil ditambahkan.'
          : 'Perubahan pengguna berhasil disimpan.',
    );
    if (success && mounted) {
      TextInput.finishAutofillContext(shouldSave: false);
      setState(() {
        editorOpen = false;
        editing = null;
        name.clear();
        email.clear();
        password.clear();
        adminPassword.clear();
      });
      await load();
    }
  }

  Future<void> changeStatus(UserAccount user) async {
    if (user.id == controller.session?.userId) return;
    final confirmed = await confirmManagement(
      context,
      title: user.isActive ? 'Nonaktifkan pengguna?' : 'Aktifkan pengguna?',
      message:
          '${user.name} (${user.email}). ${user.isActive ? 'Akses akun akan dicabut.' : 'Akun dapat masuk kembali.'}',
      confirm: user.isActive ? 'Nonaktifkan' : 'Aktifkan',
    );
    if (!mounted || !authorized || !confirmed) return;
    if (await write(
      () => controller.setUserActive(user.id, !user.isActive),
      'Status pengguna berhasil diperbarui.',
    )) {
      await load();
    }
  }

  Future<void> remove(UserAccount user) async {
    if (user.id == controller.session?.userId) return;
    final confirmed = await confirmManagement(
      context,
      title: 'Hapus pengguna?',
      message:
          'Hapus akun ${user.name} (${user.email}) secara permanen. Tindakan ini tidak dapat dibatalkan.',
      confirm: 'Hapus pengguna',
    );
    if (!mounted || !authorized || !confirmed) return;
    if (await write(
      () => controller.deleteUser(user.id),
      'Pengguna berhasil dihapus.',
    )) {
      await load();
    }
  }

  Widget editor() => Panel(
    child: AutofillGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          managementHeading(
            context,
            editing == null ? 'Tambah pengguna' : 'Edit pengguna',
          ),
          ManagementField(
            id: 'user-name',
            label: 'Nama',
            controller: name,
            error: failure?.field('name'),
            enabled: !busy,
            autofill: const [AutofillHints.name],
          ),
          ManagementField(
            id: 'user-email',
            label: 'Email',
            controller: email,
            error: failure?.field('email'),
            enabled: !busy,
            keyboard: TextInputType.emailAddress,
            autofill: const [AutofillHints.email],
          ),
          if (editing?.id != controller.session?.userId)
            ManagementSelector(
              id: 'user-role',
              label: 'Hak akses',
              value: editRole,
              options: const {'user': 'Petani', 'admin': 'Administrator'},
              enabled: !busy,
              onChanged: (v) => setState(() {
                editRole = v;
              }),
            )
          else
            const Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: Text(
                'Akun Anda · Administrator. Peran sendiri tidak dapat diturunkan.',
              ),
            ),
          ManagementField(
            id: 'user-password',
            label: editing == null
                ? 'Kata sandi'
                : 'Kata sandi baru (opsional)',
            controller: password,
            secret: true,
            enabled: !busy,
            error: failure?.field('password'),
            autofill: const [AutofillHints.newPassword],
            hint: 'Minimal 8 karakter. Jangan bagikan kata sandi di catatan aktivitas.',
          ),
          if (editing != null)
            ManagementField(
              id: 'user-admin-password',
              label: 'Kata sandi administrator',
              controller: adminPassword,
              secret: true,
              enabled: !busy,
              error: failure?.field('admin_password'),
              autofill: const [AutofillHints.password],
              hint: 'Kata sandi akun Anda saat ini; wajib jika email atau kata sandi pengguna diubah.',
            ),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton(
                key: const Key('user-save'),
                onPressed: busy ? null : save,
                child: Text(busy ? 'Menyimpan…' : 'Simpan pengguna'),
              ),
              OutlinedButton(
                onPressed: busy
                    ? null
                    : () => setState(() {
                        editorOpen = false;
                        editing = null;
                        password.clear();
                        adminPassword.clear();
                        name.clear();
                        email.clear();
                        failure = null;
                      }),
                child: const Text('Batal'),
              ),
            ],
          ),
        ],
      ),
    ),
  );
  Widget userCard(UserAccount user) {
    final self = user.id == controller.session?.userId;
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${user.name}${self ? ' · Anda' : ''}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(user.email),
          const SizedBox(height: 8),
          Text(
            '${user.isAdmin ? 'Administrator' : 'Petani'} · ${user.isActive ? 'Aktif' : 'Nonaktif'}',
          ),
          if (user.createdAt != null)
            Text('Dibuat ${utcLabel(user.createdAt)}'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                key: Key('user-edit-${user.id}'),
                onPressed: busy ? null : () => edit(user),
                child: const Text('Edit'),
              ),
              if (!self) ...[
                TextButton(
                  key: Key('user-status-${user.id}'),
                  onPressed: busy ? null : () => changeStatus(user),
                  child: Text(user.isActive ? 'Nonaktifkan' : 'Aktifkan'),
                ),
                TextButton(
                  key: Key('user-delete-${user.id}'),
                  onPressed: busy ? null : () => remove(user),
                  child: Text(
                    'Hapus',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => protectedPage(
    'Pengguna',
    () => [
      const PageIntro(
        eyebrow: 'Administrasi',
        title: 'Kelola akses',
        description:
            'Cari pengguna dan kelola peran akun Growvia yang sudah ada.',
      ),
      ...feedback,
      if (editorOpen) editor(),
      if (!editorOpen)
        FilledButton.icon(
          key: const Key('user-add'),
          onPressed: busy ? null : () => edit(),
          icon: const GrowviaIcon('plus'),
          label: const Text('Tambah pengguna'),
        ),
      Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ManagementField(
              id: 'users-q',
              label: 'Cari nama atau email',
              controller: q,
            ),
            ManagementSelector(
              id: 'users-role',
              label: 'Hak akses',
              value: role,
              options: const {
                '': 'Semua hak akses',
                'admin': 'Administrator',
                'user': 'Petani',
              },
              onChanged: (v) => setState(() {
                role = v;
              }),
            ),
            ManagementSelector(
              id: 'users-status',
              label: 'Status',
              value: status,
              options: const {
                '': 'Semua status',
                'active': 'Aktif',
                'inactive': 'Nonaktif',
              },
              onChanged: (v) => setState(() {
                status = v;
              }),
            ),
            ManagementSelector(
              id: 'users-sort',
              label: 'Urutan',
              value: sort,
              options: const {
                'newest': 'Terbaru',
                'oldest': 'Terlama',
                'name_asc': 'Nama A–Z',
                'name_desc': 'Nama Z–A',
              },
              onChanged: (v) => setState(() {
                sort = v;
              }),
            ),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton(
                  key: const Key('users-apply'),
                  onPressed: loading || busy ? null : apply,
                  child: const Text('Terapkan filter'),
                ),
                TextButton(
                  onPressed: loading || busy
                      ? null
                      : () {
                          setState(() {
                            q.clear();
                            role = '';
                            status = '';
                            sort = 'newest';
                          });
                          apply();
                        },
                  child: const Text('Reset filter'),
                ),
              ],
            ),
          ],
        ),
      ),
      if (loading)
        const LinearProgressIndicator(semanticsLabel: 'Memuat pengguna'),
      if (loadFailure != null)
        ManagementError(failure: loadFailure!, retry: () => load()),
      if (result != null) ...[
        if (result!.data.isEmpty)
          const Notice(
            title: 'Tidak ada pengguna',
            message: 'Tidak ada hasil untuk filter ini. Ubah pencarian atau reset filter.',
          ),
        ManagementPagination(
          page: result!.currentPage,
          lastPage: result!.lastPage,
          total: result!.total,
          onPage: load,
          busy: loading || busy,
        ),
        ...result!.data.map(userCard),
        if (result!.data.isNotEmpty)
          ManagementPagination(
            page: result!.currentPage,
            lastPage: result!.lastPage,
            total: result!.total,
            onPage: load,
            busy: loading || busy,
          ),
      ],
    ],
  );
  @override
  void dispose() {
    for (final field in [q, name, email, password, adminPassword]) {
      field.dispose();
    }
    super.dispose();
  }
}
