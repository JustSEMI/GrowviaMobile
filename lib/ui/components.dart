import 'package:flutter/material.dart';

import '../core/tokens.dart';
import 'growvia_components.dart';
import 'growvia_icon.dart';

class Brand extends StatelessWidget {
  const Brand({super.key});

  @override
  Widget build(BuildContext context) {
    final t = GrowviaTokens.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Padanan `.brand-mark`: kotak hijau tua dengan ikon daun.
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: t.brandSurface,
            borderRadius: BorderRadius.circular(10),
          ),
          child: GrowviaIcon('leaf', color: t.brandInk, size: 24),
        ),
        const SizedBox(width: 11),
        Flexible(
          child: Text(
            'growvia',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textScaler: TextScaler.noScaling,
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontSize: 25, letterSpacing: -1.75),
          ),
        ),
      ],
    );
  }
}

class Notice extends StatelessWidget {
  const Notice({
    required this.title,
    required this.message,
    this.error = false,
    this.success = false,
    super.key,
  });
  final String title;
  final String message;
  final bool error;
  final bool success;

  @override
  Widget build(BuildContext context) {
    final t = GrowviaTokens.of(context);
    // Token yang sama dengan `.alert--success` / `.alert--error` di web.
    final background = error
        ? t.paleRed
        : success
        ? t.paleGreen
        : t.noticeSurface;
    final border = error
        ? t.dangerLine
        : success
        ? t.successLine
        : t.noticeLine;
    final ink = error
        ? t.red
        : success
        ? t.green
        : t.noticeInk;
    return Semantics(
      liveRegion: error || success,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: background,
          border: Border.all(color: border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GrowviaIcon(
              error
                  ? 'close'
                  : success
                  ? 'check'
                  : 'info',
              size: 22,
              color: ink,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(fontWeight: FontWeight.w600, color: ink),
                  ),
                  const SizedBox(height: 4),
                  Text(message, style: TextStyle(color: ink, height: 1.45)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PageIntro extends StatelessWidget {
  const PageIntro({
    required this.eyebrow,
    required this.title,
    required this.description,
    super.key,
  });
  final String eyebrow;
  final String title;
  final String description;
  @override
  Widget build(BuildContext context) {
    final t = GrowviaTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: t.paleGreen,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            eyebrow.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.3,
              color: t.green,
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          title,
          style: Theme.of(context).textTheme.headlineMedium
              ?.copyWith(fontSize: 36, height: 1.06, letterSpacing: -0.9),
        ),
        const SizedBox(height: 10),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Text(
            description,
            style: TextStyle(color: t.secondary, height: 1.55),
          ),
        ),
      ],
    );
  }
}

/// Nama pendek untuk [GrowviaPanel] agar pemanggil lama tidak berubah.
///
/// Implementasinya sengaja hanya satu supaya panel web dan mobile tidak
/// menyimpang; jangan menambah dekorasi baru di sini.
class Panel extends StatelessWidget {
  const Panel({required this.child, this.padding = 20, super.key});
  final Widget child;
  final double padding;
  @override
  Widget build(BuildContext context) =>
      GrowviaPanel(padding: padding, child: child);
}

class PageBody extends StatelessWidget {
  const PageBody({required this.children, super.key});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    physics: const AlwaysScrollableScrollPhysics(),
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
    child: Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    ),
  );
}
