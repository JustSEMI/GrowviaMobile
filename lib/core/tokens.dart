import 'package:flutter/material.dart';

/// Token warna Growvia, cerminan `:root` di `resources/css/app.css`.
///
/// Web memakai `light-dark(a, b)` untuk setiap token. Di sini token yang sama
/// dipecah menjadi [GrowviaTokens.light] dan [GrowviaTokens.dark] dengan nama
/// identik, supaya penyesuaian web bisa dipindahkan ke mobile satu per satu
/// tanpa menebak warna.
///
/// Nilai `0xAARRGGBB` mengikuti urutan `#RRGGBB` pada CSS.
@immutable
class GrowviaTokens extends ThemeExtension<GrowviaTokens> {
  const GrowviaTokens({
    required this.canvas,
    required this.surface,
    required this.soft,
    required this.ink,
    required this.secondary,
    required this.muted,
    required this.line,
    required this.green,
    required this.paleGreen,
    required this.blue,
    required this.paleBlue,
    required this.amber,
    required this.paleAmber,
    required this.red,
    required this.paleRed,
    required this.action,
    required this.actionHover,
    required this.onAction,
    required this.brandSurface,
    required this.brandInk,
    required this.selection,
    required this.navActive,
    required this.avatarLine,
    required this.avatarSurface,
    required this.avatarInk,
    required this.breadcrumb,
    required this.controlLine,
    required this.controlHover,
    required this.controlBorder,
    required this.fieldSurface,
    required this.placeholder,
    required this.dangerLine,
    required this.dangerHover,
    required this.disabled,
    required this.neutral,
    required this.noticeLine,
    required this.noticeSurface,
    required this.noticeInk,
    required this.chartGrid,
    required this.legend,
    required this.pumpLine,
    required this.pumpSurface,
    required this.pumpInk,
    required this.pumpOutline,
    required this.rowHover,
    required this.emptyIcon,
    required this.successLine,
    required this.illustrationInk,
    required this.illustrationFill,
    required this.storySurface,
    required this.errorCode,
    required this.scrim,
  });

  // --- Dasar ---
  final Color canvas;
  final Color surface;
  final Color soft;
  final Color ink;
  final Color secondary;
  final Color muted;
  final Color line;

  // --- Aksen ---
  final Color green;
  final Color paleGreen;
  final Color blue;
  final Color paleBlue;
  final Color amber;
  final Color paleAmber;
  final Color red;
  final Color paleRed;

  // --- Aksi ---
  final Color action;
  final Color actionHover;
  final Color onAction;

  // --- Merek & navigasi ---
  final Color brandSurface;
  final Color brandInk;
  final Color selection;
  final Color navActive;

  // --- Avatar ---
  final Color avatarLine;
  final Color avatarSurface;
  final Color avatarInk;

  // --- Kontrol & formulir ---
  final Color breadcrumb;
  final Color controlLine;
  final Color controlHover;
  final Color controlBorder;
  final Color fieldSurface;
  final Color placeholder;

  // --- Bahaya & nonaktif ---
  final Color dangerLine;
  final Color dangerHover;
  final Color disabled;
  final Color neutral;

  // --- Catatan / notice ---
  final Color noticeLine;
  final Color noticeSurface;
  final Color noticeInk;

  // --- Grafik ---
  final Color chartGrid;
  final Color legend;

  // --- Pompa ---
  final Color pumpLine;
  final Color pumpSurface;
  final Color pumpInk;
  final Color pumpOutline;

  // --- Tabel & keadaan kosong ---
  final Color rowHover;
  final Color emptyIcon;
  final Color successLine;

  // --- Ilustrasi & cerita ---
  final Color illustrationInk;
  final Color illustrationFill;
  final Color storySurface;
  final Color errorCode;

  // --- Lapisan ---
  final Color scrim;

  /// Nilai `light-dark(a, b)` sisi terang dari `resources/css/app.css`.
  static const GrowviaTokens light = GrowviaTokens(
    canvas: Color(0xfff7f6f3),
    surface: Color(0xffffffff),
    soft: Color(0xfffbfbfa),
    ink: Color(0xff202723),
    secondary: Color(0xff626a64),
    muted: Color(0xff737773),
    line: Color(0xffeaeaea),
    green: Color(0xff346538),
    paleGreen: Color(0xffedf3ec),
    blue: Color(0xff1f6c9f),
    paleBlue: Color(0xffe1f3fe),
    amber: Color(0xff785411),
    paleAmber: Color(0xfffbf3db),
    red: Color(0xff9f2f2d),
    paleRed: Color(0xfffdebec),
    action: Color(0xff111111),
    actionHover: Color(0xff333333),
    onAction: Color(0xffffffff),
    brandSurface: Color(0xff263c2e),
    brandInk: Color(0xffedf3ec),
    selection: Color(0xffdce8d8),
    navActive: Color(0xff24492c),
    avatarLine: Color(0xffdfe5dc),
    avatarSurface: Color(0xffedf0e7),
    avatarInk: Color(0xff374736),
    breadcrumb: Color(0xffb0b5ad),
    controlLine: Color(0xffd8ddd6),
    controlHover: Color(0xff9da798),
    controlBorder: Color(0xff8b9585),
    fieldSurface: Color(0xffffffff),
    placeholder: Color(0xff697362),
    dangerLine: Color(0xffebc9ca),
    dangerHover: Color(0xfff9dfe0),
    disabled: Color(0xffecefe9),
    neutral: Color(0xfff0f1ed),
    noticeLine: Color(0xffe3e7dd),
    noticeSurface: Color(0xffeff2e9),
    noticeInk: Color(0xff485541),
    chartGrid: Color(0xffeceee8),
    legend: Color(0xff6c8b60),
    pumpLine: Color(0xffe2e7dd),
    pumpSurface: Color(0xfff8faf5),
    pumpInk: Color(0xff7c8976),
    pumpOutline: Color(0xfffbfcf9),
    rowHover: Color(0xfffcfdfb),
    emptyIcon: Color(0xff788775),
    successLine: Color(0xffdce6d9),
    illustrationInk: Color(0xff64755f),
    illustrationFill: Color(0xffe0e8d6),
    storySurface: Color(0xffeff1e9),
    errorCode: Color(0xff718267),
    scrim: Color(0x6b141c16),
  );

  /// Nilai `light-dark(a, b)` sisi gelap dari `resources/css/app.css`.
  static const GrowviaTokens dark = GrowviaTokens(
    canvas: Color(0xff171b18),
    surface: Color(0xff202622),
    soft: Color(0xff252c27),
    ink: Color(0xffedf1e9),
    secondary: Color(0xffb5beb4),
    muted: Color(0xffa3aea1),
    line: Color(0xff3a443c),
    green: Color(0xffacd0a0),
    paleGreen: Color(0xff2a392e),
    blue: Color(0xffa7cde5),
    paleBlue: Color(0xff253744),
    amber: Color(0xffe2c78f),
    paleAmber: Color(0xff3d3524),
    red: Color(0xffefb5b8),
    paleRed: Color(0xff432d31),
    action: Color(0xffe0e8d8),
    actionHover: Color(0xfff0f4eb),
    onAction: Color(0xff1b241d),
    brandSurface: Color(0xff324836),
    brandInk: Color(0xffd7e8cd),
    selection: Color(0xff3d563e),
    navActive: Color(0xffc9e6bb),
    avatarLine: Color(0xff465846),
    avatarSurface: Color(0xff2c382e),
    avatarInk: Color(0xffcee0c5),
    breadcrumb: Color(0xff788775),
    controlLine: Color(0xff5c6a5e),
    controlHover: Color(0xff92a58e),
    controlBorder: Color(0xff788775),
    fieldSurface: Color(0xff1c211d),
    placeholder: Color(0xffa3aea1),
    dangerLine: Color(0xff805457),
    dangerHover: Color(0xff503338),
    disabled: Color(0xff2c342e),
    neutral: Color(0xff2b332d),
    noticeLine: Color(0xff435440),
    noticeSurface: Color(0xff283327),
    noticeInk: Color(0xffc2d2b7),
    chartGrid: Color(0xff364139),
    legend: Color(0xff9ebb8e),
    pumpLine: Color(0xff3f4d40),
    pumpSurface: Color(0xff242e25),
    pumpInk: Color(0xffb0bea6),
    pumpOutline: Color(0xff1c231e),
    rowHover: Color(0xff283129),
    emptyIcon: Color(0xffa3b39a),
    successLine: Color(0xff52704d),
    illustrationInk: Color(0xff9fb493),
    illustrationFill: Color(0xff31432d),
    storySurface: Color(0xff222c22),
    errorCode: Color(0xffa5bf98),
    scrim: Color(0xb8070b08),
  );

  /// Token dari [context]; jatuh ke sisi terang bila ekstensi belum dipasang.
  static GrowviaTokens of(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<GrowviaTokens>() ??
        (theme.brightness == Brightness.dark ? dark : light);
  }

  /// Warna pasangan untuk `badge--*` dan `icon-tile--*` di web.
  ///
  /// [tone] mengikuti nama varian CSS: `green`, `blue`, `amber`, `red`,
  /// `neutral`.
  ({Color foreground, Color background}) tone(String tone) => switch (tone) {
    'blue' => (foreground: blue, background: paleBlue),
    'amber' => (foreground: amber, background: paleAmber),
    'red' => (foreground: red, background: paleRed),
    'neutral' => (foreground: secondary, background: neutral),
    _ => (foreground: green, background: paleGreen),
  };

  @override
  GrowviaTokens copyWith({
    Color? canvas,
    Color? surface,
    Color? soft,
    Color? ink,
    Color? secondary,
    Color? muted,
    Color? line,
    Color? green,
    Color? paleGreen,
    Color? blue,
    Color? paleBlue,
    Color? amber,
    Color? paleAmber,
    Color? red,
    Color? paleRed,
    Color? action,
    Color? actionHover,
    Color? onAction,
    Color? brandSurface,
    Color? brandInk,
    Color? selection,
    Color? navActive,
    Color? avatarLine,
    Color? avatarSurface,
    Color? avatarInk,
    Color? breadcrumb,
    Color? controlLine,
    Color? controlHover,
    Color? controlBorder,
    Color? fieldSurface,
    Color? placeholder,
    Color? dangerLine,
    Color? dangerHover,
    Color? disabled,
    Color? neutral,
    Color? noticeLine,
    Color? noticeSurface,
    Color? noticeInk,
    Color? chartGrid,
    Color? legend,
    Color? pumpLine,
    Color? pumpSurface,
    Color? pumpInk,
    Color? pumpOutline,
    Color? rowHover,
    Color? emptyIcon,
    Color? successLine,
    Color? illustrationInk,
    Color? illustrationFill,
    Color? storySurface,
    Color? errorCode,
    Color? scrim,
  }) => GrowviaTokens(
    canvas: canvas ?? this.canvas,
    surface: surface ?? this.surface,
    soft: soft ?? this.soft,
    ink: ink ?? this.ink,
    secondary: secondary ?? this.secondary,
    muted: muted ?? this.muted,
    line: line ?? this.line,
    green: green ?? this.green,
    paleGreen: paleGreen ?? this.paleGreen,
    blue: blue ?? this.blue,
    paleBlue: paleBlue ?? this.paleBlue,
    amber: amber ?? this.amber,
    paleAmber: paleAmber ?? this.paleAmber,
    red: red ?? this.red,
    paleRed: paleRed ?? this.paleRed,
    action: action ?? this.action,
    actionHover: actionHover ?? this.actionHover,
    onAction: onAction ?? this.onAction,
    brandSurface: brandSurface ?? this.brandSurface,
    brandInk: brandInk ?? this.brandInk,
    selection: selection ?? this.selection,
    navActive: navActive ?? this.navActive,
    avatarLine: avatarLine ?? this.avatarLine,
    avatarSurface: avatarSurface ?? this.avatarSurface,
    avatarInk: avatarInk ?? this.avatarInk,
    breadcrumb: breadcrumb ?? this.breadcrumb,
    controlLine: controlLine ?? this.controlLine,
    controlHover: controlHover ?? this.controlHover,
    controlBorder: controlBorder ?? this.controlBorder,
    fieldSurface: fieldSurface ?? this.fieldSurface,
    placeholder: placeholder ?? this.placeholder,
    dangerLine: dangerLine ?? this.dangerLine,
    dangerHover: dangerHover ?? this.dangerHover,
    disabled: disabled ?? this.disabled,
    neutral: neutral ?? this.neutral,
    noticeLine: noticeLine ?? this.noticeLine,
    noticeSurface: noticeSurface ?? this.noticeSurface,
    noticeInk: noticeInk ?? this.noticeInk,
    chartGrid: chartGrid ?? this.chartGrid,
    legend: legend ?? this.legend,
    pumpLine: pumpLine ?? this.pumpLine,
    pumpSurface: pumpSurface ?? this.pumpSurface,
    pumpInk: pumpInk ?? this.pumpInk,
    pumpOutline: pumpOutline ?? this.pumpOutline,
    rowHover: rowHover ?? this.rowHover,
    emptyIcon: emptyIcon ?? this.emptyIcon,
    successLine: successLine ?? this.successLine,
    illustrationInk: illustrationInk ?? this.illustrationInk,
    illustrationFill: illustrationFill ?? this.illustrationFill,
    storySurface: storySurface ?? this.storySurface,
    errorCode: errorCode ?? this.errorCode,
    scrim: scrim ?? this.scrim,
  );

  @override
  GrowviaTokens lerp(GrowviaTokens? other, double t) {
    if (other == null) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return GrowviaTokens(
      canvas: mix(canvas, other.canvas),
      surface: mix(surface, other.surface),
      soft: mix(soft, other.soft),
      ink: mix(ink, other.ink),
      secondary: mix(secondary, other.secondary),
      muted: mix(muted, other.muted),
      line: mix(line, other.line),
      green: mix(green, other.green),
      paleGreen: mix(paleGreen, other.paleGreen),
      blue: mix(blue, other.blue),
      paleBlue: mix(paleBlue, other.paleBlue),
      amber: mix(amber, other.amber),
      paleAmber: mix(paleAmber, other.paleAmber),
      red: mix(red, other.red),
      paleRed: mix(paleRed, other.paleRed),
      action: mix(action, other.action),
      actionHover: mix(actionHover, other.actionHover),
      onAction: mix(onAction, other.onAction),
      brandSurface: mix(brandSurface, other.brandSurface),
      brandInk: mix(brandInk, other.brandInk),
      selection: mix(selection, other.selection),
      navActive: mix(navActive, other.navActive),
      avatarLine: mix(avatarLine, other.avatarLine),
      avatarSurface: mix(avatarSurface, other.avatarSurface),
      avatarInk: mix(avatarInk, other.avatarInk),
      breadcrumb: mix(breadcrumb, other.breadcrumb),
      controlLine: mix(controlLine, other.controlLine),
      controlHover: mix(controlHover, other.controlHover),
      controlBorder: mix(controlBorder, other.controlBorder),
      fieldSurface: mix(fieldSurface, other.fieldSurface),
      placeholder: mix(placeholder, other.placeholder),
      dangerLine: mix(dangerLine, other.dangerLine),
      dangerHover: mix(dangerHover, other.dangerHover),
      disabled: mix(disabled, other.disabled),
      neutral: mix(neutral, other.neutral),
      noticeLine: mix(noticeLine, other.noticeLine),
      noticeSurface: mix(noticeSurface, other.noticeSurface),
      noticeInk: mix(noticeInk, other.noticeInk),
      chartGrid: mix(chartGrid, other.chartGrid),
      legend: mix(legend, other.legend),
      pumpLine: mix(pumpLine, other.pumpLine),
      pumpSurface: mix(pumpSurface, other.pumpSurface),
      pumpInk: mix(pumpInk, other.pumpInk),
      pumpOutline: mix(pumpOutline, other.pumpOutline),
      rowHover: mix(rowHover, other.rowHover),
      emptyIcon: mix(emptyIcon, other.emptyIcon),
      successLine: mix(successLine, other.successLine),
      illustrationInk: mix(illustrationInk, other.illustrationInk),
      illustrationFill: mix(illustrationFill, other.illustrationFill),
      storySurface: mix(storySurface, other.storySurface),
      errorCode: mix(errorCode, other.errorCode),
      scrim: mix(scrim, other.scrim),
    );
  }
}
