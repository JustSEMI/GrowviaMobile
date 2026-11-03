import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:http/http.dart' as http;

import 'core/app_controller.dart';
import 'core/theme.dart';
import 'features/login_page.dart';
import 'features/workspace_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MainApp());
}

class MainApp extends StatefulWidget {
  const MainApp({this.client, super.key});
  final http.Client? client;
  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  late final AppController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AppController(client: widget.client);
    _controller.addListener(_updated);
    _controller.preferences.addListener(_updated);
    _controller.initialize();
  }

  void _updated() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_updated);
    _controller.preferences.removeListener(_updated);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Growvia',
    debugShowCheckedModeBanner: false,
    locale: const Locale('id'),
    supportedLocales: const [Locale('id')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    theme: GrowviaTheme.light(),
    darkTheme: GrowviaTheme.dark(),
    themeMode: _controller.preferences.themeMode,
    home: _controller.initializing
        ? const Scaffold(
            body: SafeArea(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 20),
                    Text('Menyiapkan ruang kerja…'),
                  ],
                ),
              ),
            ),
          )
        : _controller.workspaceOpen
        ? WorkspacePage(controller: _controller)
        : LoginPage(controller: _controller),
  );
}
