import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/tv_focusable.dart';
import 'auth_controller.dart';

class ForgotPasswordPage extends GetView<AuthController> {
  ForgotPasswordPage({super.key});

  final emailController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AppScaffold(
      title: 'Reset Password',
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
                        'Forgot Password',
                        style: AppTypography.getHeadline(color: colorScheme.onSurface),
                      ),
                    ],
                  ),
                  AppSpacing.heightLG,
                  Text(
                    'Enter your email address and we\'ll send you a link to reset your password.',
                    style: AppTypography.getBody(color: colorScheme.onSurfaceVariant),
                  ),
                  AppSpacing.heightLG,
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
                          AppTextField(
                            labelText: 'Email Address',
                            hintText: 'user@example.com',
                            controller: emailController,
                            keyboardType: TextInputType.emailAddress,
                            prefixIcon: Icons.email_outlined,
                            onChanged: (_) => controller.clearError(),
                          ),
                          AppSpacing.heightLG,
                          Obx(() => AppButton.primary(
                                text: 'Send Reset Email',
                                isLoading: controller.isLoading.value,
                                onPressed: () => controller.sendPasswordReset(
                                  emailController.text,
                                ),
                              )),
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
