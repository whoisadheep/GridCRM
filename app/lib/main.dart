import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'ui/screens/call_list_screen.dart';
import 'ui/screens/login_screen.dart';
import 'core/settings.dart';
import 'core/sync_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  bool _isLoggedIn = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initSyncListener();
    _checkLogin();
  }

  Future<void> _checkLogin() async {
    final settings = ref.read(settingsProvider);
    final loggedIn = await settings.isLoggedIn();
    if (loggedIn) {
      if (FirebaseAuth.instance.currentUser == null) {
        await settings.logout();
        _isLoggedIn = false;
      } else {
        final role = await settings.getRole();
        ref.read(roleProvider.notifier).state = role;
        _isLoggedIn = true;
      }
    } else {
      _isLoggedIn = false;
    }
    if (mounted) {
      setState(() {
        _isLoggedIn = loggedIn;
        _isLoading = false;
      });
    }
  }

  void _initSyncListener() {
    Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
      if (!results.contains(ConnectivityResult.none)) {
        // We are online! Trigger sync.
        ref.read(syncServiceProvider).syncPendingActions(ref);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const MaterialApp(
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    return MaterialApp(
      title: 'Grid CRM',
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFFF2F6FA), // Soft pastel background
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4285F4), // Google-esque blue
          brightness: Brightness.light,
          surface: const Color(0xFFF2F6FA),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF2F6FA),
          elevation: 0,
          scrolledUnderElevation: 0,
          iconTheme: IconThemeData(color: Colors.black87),
          titleTextStyle: TextStyle(color: Colors.black87, fontSize: 20, fontWeight: FontWeight.bold),
        ),
        useMaterial3: true,
      ),
      home: _isLoggedIn ? const CallListScreen() : const LoginScreen(),
    );
  }
}
