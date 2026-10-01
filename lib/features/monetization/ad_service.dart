import 'package:flutter/widgets.dart';
import 'models/ad_frequency_state.dart';

enum AdTransitionPoint {
  processingComplete,
  saveToDeviceComplete,
  doneNavigation,
  processAnotherFile,
  resultReached,
  returnToHome,
  completedOperation,
  startingNewOperation,
}

abstract class AdService {
  Future<void> initialize();
  Widget buildBannerAd();
  Future<void> showInterstitialIfReady({bool force = false});
  Future<bool> maybeShowTransitionInterstitial({
    required AdTransitionPoint point,
    Duration timeout = const Duration(seconds: 2),
  }) async => false;
  void recordAction(AdTransitionPoint point) {}
  bool isInterstitialEligible() => false;
  Future<void> recordOperationCompleted();
  int get operationCount;
  void updateProStatus(bool isPro);
  Future<bool> showRewardedAd() async => false;
  bool get isRewardedAdAvailable => false;
  Future<void> preloadRewardedAd() async {}
  Future<void> preloadInterstitialAd() async {}
  Future<void> preloadAppOpenAd() async {}
  Future<bool> isNetworkAvailable() async => true;
  String? getLastInterstitialRejectionReason() => null;
  String? getLastAppOpenRejectionReason() => null;

  // Centralized frequency & interaction tracking
  AdFrequencyState get frequencyState => const AdFrequencyState();
  void setProcessing(bool value) {}
  void setSaving(bool value) {}
  void setSharing(bool value) {}
  void setCurrentRoute(String? route) {}
  bool isAppOpenEligible() => false;
  Future<bool> maybeShowAppOpenAd() async => false;
  bool get isFullscreenAdShowing => false;

  // UMP consent & privacy choices
  bool get isConsentInfoInitialized => true;
  bool get isPrivacyOptionsRequired => false;
  Future<void> showPrivacyOptionsForm(BuildContext context) async {}
  void addConsentListener(VoidCallback listener) {}
  void removeConsentListener(VoidCallback listener) {}
}
