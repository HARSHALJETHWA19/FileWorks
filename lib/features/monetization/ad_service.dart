import 'package:flutter/widgets.dart';

enum AdTransitionPoint {
  processingComplete,
  saveToDeviceComplete,
  doneNavigation,
  processAnotherFile,
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
  Future<bool> isNetworkAvailable() async => true;
}
