import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app.dart';
import 'services/notification_service.dart';


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Configure status bar and system UI navigation overlays
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  // Load environment variables from .env
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint('Could not load .env file: $e');
  }

  String supabaseUrl = (dotenv.env['SUPABASE_URL'] ?? '').trim();
  final supabaseAnonKey = (dotenv.env['SUPABASE_ANON_KEY'] ?? '').trim();

  // Clean trailing /rest/v1 or trailing slashes if copied from Data API settings
  supabaseUrl = supabaseUrl.replaceAll(RegExp(r'/rest/v1/?$'), '');
  if (supabaseUrl.endsWith('/')) {
    supabaseUrl = supabaseUrl.substring(0, supabaseUrl.length - 1);
  }

  if (supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty) {
    await Supabase.initialize(
      url: supabaseUrl,
      // ignore: deprecated_member_use
      anonKey: supabaseAnonKey,
    );
  } else {
    debugPrint('WARNING: Supabase URL or Anon Key missing from .env');
  }

  // Initialize notification service & permissions
  try {
    await NotificationService().initialize();
    await NotificationService().requestPermissions();
  } catch (e) {
    debugPrint('Notification initialization error: $e');
  }

  runApp(const ProviderScope(child: AcademicAssistantApp()));
}

