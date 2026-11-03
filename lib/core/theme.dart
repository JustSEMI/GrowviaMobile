import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'tokens.dart';

/// Tema Growvia, disusun dari [GrowviaTokens] yang mencerminkan `app.css`.
///
/// Prinsipnya: warna tidak ditulis ulang di sini, melainkan diambil dari
/// token yang sudah diverifikasi terhadap web (`Tools/growvia-mobile/
/// verify_tokens.py`). [ColorScheme] Material hanya jembatan agar komponen
/// bawaan Flutter ikut sewarna; widget Growvia sebaiknya membaca
/// `GrowviaTokens.of(context)` langsung.
abstract final class GrowviaTheme {
  static ThemeData light() => _theme(GrowviaTokens.light, Brightness.light);

  static ThemeData dark() => _theme(GrowviaTokens.dark, Brightness.dark);

  static ThemeData _theme(GrowviaTokens t, Brightness brightness) {
    final scheme = ColorScheme(
      brightness: brightness,
      primary: t.green,
      onPrimary: t.surface,
      primaryContainer: t.paleGreen,
      onPrimaryContainer: t.green,
      secondary: t.secondary,
      onSecondary: t.surface,
      secondaryContainer: t.soft,
      onSecondaryContainer: t.ink,
      tertiary: t.blue,
      onTertiary: t.surface,
      tertiaryContainer: t.paleBlue,
      onTertiaryContainer: t.blue,
      error: t.red,
      onError: t.surface,
      errorContainer: t.paleRed,
      onErrorContainer: t.red,
      surface: t.surface,
      onSurface: t.ink,
      onSurfaceVariant: t.secondary,
      surfaceContainerLowest: t.canvas,
      surfaceContainerLow: t.soft,
      surfaceContainer: t.neutral,
      surfaceContainerHigh: t.soft,
      surfaceContainerHighest: t.neutral,
      outline: t.controlBorder,
      outlineVariant: t.line,
      shadow: t.scrim,
      scrim: t.scrim,
      inverseSurface: t.ink,
      onInverseSurface: t.canvas,
      inversePrimary: t.paleGreen,
      surfaceTint: Colors.transparent,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      fontFamily: 'Montserrat',
      extensions: <ThemeExtension<dynamic>>[t],
    );

    return base.copyWith(
      scaffoldBackgroundColor: t.canvas,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.fuchsia: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      textTheme: base.textTheme.copyWith(
        displaySmall: base.textTheme.displaySmall?.copyWith(
          fontFamily: 'Horizon',
          height: 1.12,
          fontSize: 42,
        ),
        headlineMedium: base.textTheme.headlineMedium?.copyWith(
          fontFamily: 'Horizon',
          height: 1.12,
          fontSize: 34,
        ),
        titleLarge: base.textTheme.titleLarge?.copyWith(
          fontSize: 21,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: base.textTheme.bodyLarge?.copyWith(
          fontSize: 16,
          height: 1.5,
        ),
        bodyMedium: base.textTheme.bodyMedium?.copyWith(
          fontSize: 14,
          height: 1.5,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: t.canvas,
        foregroundColor: t.ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 20,
      ),
      cardTheme: CardThemeData(
        color: t.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: t.line),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: t.fieldSurface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 18,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: t.controlBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: t.green, width: 1.5),
        ),
        errorMaxLines: 3,
        hintStyle: TextStyle(color: t.placeholder),
        labelStyle: TextStyle(color: t.secondary),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 52),
          backgroundColor: t.action,
          foregroundColor: t.onAction,
          disabledBackgroundColor: t.disabled,
          disabledForegroundColor: t.secondary,
          textStyle: const TextStyle(
            fontFamily: 'Montserrat',
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 52),
          foregroundColor: t.ink,
          backgroundColor: t.surface,
          side: BorderSide(color: t.controlLine),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          foregroundColor: t.green,
        ),
      ),
      iconTheme: IconThemeData(color: t.secondary, size: 20),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: t.surface,
        indicatorColor: t.paleGreen,
        indicatorShape: const StadiumBorder(),
        elevation: 0,
        height: 78,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(fontFamily: 'Montserrat', fontSize: 12, color: t.ink),
        ),
      ),
      dividerTheme: DividerThemeData(color: t.line, space: 1),
      dialogTheme: DialogThemeData(
        backgroundColor: t.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      drawerTheme: DrawerThemeData(
        backgroundColor: t.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(),
      ),
      listTileTheme: ListTileThemeData(
        selectedColor: t.navActive,
        selectedTileColor: t.paleGreen,
        iconColor: t.secondary,
        textColor: t.ink,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: t.green),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? t.surface : t.secondary,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? t.green : t.neutral,
        ),
        trackOutlineColor: WidgetStatePropertyAll(t.controlBorder),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? t.green : t.fieldSurface,
        ),
        checkColor: WidgetStatePropertyAll(t.surface),
        side: BorderSide(color: t.controlBorder),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? t.green : t.controlBorder,
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: t.green,
        unselectedLabelColor: t.secondary,
        indicatorColor: t.green,
        dividerColor: t.line,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: t.neutral,
        selectedColor: t.paleGreen,
        side: BorderSide(color: t.line),
        labelStyle: TextStyle(color: t.ink, fontFamily: 'Montserrat'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: t.ink,
        contentTextStyle: TextStyle(
          color: t.canvas,
          fontFamily: 'Montserrat',
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: t.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: t.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: t.controlLine),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: t.ink,
          borderRadius: BorderRadius.circular(6),
        ),
        textStyle: TextStyle(
          color: t.canvas,
          fontSize: 12,
          fontFamily: 'Montserrat',
        ),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: t.green,
        selectionColor: t.selection,
        selectionHandleColor: t.green,
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStatePropertyAll(t.controlHover),
        radius: const Radius.circular(999),
      ),
    );
  }
}
