import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/tv_focusable.dart';
import 'auth_controller.dart';

class EmailVerificationPage extends GetView<AuthController> {
  const EmailVerificationPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AppScaffold(
      title: 'Verify Email',
      showNavigation: false,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420.0),
            child: AppCard(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      TvFocusable(
                        onTap: () => Get.back(),
                        scale: 1.0,
                        borderRadius: AppRadius.medium,
                        child: const IconButton(
                          icon: Icon(AppIcons.back),
                          onPressed: null,
                        ),
                      ),
                      AppSpacing.widthSM,
                      Text(
                        'Verify Your Email',
                        style: AppTypography.getHeadline(color: colorScheme.onSurface),
                      ),
                    ],
                  ),
                  AppSpacing.heightLG,
                  Icon(
                    Icons.mark_email_unread_outlined,
                    size: 64.0,
                    color: colorScheme.primary,
                  ),
                  AppSpacing.heightLG,
                  Text(
                    'We sent a verification link to your email address.',
                    textAlign: TextAlign.center,
                    style: AppTypography.getBody(color: colorScheme.onSurfaceVariant),
                  ),
                  AppSpacing.heightMD,
                  Text(
                    'Please check your inbox and click the link to verify your account.',
                    textAlign: TextAlign.center,
                    style: AppTypography.getCaption(color: colorScheme.onSurfaceVariant),
                  ),
                  AppSpacing.heightXL,
                  Obx(() => Column(
                        children: [
                          if (controller.errorMessage.value.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.all(AppSpacing.md),
                              decoration: BoxDecoration(
                                color: colorScheme.error.withValues(alpha: 0.1),
                                borderRadius: AppRadius.medium,
                                border: Border.all(
                                  color: colorScheme.error.withValues(alpha: 0.3),
                                  width: 1.0,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(AppIcons.error,
                                      color: colorScheme.error, size: 18.0),
                                  AppSpacing.widthSM,
                                  Expanded(
                                    child: Text(
                                      controller.errorMessage.value,
                                      style: AppTypography.getCaption(
                                        color: colorScheme.error,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          AppSpacing.heightMD,
                          AppButton.primary(
                            text: 'Resend Verification Email',
                            isLoading: controller.isLoading.value,
                            onPressed: controller.sendVerificationEmail,
                          ),
                          AppSpacing.heightSM,
                          AppButton.text(
                            text: 'I\'ve Verified My Email',
                            onPressed: controller.continueAfterVerification,
                          ),
                          AppSpacing.heightLG,
                          TvFocusable(
                            onTap: () => Get.offAllNamed(AppRoutes.login),
                            borderRadius: AppRadius.medium,
                            scale: 1.05,
                            child: TextButton(
                              onPressed: null,
                              child: Text(
                                'Back to Login',
                                style: AppTypography.getCaption(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ),
                        ],
                      )),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
