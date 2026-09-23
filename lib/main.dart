import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app/app.dart';
import 'features/monetization/admob_service.dart';
import 'features/monetization/providers/monetization_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize local persistent storage
  final prefs = await SharedPreferences.getInstance();

  // Initialize Google Mobile Ads SDK
  final admobService = AdmobService(prefs);
  await admobService.initialize();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        adServiceProvider.overrideWithValue(admobService),
      ],
      child: const FileWorksApp(),
    ),
  );
}
