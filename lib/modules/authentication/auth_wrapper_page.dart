import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/app_button.dart';
import './constants/auth_constants.dart';
import './account_loading_page.dart';
import './complete_profile_page.dart';
import 'auth_controller.dart';

class AuthWrapperPage extends GetView<AuthController> {
  const AuthWrapperPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Obx(() {
      if (controller.isLoading.value) {
        return const AccountLoadingPage();
      }
      if (controller.isAuthenticated.value && controller.currentUser.value != null) {
        return const CompleteProfilePage();
      }
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0F172A), Color(0xFF020617)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: AuthConstants.primaryGradient,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.darkPrimary.withValues(alpha: 0.5),
                            blurRadius: 30.0,
                            spreadRadius: 2.0,
                          ),
                        ],
                      ),
                      child: const Icon(
                        AppIcons.play,
                        size: 48.0,
                        color: AppColors.darkTextPrimary,
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
                    SizedBox(
                      width: double.infinity,
                      child: AppButton.primary(
                        text: 'Sign In',
                        onPressed: () => Get.toNamed(AppRoutes.login),
                      ),
                    ),
                    AppSpacing.heightSM,
                    SizedBox(
                      width: double.infinity,
                      child: AppButton.secondary(
                        text: 'Create Account',
                        onPressed: () => Get.toNamed(AppRoutes.register),
                      ),
                    ),
                    AppSpacing.heightLG,
                    TextButton(
                      onPressed: () => Get.toNamed(AppRoutes.login, arguments: {'anonymous': true}),
                      child: Text(
                        'Continue as Guest',
                        style: AppTypography.getLabel(color: colorScheme.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    });
  }
}
