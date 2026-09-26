import 'package:flutter/widgets.dart';

abstract class AdService {
  Future<void> initialize();
  Widget buildBannerAd();
  Future<void> showInterstitialIfReady({bool force = false});
  Future<void> recordOperationCompleted();
  int get operationCount;
  void updateProStatus(bool isPro);
  Future<bool> showRewardedAd() async => false;
  bool get isRewardedAdAvailable => false;
  Future<void> preloadRewardedAd() async {}
}
