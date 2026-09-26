import 'package:flutter/widgets.dart';

abstract class AdService {
  Future<void> initialize();
  Widget buildBannerAd();
  Future<void> showInterstitialIfReady({bool force = false});
  Future<void> recordOperationCompleted();
  int get operationCount;
  void updateProStatus(bool isPro);
}
