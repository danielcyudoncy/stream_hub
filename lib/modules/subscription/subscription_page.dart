import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/constants/app_constants.dart';
import '../../shared/widgets/app_scaffold.dart';
import '../../shared/widgets/tv_focusable.dart';
import '../../data/services/free_tv_slot_service.dart';
import 'subscription_controller.dart';
import 'widgets/subscription_benefit_tile.dart';
import 'widgets/subscription_plan_card.dart';

class SubscriptionPage extends StatefulWidget {
  const SubscriptionPage({super.key});

  @override
  State<SubscriptionPage> createState() => _SubscriptionPageState();
}

class _SubscriptionPageState extends State<SubscriptionPage> {
  final TextEditingController _emailController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final controller = Get.isRegistered<SubscriptionController>()
        ? Get.find<SubscriptionController>()
        : null;
    final subEmail = controller?.subscription.value.email;
    if (subEmail != null && subEmail.isNotEmpty) {
      _emailController.text = subEmail;
    } else {
      try {
        final authEmail = FirebaseAuth.instance.currentUser?.email;
        if (authEmail != null && authEmail.isNotEmpty) {
          _emailController.text = authEmail;
        }
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<SubscriptionController>();
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AppScaffold(
      title: 'Subscription',
      showBackButton: true,
      body: Obx(() {
        final sub = controller.subscription.value;
        final isOwner = sub.isOwnerVip;
        final isTrial = !isOwner && sub.isTrial;
        final isPaid = isOwner || (sub.isPremium && !isTrial);
        final isSubscribed = sub.isPremium;
        final isLoading = controller.isLoading.value;
        final isVerifying = controller.isProcessingPayment.value;
        final hasActiveRef = controller.activeReference.value.isNotEmpty;

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              children: [
                // Header Brand Section
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isOwner
                            ? [Colors.amber.shade800, Colors.amber.shade400]
                            : isTrial
                                ? [Colors.cyan.shade600, Colors.teal.shade400]
                                : [Colors.amber.shade700, Colors.amber.shade400],
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      isOwner
                          ? '👑 STREAMHUB PRO • OWNER LIFETIME VIP'
                          : isTrial
                              ? 'STREAMHUB PRO • 30-DAY VIP TRIAL'
                              : 'STREAMHUB PRO VIP',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: Colors.black,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    isOwner
                        ? '👑 Owner Lifetime VIP Active'
                        : isPaid
                            ? 'Your Premium Plan is Active'
                            : isTrial
                                ? 'Your 30-Day VIP Trial is Active'
                                : 'Unlock Unlimited IPTV Streaming',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    isPaid
                        ? 'Thank you for supporting StreamHub Pro. Your subscription is active and auto-renewing.'
                        : isTrial
                        ? 'Enjoy full access to all custom IPTV features. Subscribe anytime to keep uninterrupted access after your trial.'
                        : 'Connect your own M3U, Xtream Codes, and Stalker portals with full hardware acceleration and multi-screen support.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.textTheme.bodyMedium?.color?.withValues(
                        alpha: 0.7,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Active Subscription Status Banner
                if (isSubscribed) ...[
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: isTrial
                          ? Colors.cyan.withValues(alpha: 0.12)
                          : (sub.isAutoRenewing
                                ? Colors.green.withValues(alpha: 0.12)
                                : Colors.orange.withValues(alpha: 0.12)),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isTrial
                            ? Colors.cyan.withValues(alpha: 0.5)
                            : (sub.isAutoRenewing
                                  ? Colors.green.withValues(alpha: 0.5)
                                  : Colors.orange.withValues(alpha: 0.5)),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              isTrial
                                  ? Icons.stars_rounded
                                  : (sub.isAutoRenewing
                                        ? Icons.check_circle
                                        : Icons.pause_circle_outline),
                              color: isTrial
                                  ? Colors.cyan
                                  : (sub.isAutoRenewing
                                        ? Colors.green
                                        : Colors.orange),
                              size: 24,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                sub.planName,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: isOwner
                                      ? Colors.amber
                                      : isTrial
                                          ? Colors.cyan
                                          : (sub.isAutoRenewing
                                                ? Colors.green
                                                : Colors.orange),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    (isOwner
                                            ? Colors.amber
                                            : isTrial
                                                ? Colors.cyan
                                                : (sub.isAutoRenewing
                                                      ? Colors.green
                                                      : Colors.orange))
                                        .withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                isOwner
                                    ? '👑 OWNER VIP'
                                    : isTrial
                                        ? 'TRIAL (${sub.daysRemaining}D LEFT)'
                                        : (sub.isAutoRenewing
                                              ? 'AUTO-RENEW ON'
                                              : 'AUTO-RENEW OFF'),
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: isOwner
                                      ? Colors.amber
                                      : isTrial
                                          ? Colors.cyan
                                          : (sub.isAutoRenewing
                                                ? Colors.green
                                                : Colors.orange),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        if (sub.expiryDate != null)
                          Text(
                            isOwner
                                ? 'Permanent Lifetime Access • Unlimited playlists & features unlocked'
                                : isTrial
                                    ? 'Trial ends on: ${sub.expiryDate!.day}/${sub.expiryDate!.month}/${sub.expiryDate!.year} (${sub.daysRemaining} days remaining)'
                                    : (sub.isAutoRenewing
                                          ? 'Renews on: ${sub.expiryDate!.day}/${sub.expiryDate!.month}/${sub.expiryDate!.year} (${sub.daysRemaining} days remaining)'
                                          : 'VIP access ends on: ${sub.expiryDate!.day}/${sub.expiryDate!.month}/${sub.expiryDate!.year} (${sub.daysRemaining} days remaining)'),
                            style: theme.textTheme.bodySmall,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Premium Plan Card
                if (!isPaid) ...[
                  SubscriptionPlanCard(
                    title: AppConstants.paystackDefaultPlanName,
                    price: '₦1,000 / mo',
                    subtitle:
                        'Full access to all IPTV standards & advanced features',
                    isSelected: true,
                    onTap: () {},
                  ),
                  const SizedBox(height: 24),

                  // Email Input Field
                  Text(
                    'Billing Email',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      hintText: 'Enter your email for payment receipt',
                      prefixIcon: const Icon(Icons.email_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: colorScheme.surface.withValues(alpha: 0.5),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Benefits Section
                Text(
                  'What\'s Included in Premium',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                const SubscriptionBenefitTile(
                  icon: Icons.playlist_play_rounded,
                  title: 'Unlimited Custom IPTV Providers',
                  description:
                      'Add unlimited M3U playlists, Xtream Codes credentials, and Stalker MAC portals.',
                ),
                const SubscriptionBenefitTile(
                  icon: Icons.layers_rounded,
                  title: 'Multi-Screen & Multi-View',
                  description:
                      'Watch multiple live streams simultaneously on your TV or tablet.',
                ),
                const SubscriptionBenefitTile(
                  icon: Icons.calendar_today_rounded,
                  title: 'Complete EPG & TV Guide Timeline',
                  description:
                      'Full program schedule grids, channel timelines, and catchup tv.',
                ),
                const SubscriptionBenefitTile(
                  icon: Icons.download_rounded,
                  title: 'Offline VOD Downloads',
                  description:
                      'Save your movies and TV series episodes directly to local storage.',
                ),
                const SubscriptionBenefitTile(
                  icon: Icons.sync_rounded,
                  title: 'Cross-Device Cloud Sync',
                  description:
                      'Seamlessly synchronize favorites, history, and settings across your devices.',
                ),
                const SizedBox(height: 24),

                // Action Buttons
                if (!isPaid) ...[
                  if (hasActiveRef) ...[
                    TvFocusable(
                      onTap: isVerifying
                          ? null
                          : () => controller.verifyPayment(),
                      scale: 1.02,
                      borderRadius: BorderRadius.circular(12),
                      descendantsAreFocusable: false,
                      child: ElevatedButton.icon(
                        onPressed: isVerifying
                            ? null
                            : () => controller.verifyPayment(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: isVerifying
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.verified),
                        label: Text(
                          isVerifying
                              ? 'Verifying with Paystack...'
                              : 'Verify Completed Payment',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  TvFocusable(
                    onTap: isLoading
                        ? null
                        : () {
                            controller.initiatePaystackCheckout(
                              email: _emailController.text,
                            );
                          },
                    scale: 1.02,
                    borderRadius: BorderRadius.circular(12),
                    descendantsAreFocusable: false,
                    child: ElevatedButton(
                      onPressed: isLoading
                          ? null
                          : () {
                              controller.initiatePaystackCheckout(
                                email: _emailController.text,
                              );
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        foregroundColor: colorScheme.onPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: isLoading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              isTrial
                                  ? 'Upgrade to Full Plan (₦1,000 / mo)'
                                  : 'Subscribe with Paystack (₦1,000 / mo)',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                    ),
                  ),
                ] else ...[
                  Row(
                    children: [
                      Expanded(
                        child: TvFocusable(
                          onTap: () => controller.refreshStatus(),
                          scale: 1.02,
                          borderRadius: BorderRadius.circular(12),
                          descendantsAreFocusable: false,
                          child: OutlinedButton.icon(
                            onPressed: () => controller.refreshStatus(),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: const Icon(Icons.refresh, size: 18),
                            label: const FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text('Refresh Status'),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TvFocusable(
                          onTap: () => controller.openManageBilling(),
                          scale: 1.02,
                          borderRadius: BorderRadius.circular(12),
                          descendantsAreFocusable: false,
                          child: OutlinedButton.icon(
                            onPressed: () => controller.openManageBilling(),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: const Icon(Icons.receipt_long, size: 18),
                            label: const FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text('Manage Billing'),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (sub.isAutoRenewing && !isOwner) ...[
                    TvFocusable(
                      onTap: controller.isCancelling.value
                          ? null
                          : () => _showCancelConfirmationDialog(
                              context,
                              controller,
                              sub,
                            ),
                      scale: 1.02,
                      borderRadius: BorderRadius.circular(12),
                      descendantsAreFocusable: false,
                      child: OutlinedButton.icon(
                        onPressed: controller.isCancelling.value
                            ? null
                            : () => _showCancelConfirmationDialog(
                                context,
                                controller,
                                sub,
                              ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.redAccent,
                          side: BorderSide(
                            color: Colors.redAccent.withValues(alpha: 0.5),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: controller.isCancelling.value
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.redAccent,
                                ),
                              )
                            : const Icon(Icons.cancel_outlined, size: 20),
                        label: const Text(
                          'Cancel Subscription',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.orange.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.info_outline,
                            color: Colors.orange,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Auto-renewal is cancelled. Your VIP benefits remain active until your expiry date.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.orange.shade300,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
                const SizedBox(height: 20),

                // Security Note
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.lock_outline,
                          size: 14,
                          color: theme.textTheme.bodySmall?.color?.withValues(
                            alpha: 0.5,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'Secured by Paystack • Cancel anytime • Free Live TV always remains free',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: 12,
                              color: theme.textTheme.bodySmall?.color
                                  ?.withValues(alpha: 0.6),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // Developer / Testing Mode Card
                _buildTestModeCard(context),
                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildTestModeCard(BuildContext context) {
    if (!Get.isRegistered<FreeTvSlotService>()) return const SizedBox.shrink();
    final slotService = Get.find<FreeTvSlotService>();

    return Obx(() {
      final isSimulating = slotService.simulateFreeTier.value;

      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSimulating
                ? Colors.cyanAccent.withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.12),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.science_outlined,
                  size: 20,
                  color: isSimulating ? Colors.cyanAccent : Colors.white70,
                ),
                const SizedBox(width: 8),
                Text(
                  'Developer / Testing Mode',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isSimulating ? Colors.cyanAccent : Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Simulate that your 30-day VIP trial has expired to test the 10 Free Channel Pass, channel card VIP locks, and channel swapping flow.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.6),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isSimulating
                      ? 'Active: Free Tier (Gating Enabled)'
                      : 'Inactive: 30-Day VIP Active',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isSimulating ? Colors.cyanAccent : Colors.white70,
                  ),
                ),
                Switch.adaptive(
                  value: isSimulating,
                  activeThumbColor: Colors.cyanAccent,
                  onChanged: (val) {
                    slotService.simulateFreeTier.value = val;
                  },
                ),
              ],
            ),
          ],
        ),
      );
    });
  }

  void _showCancelConfirmationDialog(
    BuildContext context,
    SubscriptionController controller,
    dynamic sub,
  ) {
    final theme = Theme.of(context);
    final expiryStr = sub.expiryDate != null
        ? '${sub.expiryDate!.day}/${sub.expiryDate!.month}/${sub.expiryDate!.year}'
        : 'the end of your billing cycle';

    Get.dialog(
      AlertDialog(
        backgroundColor: theme.scaffoldBackgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orangeAccent.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.warning_amber_rounded,
                color: Colors.orangeAccent,
                size: 28,
              ),
            ),
            const SizedBox(height: 12),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                'Cancel Auto-Renewal?',
                maxLines: 1,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to cancel auto-renewal?\n\nYou will continue to enjoy unlimited VIP access until $expiryStr, and your card will not be charged again.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.85),
          ),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        actions: [
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                TvFocusable(
                  onTap: () => Get.back(),
                  scale: 1.04,
                  borderRadius: BorderRadius.circular(12),
                  descendantsAreFocusable: false,
                  child: OutlinedButton(
                    onPressed: () => Get.back(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Keep VIP',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TvFocusable(
                  onTap: () {
                    Get.back();
                    controller.cancelSubscription();
                  },
                  scale: 1.04,
                  borderRadius: BorderRadius.circular(12),
                  descendantsAreFocusable: false,
                  child: ElevatedButton(
                    onPressed: () {
                      Get.back();
                      controller.cancelSubscription();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Cancel Subscription',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
