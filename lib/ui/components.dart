import 'package:flutter/material.dart';

import '../core/tokens.dart';
import 'growvia_components.dart';
import 'growvia_icon.dart';

class Brand extends StatelessWidget {
  const Brand({this.compact = false, super.key});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final t = GrowviaTokens.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: compact ? 32 : 36,
          height: compact ? 32 : 36,
          decoration: BoxDecoration(
            color: t.brandSurface,
            borderRadius: BorderRadius.circular(compact ? 9 : 10),
          ),
          child: Center(
            child: GrowviaIcon(
              'leaf',
              color: t.brandInk,
              size: compact ? 18 : 20,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(text: 'growvia'),
                    TextSpan(text: '.', style: TextStyle(color: t.green)),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textScaler: TextScaler.noScaling,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontSize: compact ? 20 : 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -1.1,
                  height: 1.0,
                ),
              ),
              if (!compact) ...[
                const SizedBox(height: 3),
                Text(
                  'RUANG KERJA KEBUN',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textScaler: TextScaler.noScaling,
                  style: TextStyle(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                    color: t.muted,
                  ),
                ),
              ],
            ],
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
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 14,
              height: 2,
              decoration: BoxDecoration(
                color: t.green,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                eyebrow.toUpperCase(),
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.15,
                  color: t.green,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontSize: 23,
            fontWeight: FontWeight.w700,
            height: 1.18,
            letterSpacing: -0.6,
            color: t.ink,
          ),
        ),
        const SizedBox(height: 6),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Text(
            description,
            style: TextStyle(
              fontSize: 13.5,
              color: t.secondary,
              height: 1.48,
            ),
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
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
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
