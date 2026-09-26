import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app/app.dart';
import 'features/monetization/admob_service.dart';
import 'features/monetization/providers/monetization_provider.dart';
import 'features/monetization/services/billing_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize local persistent storage
  final prefs = await SharedPreferences.getInstance();

  // Initialize Google Mobile Ads SDK
  final admobService = AdmobService(prefs);
  await admobService.initialize();

  // Initialize Google Play Billing Service
  final billingService = BillingService(prefs);
  await billingService.initialize();

  // Synchronize initial Pro entitlement status with AdMob
  admobService.updateProStatus(billingService.state.isPro);

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        adServiceProvider.overrideWithValue(admobService),
        billingServiceProvider.overrideWithValue(billingService),
      ],
      child: const FileWorksApp(),
    ),
  );
}
