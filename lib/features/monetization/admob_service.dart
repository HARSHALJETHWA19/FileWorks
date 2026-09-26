import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_constants.dart';
import 'ad_config.dart';
import 'ad_service.dart';

class AdmobService implements AdService {
  final SharedPreferences _prefs;
  InterstitialAd? _interstitialAd;
  bool _isInterstitialLoading = false;
  RewardedAd? _rewardedAd;
  bool _isRewardedLoading = false;
  bool _isRewardedShowing = false;
  int _operationCount = 0;
  bool _initialized = false;
  bool _isPro = false;
  DateTime? _lastInterstitialTime;

  AdmobService(this._prefs) {
    _operationCount = _prefs.getInt(AppConstants.keyOperationCount) ?? 0;
    _isPro = _prefs.getBool(AppConstants.keyIsProUser) ?? false;
  }

  @override
  int get operationCount => _operationCount;

  @override
  void updateProStatus(bool isPro) {
    _isPro = isPro;
    if (_isPro) {
      // Immediately stop and dispose cached ads
      _interstitialAd?.dispose();
      _interstitialAd = null;
      _isInterstitialLoading = false;
      _rewardedAd?.dispose();
      _rewardedAd = null;
      _isRewardedLoading = false;
    } else {
      if (_initialized) {
        if (_interstitialAd == null && !_isInterstitialLoading && AdConfig.interstitialEnabled) {
          _loadInterstitialAd();
        }
        if (_rewardedAd == null && !_isRewardedLoading && AdConfig.rewardedEnabled) {
          _loadRewardedAd();
        }
      }
    }
  }

  @override
  Future<void> initialize() async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return;
    }
    try {
      final params = ConsentRequestParameters();
      ConsentInformation.instance.requestConsentInfoUpdate(
        params,
        () async {
          ConsentForm.loadAndShowConsentFormIfRequired(
            (FormError? formError) async {
              if (formError != null) {
                debugPrint('Consent form error: ${formError.message}');
              }
              if (await ConsentInformation.instance.canRequestAds()) {
                await _initializeMobileAds();
              }
            },
          );
        },
        (FormError error) async {
          debugPrint('Consent info update error: ${error.message}');
          // If update failed (e.g. offline), initialize if consent status allows
          if (await ConsentInformation.instance.canRequestAds()) {
            await _initializeMobileAds();
          }
        },
      );
    } catch (e) {
      debugPrint('AdMob UMP initialization skipped or failed: $e');
      await _initializeMobileAds();
    }
  }

  Future<void> _initializeMobileAds() async {
    if (_initialized) return;
    try {
      await MobileAds.instance.initialize();
      _initialized = true;
      if (!_isPro) {
        if (AdConfig.interstitialEnabled) {
          _loadInterstitialAd();
        }
        if (AdConfig.rewardedEnabled) {
          _loadRewardedAd();
        }
      }
    } catch (e) {
      debugPrint('MobileAds initialization skipped or failed: $e');
    }
  }

  /// Presents the Google UMP Privacy Options Form if available.
  static Future<void> showPrivacyOptionsForm(BuildContext context) async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Privacy choices are available on mobile devices.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    try {
      ConsentForm.showPrivacyOptionsForm((FormError? formError) {
        if (formError != null) {
          debugPrint('Privacy options form error: ${formError.message}');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Privacy choices: ${formError.message}'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      });
    } catch (e) {
      debugPrint('Error invoking privacy options form: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open privacy choices: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _loadInterstitialAd() {
    if (!_initialized || _isInterstitialLoading || _interstitialAd != null || _isPro) {
      return;
    }
    if (!AdConfig.interstitialEnabled) return;

    _isInterstitialLoading = true;

    InterstitialAd.load(
      adUnitId: AdConfig.interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          if (_isPro) {
            ad.dispose();
            _isInterstitialLoading = false;
            _interstitialAd = null;
            return;
          }
          _interstitialAd = ad;
          _isInterstitialLoading = false;
          _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _interstitialAd = null;
              if (!_isPro && AdConfig.interstitialEnabled) {
                _loadInterstitialAd(); // Preload next
              }
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              _interstitialAd = null;
              if (!_isPro && AdConfig.interstitialEnabled) {
                _loadInterstitialAd();
              }
            },
          );
        },
        onAdFailedToLoad: (error) {
          debugPrint('Interstitial ad failed to load: $error');
          _isInterstitialLoading = false;
          _interstitialAd = null;
        },
      ),
    );
  }

  int _transitionActionCount = 0;
  bool _isInterstitialShowing = false;

  @override
  Future<void> recordOperationCompleted() async {
    _operationCount++;
    await _prefs.setInt(AppConstants.keyOperationCount, _operationCount);
  }

  @override
  void recordAction(AdTransitionPoint point) {
    if (_isPro) return;
    _transitionActionCount++;
  }

  @override
  bool isInterstitialEligible() {
    if (!_initialized || _isPro || !AdConfig.interstitialEnabled) return false;
    if (_isInterstitialShowing) return false;

    // Check transition action threshold
    if (_transitionActionCount < AdConfig.maxActionsBetweenInterstitials &&
        _operationCount < AdConfig.interstitialOperationThreshold) {
      debugPrint('Interstitial skipped: Action threshold not reached (actions=$_transitionActionCount, ops=$_operationCount)');
      return false;
    }

    // Check cooldown
    if (_lastInterstitialTime != null) {
      final elapsed = DateTime.now().difference(_lastInterstitialTime!);
      if (elapsed < AdConfig.interstitialCooldown) {
        debugPrint('Interstitial skipped: Cooldown active (${elapsed.inSeconds}s < ${AdConfig.interstitialCooldown.inSeconds}s)');
        return false;
      }
    }

    return true;
  }

  @override
  Future<bool> maybeShowTransitionInterstitial({
    required AdTransitionPoint point,
    Duration timeout = const Duration(seconds: 2),
  }) async {
    if (!_initialized || _isPro || !AdConfig.interstitialEnabled) return false;

    recordAction(point);

    if (!isInterstitialEligible()) {
      return false;
    }

    if (_interstitialAd != null) {
      return _showLoadedInterstitial();
    }

    if (_isInterstitialLoading) {
      final completer = Completer<bool>();
      Timer? timer;
      timer = Timer.periodic(const Duration(milliseconds: 100), (t) {
        if (_interstitialAd != null) {
          timer?.cancel();
          if (!completer.isCompleted) {
            _showLoadedInterstitial().then((val) {
              if (!completer.isCompleted) completer.complete(val);
            });
          }
        } else if (t.tick >= (timeout.inMilliseconds / 100)) {
          timer?.cancel();
          if (!completer.isCompleted) completer.complete(false);
        }
      });
      return completer.future;
    }

    _loadInterstitialAd();
    return false;
  }

  Future<bool> _showLoadedInterstitial() async {
    if (_interstitialAd == null || _isInterstitialShowing) return false;
    _isInterstitialShowing = true;
    final ad = _interstitialAd!;
    _interstitialAd = null;
    _transitionActionCount = 0;
    _operationCount = 0;
    _lastInterstitialTime = DateTime.now();
    await _prefs.setInt(AppConstants.keyOperationCount, 0);

    final completer = Completer<bool>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _isInterstitialShowing = false;
        if (!completer.isCompleted) completer.complete(true);
        if (!_isPro && AdConfig.interstitialEnabled) {
          _loadInterstitialAd();
        }
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _isInterstitialShowing = false;
        if (!completer.isCompleted) completer.complete(false);
        if (!_isPro && AdConfig.interstitialEnabled) {
          _loadInterstitialAd();
        }
      },
    );

    try {
      await ad.show();
      return await completer.future;
    } catch (e) {
      _isInterstitialShowing = false;
      if (!_isPro && AdConfig.interstitialEnabled) {
        _loadInterstitialAd();
      }
      return false;
    }
  }

  @override
  Future<void> showInterstitialIfReady({bool force = false}) async {
    if (!_initialized || _isPro || !AdConfig.interstitialEnabled) return;

    if (force || isInterstitialEligible()) {
      if (_interstitialAd != null) {
        await _showLoadedInterstitial();
      } else {
        _loadInterstitialAd();
      }
    }
  }

  @override
  bool get isRewardedAdAvailable => _rewardedAd != null;

  @override
  Future<void> preloadRewardedAd() async {
    if (!_initialized || _isPro || !AdConfig.rewardedEnabled) return;
    _loadRewardedAd();
  }

  void _loadRewardedAd() {
    if (!_initialized || _isRewardedLoading || _rewardedAd != null || _isPro) {
      return;
    }
    if (!AdConfig.rewardedEnabled) return;

    _isRewardedLoading = true;

    RewardedAd.load(
      adUnitId: AdConfig.rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          if (_isPro) {
            ad.dispose();
            _isRewardedLoading = false;
            _rewardedAd = null;
            return;
          }
          _rewardedAd = ad;
          _isRewardedLoading = false;
        },
        onAdFailedToLoad: (error) {
          debugPrint('Rewarded ad failed to load: $error');
          _isRewardedLoading = false;
          _rewardedAd = null;
        },
      ),
    );
  }

  @override
  Future<bool> showRewardedAd() async {
    if (_isPro) return true;
    if (_isRewardedShowing) return false;
    if (!AdConfig.rewardedEnabled) return false;

    // If ad is not ready, try loading it with a short wait
    if (_rewardedAd == null) {
      _loadRewardedAd();
      int attempts = 0;
      while (_isRewardedLoading && attempts < 25) {
        await Future.delayed(const Duration(milliseconds: 200));
        attempts++;
      }
    }

    if (_rewardedAd == null) {
      debugPrint('Rewarded ad unavailable');
      return false;
    }

    final ad = _rewardedAd!;
    _rewardedAd = null;
    _isRewardedShowing = true;

    final completer = Completer<bool>();
    bool rewardEarned = false;

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _isRewardedShowing = false;
        if (!completer.isCompleted) {
          completer.complete(rewardEarned);
        }
        if (!_isPro && AdConfig.rewardedEnabled) {
          _loadRewardedAd();
        }
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('Rewarded ad failed to show: $error');
        ad.dispose();
        _isRewardedShowing = false;
        if (!completer.isCompleted) {
          completer.complete(false);
        }
        if (!_isPro && AdConfig.rewardedEnabled) {
          _loadRewardedAd();
        }
      },
    );

    try {
      await ad.show(
        onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
          rewardEarned = true;
        },
      );
    } catch (e) {
      debugPrint('Exception while displaying rewarded ad: $e');
      _isRewardedShowing = false;
      if (!completer.isCompleted) {
        completer.complete(false);
      }
    }

    return completer.future;
  }

  @override
  Future<bool> isNetworkAvailable() async {
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 2));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget buildBannerAd() {
    if (!_initialized || _isPro || !AdConfig.bannerEnabled) {
      return const SizedBox.shrink();
    }
    return _AdMobBannerWidget(adUnitId: AdConfig.bannerAdUnitId);
  }
}

class _AdMobBannerWidget extends StatefulWidget {
  final String adUnitId;

  const _AdMobBannerWidget({required this.adUnitId});

  @override
  State<_AdMobBannerWidget> createState() => _AdMobBannerWidgetState();
}

class _AdMobBannerWidgetState extends State<_AdMobBannerWidget> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadBanner();
  }

  void _loadBanner() {
    _bannerAd = BannerAd(
      adUnitId: widget.adUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) {
            setState(() {
              _isLoaded = true;
            });
          }
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('BannerAd failed to load: $error');
          ad.dispose();
          if (mounted) {
            setState(() {
              _bannerAd = null;
              _isLoaded = false;
            });
          }
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoaded && _bannerAd != null) {
      return Container(
        alignment: Alignment.center,
        width: _bannerAd!.size.width.toDouble(),
        height: _bannerAd!.size.height.toDouble(),
        child: AdWidget(ad: _bannerAd!),
      );
    }
    return const SizedBox.shrink();
  }
}
