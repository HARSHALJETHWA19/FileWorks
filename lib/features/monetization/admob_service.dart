import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_constants.dart';
import 'ad_config.dart';
import 'ad_service.dart';
import 'models/ad_frequency_state.dart';
import 'services/ad_diagnostics_service.dart';

class AdmobService with WidgetsBindingObserver implements AdService {
  final SharedPreferences _prefs;
  final AdDiagnosticsService _diagnostics = AdDiagnosticsService();
  InterstitialAd? _interstitialAd;
  bool _isInterstitialLoading = false;
  RewardedAd? _rewardedAd;
  bool _isRewardedLoading = false;
  bool _isRewardedShowing = false;
  AppOpenAd? _appOpenAd;
  DateTime? _appOpenLoadTime;
  bool _isAppOpenLoading = false;
  bool _isFullscreenAdShowing = false;
  bool _isProcessing = false;
  bool _isSaving = false;
  bool _isSharing = false;
  String? _currentRoute;

  int _operationCount = 0;
  int _transitionActionCount = 0;
  bool _initialized = false;
  bool _isPro = false;
  DateTime? _lastInterstitialTime;
  DateTime? _lastAppOpenTime;

  String? _lastInterstitialRejectionReason;
  String? _lastAppOpenRejectionReason;
  int _interstitialRetryAttempts = 0;
  Timer? _interstitialRetryTimer;
  int _appOpenRetryAttempts = 0;
  Timer? _appOpenRetryTimer;

  bool _consentInfoInitialized = false;
  bool _privacyOptionsRequired = false;
  final List<VoidCallback> _consentListeners = [];
  bool _observerRegistered = false;

  AdmobService(this._prefs) {
    _operationCount = _prefs.getInt(AppConstants.keyOperationCount) ?? 0;
    _isPro = _prefs.getBool(AppConstants.keyIsProUser) ?? false;
  }

  void _initObserver() {
    if (!_observerRegistered) {
      WidgetsBinding.instance.addObserver(this);
      _observerRegistered = true;
    }
  }

  void dispose() {
    if (_observerRegistered) {
      WidgetsBinding.instance.removeObserver(this);
      _observerRegistered = false;
    }
    _interstitialRetryTimer?.cancel();
    _appOpenRetryTimer?.cancel();
    _interstitialAd?.dispose();
    _rewardedAd?.dispose();
    _appOpenAd?.dispose();
  }

  AdDiagnosticsService get diagnostics => _diagnostics;

  @override
  String? getLastInterstitialRejectionReason() => _lastInterstitialRejectionReason;

  @override
  String? getLastAppOpenRejectionReason() => _lastAppOpenRejectionReason;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      maybeShowAppOpenAd();
    }
  }

  @override
  int get operationCount => _operationCount;

  @override
  bool get isFullscreenAdShowing => _isFullscreenAdShowing;

  @override
  bool get isConsentInfoInitialized => _consentInfoInitialized;

  @override
  bool get isPrivacyOptionsRequired => _privacyOptionsRequired;

  @override
  void addConsentListener(VoidCallback listener) {
    _consentListeners.add(listener);
  }

  @override
  void removeConsentListener(VoidCallback listener) {
    _consentListeners.remove(listener);
  }

  void _notifyConsentListeners() {
    for (final listener in List<VoidCallback>.from(_consentListeners)) {
      try {
        listener();
      } catch (e) {
        debugPrint('Error in consent listener: $e');
      }
    }
  }

  @override
  AdFrequencyState get frequencyState => AdFrequencyState(
        lastInterstitialAt: _lastInterstitialTime,
        lastAppOpenAt: _lastAppOpenTime,
        actionsSinceInterstitial: _transitionActionCount,
        isFullscreenAdShowing: _isFullscreenAdShowing,
        isProcessing: _isProcessing,
        isSaving: _isSaving,
        isSharing: _isSharing,
        currentRoute: _currentRoute,
        isPro: _isPro,
      );

  @override
  void setProcessing(bool value) {
    _isProcessing = value;
  }

  @override
  void setSaving(bool value) {
    _isSaving = value;
  }

  @override
  void setSharing(bool value) {
    _isSharing = value;
  }

  @override
  void setCurrentRoute(String? route) {
    _currentRoute = route;
  }

  @override
  void updateProStatus(bool isPro) {
    _isPro = isPro;
    if (_isPro) {
      // Immediately stop and dispose cached ads
      _interstitialRetryTimer?.cancel();
      _appOpenRetryTimer?.cancel();
      _interstitialAd?.dispose();
      _interstitialAd = null;
      _isInterstitialLoading = false;

      _rewardedAd?.dispose();
      _rewardedAd = null;
      _isRewardedLoading = false;
      _isRewardedShowing = false;

      _appOpenAd?.dispose();
      _appOpenAd = null;
      _isAppOpenLoading = false;
      _appOpenLoadTime = null;

      _isFullscreenAdShowing = false;
    } else {
      if (_initialized) {
        if (_interstitialAd == null && !_isInterstitialLoading && AdConfig.interstitialEnabled) {
          _loadInterstitialAd();
        }
        if (_rewardedAd == null && !_isRewardedLoading && AdConfig.rewardedEnabled) {
          _loadRewardedAd();
        }
        if (_appOpenAd == null && !_isAppOpenLoading && AdConfig.appOpenEnabled) {
          _loadAppOpenAd();
        }
      }
    }
  }

  @override
  Future<void> initialize() async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      _consentInfoInitialized = true;
      return;
    }

    _initObserver();

    final completer = Completer<void>();
    try {
      final params = ConsentRequestParameters();
      ConsentInformation.instance.requestConsentInfoUpdate(
        params,
        () async {
          try {
            final status = await ConsentInformation.instance.getPrivacyOptionsRequirementStatus();
            _privacyOptionsRequired = (status == PrivacyOptionsRequirementStatus.required);
            _consentInfoInitialized = true;
            _notifyConsentListeners();

            ConsentForm.loadAndShowConsentFormIfRequired(
              (FormError? formError) async {
                if (formError != null) {
                  debugPrint('Consent form error: ${formError.message}');
                }
                try {
                  final postStatus = await ConsentInformation.instance.getPrivacyOptionsRequirementStatus();
                  _privacyOptionsRequired = (postStatus == PrivacyOptionsRequirementStatus.required);
                  _notifyConsentListeners();
                } catch (_) {}

                if (await ConsentInformation.instance.canRequestAds()) {
                  await _initializeMobileAds();
                }
                if (!completer.isCompleted) completer.complete();
              },
            );
          } catch (e) {
            debugPrint('Error after consent info update: $e');
            _consentInfoInitialized = true;
            _notifyConsentListeners();
            if (await ConsentInformation.instance.canRequestAds()) {
              await _initializeMobileAds();
            }
            if (!completer.isCompleted) completer.complete();
          }
        },
        (FormError error) async {
          debugPrint('Consent info update error: ${error.message}');
          _consentInfoInitialized = true;
          _notifyConsentListeners();
          try {
            if (await ConsentInformation.instance.canRequestAds()) {
              await _initializeMobileAds();
            }
          } catch (_) {}
          if (!completer.isCompleted) completer.complete();
        },
      );

      // Safe timeout: never block app startup if UMP server is slow or offline
      await completer.future.timeout(
        const Duration(seconds: 3),
        onTimeout: () {
          debugPrint('UMP consent initialization timed out after 3s; proceeding safely');
        },
      );
    } catch (e) {
      debugPrint('AdMob UMP initialization skipped or failed: $e');
      _consentInfoInitialized = true;
      _notifyConsentListeners();
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
        if (AdConfig.appOpenEnabled) {
          _loadAppOpenAd();
        }
      }
    } catch (e) {
      debugPrint('MobileAds initialization skipped or failed: $e');
    }
  }

  /// Presents the Google UMP Privacy Options Form.
  @override
  Future<void> showPrivacyOptionsForm(BuildContext context) async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Privacy choices are available on mobile devices.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (!_consentInfoInitialized) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Privacy choices are initializing. Please try again in a moment.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (!_privacyOptionsRequired) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Privacy choices are not required for your region.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    try {
      ConsentForm.showPrivacyOptionsForm((FormError? formError) async {
        if (formError != null) {
          debugPrint('Privacy options form error: ${formError.message}');
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Privacy choices are temporarily unavailable. Please try again.'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        } else {
          try {
            final status = await ConsentInformation.instance.getPrivacyOptionsRequirementStatus();
            _privacyOptionsRequired = (status == PrivacyOptionsRequirementStatus.required);
            _notifyConsentListeners();
          } catch (_) {}
        }
      });
    } catch (e) {
      debugPrint('Error invoking privacy options form: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Privacy choices are temporarily unavailable. Please try again.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  /// Backward-compatible static helper if accessed without Riverpod.
  static Future<void> showPrivacyOptionsFormStatic(BuildContext context) async {
    ConsentForm.showPrivacyOptionsForm((FormError? formError) {
      if (formError != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Privacy choices are temporarily unavailable. Please try again.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });
  }

  // =========================================================================
  // APP OPEN ADS
  // =========================================================================

  @override
  Future<void> preloadAppOpenAd() async {
    if (!_initialized || _isPro || !AdConfig.appOpenEnabled) return;
    _loadAppOpenAd();
  }

  void _loadAppOpenAd() {
    if (!_initialized || _isAppOpenLoading || _appOpenAd != null || _isPro) {
      return;
    }
    if (!AdConfig.appOpenEnabled) return;

    _isAppOpenLoading = true;
    _diagnostics.logEvent(AdFormatType.appOpen, AdDiagnosticEventType.adRequest);

    AppOpenAd.load(
      adUnitId: AdConfig.appOpenAdUnitId,
      request: const AdRequest(),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) {
          _appOpenRetryAttempts = 0;
          _appOpenRetryTimer?.cancel();
          if (_isPro) {
            ad.dispose();
            _isAppOpenLoading = false;
            _appOpenAd = null;
            _diagnostics.logEvent(AdFormatType.appOpen, AdDiagnosticEventType.adPremiumRejected, reason: 'premium');
            return;
          }
          _appOpenAd = ad;
          _appOpenLoadTime = DateTime.now();
          _isAppOpenLoading = false;
          _diagnostics.logEvent(AdFormatType.appOpen, AdDiagnosticEventType.adLoadSuccess);
          _diagnostics.logEvent(AdFormatType.appOpen, AdDiagnosticEventType.adReady);
        },
        onAdFailedToLoad: (error) {
          debugPrint('AppOpenAd failed to load: $error');
          _isAppOpenLoading = false;
          _appOpenAd = null;
          _appOpenLoadTime = null;
          _diagnostics.logEvent(
            AdFormatType.appOpen,
            AdDiagnosticEventType.adLoadFailure,
            reason: error.message,
            details: {'code': error.code},
          );
          _diagnostics.logEvent(
            AdFormatType.appOpen,
            AdDiagnosticEventType.adNoFill,
            reason: 'AdMob no-fill (${error.code})',
          );

          if (!_isPro && AdConfig.appOpenEnabled && _appOpenRetryAttempts < 3) {
            _appOpenRetryAttempts++;
            _appOpenRetryTimer?.cancel();
            _appOpenRetryTimer = Timer(Duration(seconds: 25 * _appOpenRetryAttempts), () {
              if (!_isPro && _appOpenAd == null && !_isAppOpenLoading) {
                _loadAppOpenAd();
              }
            });
          }
        },
      ),
    );
  }

  bool _isAppOpenAdAvailable() {
    if (_appOpenAd == null || _appOpenLoadTime == null) return false;
    // App Open ads expire after 4 hours per AdMob documentation
    final age = DateTime.now().difference(_appOpenLoadTime!);
    if (age >= const Duration(hours: 4)) {
      _appOpenAd?.dispose();
      _appOpenAd = null;
      _appOpenLoadTime = null;
      return false;
    }
    return true;
  }

  @override
  bool isAppOpenEligible() {
    if (!_initialized) {
      _lastAppOpenRejectionReason = 'not_initialized';
      return false;
    }
    if (_isPro) {
      _lastAppOpenRejectionReason = 'premium';
      _diagnostics.logEvent(AdFormatType.appOpen, AdDiagnosticEventType.adPremiumRejected, reason: 'premium');
      return false;
    }
    if (!AdConfig.appOpenEnabled) {
      _lastAppOpenRejectionReason = 'format_disabled';
      return false;
    }
    if (_isFullscreenAdShowing) {
      _lastAppOpenRejectionReason = 'fullscreen_showing';
      _diagnostics.logEvent(AdFormatType.appOpen, AdDiagnosticEventType.adFullscreenRejected, reason: 'fullscreen_showing');
      return false;
    }
    if (_isProcessing) {
      _lastAppOpenRejectionReason = 'processing';
      _diagnostics.logEvent(AdFormatType.appOpen, AdDiagnosticEventType.adProcessingRejected, reason: 'processing');
      return false;
    }
    if (_isSaving) {
      _lastAppOpenRejectionReason = 'saving';
      _diagnostics.logEvent(AdFormatType.appOpen, AdDiagnosticEventType.adSavingRejected, reason: 'saving');
      return false;
    }
    if (_isSharing) {
      _lastAppOpenRejectionReason = 'sharing';
      _diagnostics.logEvent(AdFormatType.appOpen, AdDiagnosticEventType.adSharingRejected, reason: 'sharing');
      return false;
    }

    // Dedicated App Open cooldown check (120 seconds)
    if (_lastAppOpenTime != null) {
      final elapsed = DateTime.now().difference(_lastAppOpenTime!);
      if (elapsed < AdConfig.appOpenCooldown) {
        final remaining = AdConfig.appOpenCooldown.inSeconds - elapsed.inSeconds;
        _lastAppOpenRejectionReason = 'cooldown';
        _diagnostics.logEvent(
          AdFormatType.appOpen,
          AdDiagnosticEventType.adCooldownRejected,
          reason: 'cooldown',
          details: {'remainingSeconds': remaining},
        );
        debugPrint('AppOpen skipped: Cooldown active (${elapsed.inSeconds}s < ${AdConfig.appOpenCooldown.inSeconds}s)');
        return false;
      }
    }

    if (!_isAppOpenAdAvailable()) {
      _lastAppOpenRejectionReason = 'not_loaded';
      _diagnostics.logEvent(AdFormatType.appOpen, AdDiagnosticEventType.adEligibilityRejected, reason: 'not_loaded');
      return false;
    }

    _lastAppOpenRejectionReason = null;
    return true;
  }

  @override
  Future<bool> maybeShowAppOpenAd() async {
    if (!isAppOpenEligible()) {
      if (!_isAppOpenAdAvailable() && !_isAppOpenLoading && !_isPro && AdConfig.appOpenEnabled) {
        _loadAppOpenAd();
      }
      return false;
    }

    _diagnostics.logEvent(AdFormatType.appOpen, AdDiagnosticEventType.adShowAttempt);
    final ad = _appOpenAd!;
    _appOpenAd = null;
    _appOpenLoadTime = null;
    _isFullscreenAdShowing = true;

    final completer = Completer<bool>();

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        _diagnostics.logEvent(AdFormatType.appOpen, AdDiagnosticEventType.adShowSuccess);
        _diagnostics.logEvent(AdFormatType.appOpen, AdDiagnosticEventType.adImpression);
      },
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _isFullscreenAdShowing = false;
        _lastAppOpenTime = DateTime.now();
        _diagnostics.logEvent(AdFormatType.appOpen, AdDiagnosticEventType.adDismissed);
        if (!completer.isCompleted) completer.complete(true);
        if (!_isPro && AdConfig.appOpenEnabled) {
          _loadAppOpenAd();
        }
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('AppOpenAd failed to show: $error');
        ad.dispose();
        _isFullscreenAdShowing = false;
        _diagnostics.logEvent(
          AdFormatType.appOpen,
          AdDiagnosticEventType.adLoadFailure,
          reason: 'Show failed: ${error.message}',
        );
        if (!completer.isCompleted) completer.complete(false);
        if (!_isPro && AdConfig.appOpenEnabled) {
          _loadAppOpenAd();
        }
      },
    );

    try {
      await ad.show();
      return await completer.future;
    } catch (e) {
      debugPrint('Exception while displaying AppOpenAd: $e');
      _isFullscreenAdShowing = false;
      _diagnostics.logEvent(
        AdFormatType.appOpen,
        AdDiagnosticEventType.adLoadFailure,
        reason: 'Exception during show: $e',
      );
      if (!_isPro && AdConfig.appOpenEnabled) {
        _loadAppOpenAd();
      }
      return false;
    }
  }

  // =========================================================================
  // INTERSTITIAL ADS
  // =========================================================================

  @override
  Future<void> preloadInterstitialAd() async {
    if (!_initialized || _isPro || !AdConfig.interstitialEnabled) return;
    _loadInterstitialAd();
  }

  void _loadInterstitialAd() {
    if (!_initialized || _isInterstitialLoading || _interstitialAd != null || _isPro) {
      return;
    }
    if (!AdConfig.interstitialEnabled) return;

    _isInterstitialLoading = true;
    _diagnostics.logEvent(AdFormatType.interstitial, AdDiagnosticEventType.adRequest);

    InterstitialAd.load(
      adUnitId: AdConfig.interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialRetryAttempts = 0;
          _interstitialRetryTimer?.cancel();
          if (_isPro) {
            ad.dispose();
            _isInterstitialLoading = false;
            _interstitialAd = null;
            _diagnostics.logEvent(AdFormatType.interstitial, AdDiagnosticEventType.adPremiumRejected, reason: 'premium');
            return;
          }
          _interstitialAd = ad;
          _isInterstitialLoading = false;
          _diagnostics.logEvent(AdFormatType.interstitial, AdDiagnosticEventType.adLoadSuccess);
          _diagnostics.logEvent(AdFormatType.interstitial, AdDiagnosticEventType.adReady);
        },
        onAdFailedToLoad: (error) {
          debugPrint('Interstitial ad failed to load: $error');
          _isInterstitialLoading = false;
          _interstitialAd = null;
          _diagnostics.logEvent(
            AdFormatType.interstitial,
            AdDiagnosticEventType.adLoadFailure,
            reason: error.message,
            details: {'code': error.code},
          );
          _diagnostics.logEvent(
            AdFormatType.interstitial,
            AdDiagnosticEventType.adNoFill,
            reason: 'AdMob no-fill (${error.code})',
          );

          if (!_isPro && AdConfig.interstitialEnabled && _interstitialRetryAttempts < 3) {
            _interstitialRetryAttempts++;
            _interstitialRetryTimer?.cancel();
            _interstitialRetryTimer = Timer(Duration(seconds: 15 * _interstitialRetryAttempts), () {
              if (!_isPro && _interstitialAd == null && !_isInterstitialLoading) {
                _loadInterstitialAd();
              }
            });
          }
        },
      ),
    );
  }

  @override
  Future<void> recordOperationCompleted() async {
    _operationCount++;
    await _prefs.setInt(AppConstants.keyOperationCount, _operationCount);
  }

  @override
  void recordAction(AdTransitionPoint point) {
    if (_isPro) return;
    _transitionActionCount++;
    _diagnostics.updateActionCount(_transitionActionCount);
  }

  @override
  bool isInterstitialEligible() {
    if (!_initialized) {
      _lastInterstitialRejectionReason = 'not_initialized';
      return false;
    }
    if (_isPro) {
      _lastInterstitialRejectionReason = 'premium';
      _diagnostics.logEvent(AdFormatType.interstitial, AdDiagnosticEventType.adPremiumRejected, reason: 'premium');
      return false;
    }
    if (!AdConfig.interstitialEnabled) {
      _lastInterstitialRejectionReason = 'format_disabled';
      return false;
    }
    if (_isFullscreenAdShowing) {
      _lastInterstitialRejectionReason = 'fullscreen_showing';
      _diagnostics.logEvent(AdFormatType.interstitial, AdDiagnosticEventType.adFullscreenRejected, reason: 'fullscreen_showing');
      return false;
    }
    if (_isProcessing) {
      _lastInterstitialRejectionReason = 'processing';
      _diagnostics.logEvent(AdFormatType.interstitial, AdDiagnosticEventType.adProcessingRejected, reason: 'processing');
      return false;
    }
    if (_isSaving) {
      _lastInterstitialRejectionReason = 'saving';
      _diagnostics.logEvent(AdFormatType.interstitial, AdDiagnosticEventType.adSavingRejected, reason: 'saving');
      return false;
    }
    if (_isSharing) {
      _lastInterstitialRejectionReason = 'sharing';
      _diagnostics.logEvent(AdFormatType.interstitial, AdDiagnosticEventType.adSharingRejected, reason: 'sharing');
      return false;
    }

    // Check transition action threshold
    if (_transitionActionCount < AdConfig.maxActionsBetweenInterstitials &&
        _operationCount < AdConfig.interstitialOperationThreshold) {
      _lastInterstitialRejectionReason = 'action_threshold';
      _diagnostics.logEvent(
        AdFormatType.interstitial,
        AdDiagnosticEventType.adActionThresholdRejected,
        reason: 'action_threshold',
        details: {'actions': _transitionActionCount, 'threshold': AdConfig.maxActionsBetweenInterstitials, 'ops': _operationCount},
      );
      debugPrint('Interstitial skipped: Action threshold not reached (actions=$_transitionActionCount, ops=$_operationCount)');
      return false;
    }

    // Check cooldown
    if (_lastInterstitialTime != null) {
      final elapsed = DateTime.now().difference(_lastInterstitialTime!);
      if (elapsed < AdConfig.interstitialCooldown) {
        final remaining = AdConfig.interstitialCooldown.inSeconds - elapsed.inSeconds;
        _lastInterstitialRejectionReason = 'cooldown';
        _diagnostics.logEvent(
          AdFormatType.interstitial,
          AdDiagnosticEventType.adCooldownRejected,
          reason: 'cooldown',
          details: {'remainingSeconds': remaining},
        );
        debugPrint('Interstitial skipped: Cooldown active (${elapsed.inSeconds}s < ${AdConfig.interstitialCooldown.inSeconds}s)');
        return false;
      }
    }

    _lastInterstitialRejectionReason = null;
    return true;
  }

  @override
  Future<bool> maybeShowTransitionInterstitial({
    required AdTransitionPoint point,
    Duration timeout = const Duration(seconds: 2),
  }) async {
    if (!_initialized || _isPro || !AdConfig.interstitialEnabled) return false;
    if (_isFullscreenAdShowing || _isProcessing || _isSaving || _isSharing) return false;

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

    _lastInterstitialRejectionReason = 'not_loaded';
    _diagnostics.logEvent(AdFormatType.interstitial, AdDiagnosticEventType.adEligibilityRejected, reason: 'not_loaded');
    _loadInterstitialAd();
    return false;
  }

  Future<bool> _showLoadedInterstitial() async {
    if (_interstitialAd == null || _isFullscreenAdShowing) return false;
    _isFullscreenAdShowing = true;
    _diagnostics.logEvent(AdFormatType.interstitial, AdDiagnosticEventType.adShowAttempt);

    final ad = _interstitialAd!;
    _interstitialAd = null;
    _transitionActionCount = 0;
    _operationCount = 0;
    _diagnostics.updateActionCount(0);
    _lastInterstitialTime = DateTime.now();
    await _prefs.setInt(AppConstants.keyOperationCount, 0);

    final completer = Completer<bool>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        _diagnostics.logEvent(AdFormatType.interstitial, AdDiagnosticEventType.adShowSuccess);
        _diagnostics.logEvent(AdFormatType.interstitial, AdDiagnosticEventType.adImpression);
      },
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _isFullscreenAdShowing = false;
        _diagnostics.logEvent(AdFormatType.interstitial, AdDiagnosticEventType.adDismissed);
        if (!completer.isCompleted) completer.complete(true);
        if (!_isPro && AdConfig.interstitialEnabled) {
          _loadInterstitialAd();
        }
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _isFullscreenAdShowing = false;
        _diagnostics.logEvent(
          AdFormatType.interstitial,
          AdDiagnosticEventType.adLoadFailure,
          reason: 'Show failed: ${error.message}',
        );
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
      _isFullscreenAdShowing = false;
      _diagnostics.logEvent(
        AdFormatType.interstitial,
        AdDiagnosticEventType.adLoadFailure,
        reason: 'Exception during show: $e',
      );
      if (!_isPro && AdConfig.interstitialEnabled) {
        _loadInterstitialAd();
      }
      return false;
    }
  }

  @override
  Future<void> showInterstitialIfReady({bool force = false}) async {
    if (!_initialized || _isPro || !AdConfig.interstitialEnabled) return;
    if (_isFullscreenAdShowing || _isProcessing || _isSaving || _isSharing) return;

    if (force || isInterstitialEligible()) {
      if (_interstitialAd != null) {
        await _showLoadedInterstitial();
      } else {
        _loadInterstitialAd();
      }
    }
  }

  // =========================================================================
  // REWARDED ADS
  // =========================================================================

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
    _diagnostics.logEvent(AdFormatType.rewarded, AdDiagnosticEventType.adRequest);

    RewardedAd.load(
      adUnitId: AdConfig.rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          if (_isPro) {
            ad.dispose();
            _isRewardedLoading = false;
            _rewardedAd = null;
            _diagnostics.logEvent(AdFormatType.rewarded, AdDiagnosticEventType.adPremiumRejected, reason: 'premium');
            return;
          }
          _rewardedAd = ad;
          _isRewardedLoading = false;
          _diagnostics.logEvent(AdFormatType.rewarded, AdDiagnosticEventType.adLoadSuccess);
          _diagnostics.logEvent(AdFormatType.rewarded, AdDiagnosticEventType.adReady);
        },
        onAdFailedToLoad: (error) {
          debugPrint('Rewarded ad failed to load: $error');
          _isRewardedLoading = false;
          _rewardedAd = null;
          _diagnostics.logEvent(
            AdFormatType.rewarded,
            AdDiagnosticEventType.adLoadFailure,
            reason: error.message,
            details: {'code': error.code},
          );
        },
      ),
    );
  }

  @override
  Future<bool> showRewardedAd() async {
    if (_isPro) return true;
    if (_isFullscreenAdShowing || _isRewardedShowing) return false;
    if (!AdConfig.rewardedEnabled) return false;

    _diagnostics.logEvent(AdFormatType.rewarded, AdDiagnosticEventType.adShowAttempt);

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
      _diagnostics.logEvent(AdFormatType.rewarded, AdDiagnosticEventType.adEligibilityRejected, reason: 'not_ready');
      return false;
    }

    final ad = _rewardedAd!;
    _rewardedAd = null;
    _isRewardedShowing = true;
    _isFullscreenAdShowing = true;

    final completer = Completer<bool>();
    bool rewardEarned = false;

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        _diagnostics.logEvent(AdFormatType.rewarded, AdDiagnosticEventType.adShowSuccess);
      },
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _isRewardedShowing = false;
        _isFullscreenAdShowing = false;
        _diagnostics.logEvent(AdFormatType.rewarded, AdDiagnosticEventType.adDismissed);
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
        _isFullscreenAdShowing = false;
        _diagnostics.logEvent(
          AdFormatType.rewarded,
          AdDiagnosticEventType.adLoadFailure,
          reason: 'Show failed: ${error.message}',
        );
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
          _diagnostics.logEvent(
            AdFormatType.rewarded,
            AdDiagnosticEventType.adImpression,
            details: {'rewardType': reward.type, 'amount': reward.amount},
          );
        },
      );
    } catch (e) {
      debugPrint('Exception while displaying rewarded ad: $e');
      _isRewardedShowing = false;
      _isFullscreenAdShowing = false;
      _diagnostics.logEvent(
        AdFormatType.rewarded,
        AdDiagnosticEventType.adLoadFailure,
        reason: 'Exception during show: $e',
      );
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

  // =========================================================================
  // BANNER ADS
  // =========================================================================

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
  final AdDiagnosticsService _diagnostics = AdDiagnosticsService();

  @override
  void initState() {
    super.initState();
    _loadBanner();
  }

  void _loadBanner() {
    _diagnostics.logEvent(AdFormatType.banner, AdDiagnosticEventType.adRequest);

    _bannerAd = BannerAd(
      adUnitId: widget.adUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          _diagnostics.logEvent(AdFormatType.banner, AdDiagnosticEventType.adLoadSuccess);
          _diagnostics.logEvent(AdFormatType.banner, AdDiagnosticEventType.adReady);
          _diagnostics.logEvent(AdFormatType.banner, AdDiagnosticEventType.adImpression);
          _diagnostics.setBannerVisible(true);
          if (mounted) {
            setState(() {
              _isLoaded = true;
            });
          }
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('BannerAd failed to load: $error');
          _diagnostics.logEvent(
            AdFormatType.banner,
            AdDiagnosticEventType.adLoadFailure,
            reason: error.message,
            details: {'code': error.code},
          );
          _diagnostics.logEvent(
            AdFormatType.banner,
            AdDiagnosticEventType.adNoFill,
            reason: 'AdMob no-fill (${error.code})',
          );
          _diagnostics.setBannerVisible(false);
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
    _diagnostics.setBannerVisible(false);
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
    return const SizedBox(
      height: 50,
      width: 320,
    );
  }
}
