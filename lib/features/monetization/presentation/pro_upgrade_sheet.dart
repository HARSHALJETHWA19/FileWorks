import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:open_filex/open_filex.dart';
import '../../../core/widgets/primary_button.dart';
import '../billing_constants.dart';
import '../providers/monetization_provider.dart';
import '../services/billing_service.dart';

class ProUpgradeSheet extends ConsumerStatefulWidget {
  const ProUpgradeSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => const ProUpgradeSheet(),
    );
  }

  @override
  ConsumerState<ProUpgradeSheet> createState() => _ProUpgradeSheetState();
}

class _ProUpgradeSheetState extends ConsumerState<ProUpgradeSheet> {
  String _selectedProductId = BillingConstants.subscription1Year;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entitlement = ref.watch(entitlementStateProvider);
    final billingService = ref.read(billingServiceProvider);

    final product6m = entitlement.products.cast<ProductDetails?>().firstWhere(
          (p) => p?.id == BillingConstants.subscription6Months,
          orElse: () => null,
        );
    final product1y = entitlement.products.cast<ProductDetails?>().firstWhere(
          (p) => p?.id == BillingConstants.subscription1Year,
          orElse: () => null,
        );

    final selectedProduct = _selectedProductId == BillingConstants.subscription1Year
        ? product1y
        : product6m;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        16,
        24,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        theme.colorScheme.primary,
                        theme.colorScheme.tertiary,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'FileWorks Premium',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        entitlement.isPro
                            ? 'Active Premium Subscription'
                            : 'Simple. Private. 100% Ad-Free.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildFeatureRow(
              theme,
              Icons.block_rounded,
              '100% Ad-Free Experience',
              'Zero banner or interstitial ads across all features.',
            ),
            const SizedBox(height: 12),
            _buildFeatureRow(
              theme,
              Icons.all_inclusive_rounded,
              'Unlimited Batch Processing',
              'Convert, merge, and compress multiple files in one pass.',
            ),
            const SizedBox(height: 12),
            _buildFeatureRow(
              theme,
              Icons.security_rounded,
              '100% On-Device Privacy',
              'All files process locally. Never uploaded to external servers.',
            ),
            const SizedBox(height: 20),
            if (entitlement.errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded,
                        color: theme.colorScheme.error, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        entitlement.errorMessage!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (entitlement.isPro) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: theme.colorScheme.primary, width: 1.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.check_circle_rounded,
                            color: theme.colorScheme.primary, size: 22),
                        const SizedBox(width: 8),
                        Text(
                          'Premium Active',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Your subscription is active via Google Play. You enjoy complete ad immunity and full access to all features.',
                      style: theme.textTheme.bodyMedium,
                    ),
                    if (entitlement.expiryDate != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Renews / Valid until: ${entitlement.expiryDate!.toLocal().toString().split(' ')[0]}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () {
                  OpenFilex.open(
                    'https://play.google.com/store/account/subscriptions?package=com.fileworks.app',
                  );
                },
                icon: const Icon(Icons.settings_rounded),
                label: const Text('Manage Subscription on Google Play'),
              ),
            ] else ...[
              // Subscription Options
              Text(
                'Choose your plan:',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              _buildPlanCard(
                theme: theme,
                id: BillingConstants.subscription1Year,
                title: '12-Month Plan',
                durationSubtitle: 'Annual subscription · Best value',
                priceText: product1y != null
                    ? product1y.price
                    : 'Google Play price loaded upon launch',
                badgeText: 'POPULAR',
                isSelected: _selectedProductId == BillingConstants.subscription1Year,
                onTap: () {
                  setState(() {
                    _selectedProductId = BillingConstants.subscription1Year;
                  });
                },
              ),
              const SizedBox(height: 10),
              _buildPlanCard(
                theme: theme,
                id: BillingConstants.subscription6Months,
                title: '6-Month Plan',
                durationSubtitle: 'Standard 6-month subscription',
                priceText: product6m != null
                    ? product6m.price
                    : 'Google Play price loaded upon launch',
                isSelected: _selectedProductId == BillingConstants.subscription6Months,
                onTap: () {
                  setState(() {
                    _selectedProductId = BillingConstants.subscription6Months;
                  });
                },
              ),
              const SizedBox(height: 20),
              PrimaryButton(
                label: entitlement.isLoading
                    ? 'Connecting to Google Play...'
                    : 'Subscribe with Google Play',
                icon: Icons.lock_open_rounded,
                isLoading: entitlement.isLoading,
                onPressed: entitlement.isLoading
                    ? null
                    : () async {
                        if (selectedProduct != null) {
                          await billingService.buySubscription(selectedProduct);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Google Play subscription products will become active once published in the Google Play Console.',
                              ),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton.icon(
                    onPressed: entitlement.isLoading
                        ? null
                        : () => _handleRestore(context, billingService),
                    icon: const Icon(Icons.restore_rounded, size: 18),
                    label: const Text('Restore Purchases'),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Text(
              'Subscriptions renew automatically via Google Play until cancelled. '
              'Cancel anytime in Google Play Subscriptions. '
              'Files are processed 100% locally on-device.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanCard({
    required ThemeData theme,
    required String id,
    required String title,
    required String durationSubtitle,
    required String priceText,
    required bool isSelected,
    required VoidCallback onTap,
    String? badgeText,
  }) {
    final borderColor = isSelected
        ? theme.colorScheme.primary
        : theme.colorScheme.outlineVariant;
    final backgroundColor = isSelected
        ? theme.colorScheme.primaryContainer.withValues(alpha: 0.25)
        : theme.colorScheme.surface;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: borderColor,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(
                isSelected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (badgeText != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.tertiary,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            badgeText,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onTertiary,
                              fontWeight: FontWeight.w800,
                              fontSize: 9,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    durationSubtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 130),
              child: Text(
                priceText,
                textAlign: TextAlign.end,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureRow(
    ThemeData theme,
    IconData icon,
    String title,
    String subtitle,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _handleRestore(BuildContext context, BillingService billingService) async {
    await billingService.restorePurchases();
    if (!context.mounted) return;

    final state = billingService.state;
    if (state.isPro) {
      _showRestoreDialog(
        context,
        title: 'Subscription Restored',
        message: 'Your FileWorks Premium subscription has been restored.',
        icon: Icons.check_circle_rounded,
        iconColor: Colors.green,
      );
    } else if (state.errorMessage != null && state.errorMessage!.isNotEmpty) {
      _showRestoreDialog(
        context,
        title: 'Restore Error',
        message: "We couldn't restore your purchase right now. Please try again later.",
        icon: Icons.error_outline_rounded,
        iconColor: Theme.of(context).colorScheme.error,
      );
    } else {
      _showRestoreDialog(
        context,
        title: 'No Active Subscription',
        message: 'No active FileWorks Premium subscription was found.',
        icon: Icons.info_outline_rounded,
        iconColor: Theme.of(context).colorScheme.primary,
      );
    }
  }

  void _showRestoreDialog(
    BuildContext context, {
    required String title,
    required String message,
    required IconData icon,
    required Color iconColor,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(icon, color: iconColor, size: 36),
        title: Text(title, textAlign: TextAlign.center),
        content: Text(message, textAlign: TextAlign.center),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
