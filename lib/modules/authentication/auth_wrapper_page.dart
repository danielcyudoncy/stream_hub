import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/helpers/platform_helper.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/tv_focusable.dart';
import './account_loading_page.dart';
import './complete_profile_page.dart';
import './models/user_model.dart';
import 'auth_controller.dart';

class AuthWrapperPage extends GetView<AuthController> {
  const AuthWrapperPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isTV = PlatformHelper.isTV;

    return Obx(() {
      if (controller.isLoading.value) {
        return AccountLoadingPage();
      }
      if (controller.isAuthenticated.value && controller.currentUser.value != null) {
        final user = controller.currentUser.value!;
        final displayName = user.displayName;
        final isAnonymous = user.provider == AuthProvider.anonymous || user.email.isEmpty;
        if ((displayName != null && displayName.isNotEmpty) || isAnonymous) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Get.offAllNamed(AppRoutes.home);
          });
          return AccountLoadingPage();
        }
        return CompleteProfilePage();
      }
      return Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                colorScheme.surface,
                colorScheme.surfaceContainerHighest,
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420.0),
                child: FocusTraversalGroup(
                  policy: WidgetOrderTraversalPolicy(),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 120.0,
                        height: 120.0,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: colorScheme.primary.withValues(alpha: 0.35),
                              blurRadius: 36.0,
                              spreadRadius: 4.0,
                            ),
                          ],
                        ),
                        child: Image.asset(
                          AppAssets.logo,
                          fit: BoxFit.contain,
                        ),
                      ),
                      AppSpacing.heightLG,
                      Text(
                        'StreamHub Pro',
                        style: AppTypography.getDisplay(color: colorScheme.onSurface),
                      ),
                      AppSpacing.heightXS,
                      Text(
                        'Premium IPTV Client',
                        style: AppTypography.getLabel(color: colorScheme.onSurfaceVariant),
                      ),
                      AppSpacing.heightXXL,
                      AppButton.primary(
                        autofocus: isTV,
                        text: 'Sign In',
                        onPressed: () => Get.toNamed(AppRoutes.login),
                      ),
                      AppSpacing.heightSM,
                      AppButton.secondary(
                        text: 'Create Account',
                        onPressed: () => Get.toNamed(AppRoutes.register),
                      ),
                      AppSpacing.heightLG,
                      TvFocusable(
                        onTap: () => Get.toNamed(
                          AppRoutes.login,
                          arguments: {'anonymous': true},
                        ),
                        borderRadius: AppRadius.medium,
                        scale: 1.05,
                        descendantsAreFocusable: false,
                        child: TextButton(
                          onPressed: () => Get.toNamed(
                            AppRoutes.login,
                            arguments: {'anonymous': true},
                          ),
                          child: Text(
                            'Continue as Guest',
                            style: AppTypography.getLabel(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    });
  }
}
