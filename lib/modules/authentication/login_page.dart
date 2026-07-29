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
import '../../../shared/widgets/app_text_field.dart';
import 'auth_controller.dart';

class LoginPage extends GetView<AuthController> {
  LoginPage({super.key});

  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final arguments = Get.arguments as Map<String, dynamic>?;
    final isAnonymousMode = arguments?['anonymous'] == true;

    if (isAnonymousMode && !controller.hasAttemptedAnonymousLogin.value) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        controller.loginAnonymously();
      });
    }

    emailController.text = controller.lastEmail.value;

    return AppScaffold(
      title: 'Sign In',
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
                      IconButton(
                        icon: const Icon(AppIcons.back),
                        onPressed: () => Get.back(),
                      ),
                      AppSpacing.widthSM,
                      Text(
                        'Welcome Back',
                        style: AppTypography.getHeadline(color: colorScheme.onSurface),
                      ),
                    ],
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
                          AppSpacing.heightMD,
                          AppTextField(
                            labelText: 'Password',
                            hintText: 'Enter your password',
                            controller: passwordController,
                            isPassword: true,
                            prefixIcon: Icons.lock_outline,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => controller.loginWithEmail(
                              emailController.text,
                              passwordController.text,
                            ),
                          ),
                          AppSpacing.heightSM,
                          Row(
                            children: [
                              Obx(() => Checkbox(
                                    value: controller.rememberMe.value,
                                    onChanged: (value) {
                                      controller.rememberMe.value = value ?? false;
                                    },
                                  )),
                              Text(
                                'Remember Me',
                                style: AppTypography.getCaption(
                                  color: colorScheme.onSurface,
                                ),
                              ),
                              const Spacer(),
                              TextButton(
                                onPressed: () => Get.toNamed(AppRoutes.forgotPassword),
                                child: Text(
                                  'Forgot Password?',
                                  style: AppTypography.getCaption(
                                    color: colorScheme.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          AppSpacing.heightLG,
                          Obx(() => AppButton.primary(
                                text: 'Sign In',
                                isLoading: controller.isLoading.value,
                                onPressed: () => controller.loginWithEmail(
                                  emailController.text,
                                  passwordController.text,
                                ),
                              )),
                          AppSpacing.heightSM,
                          AppButton.text(
                            text: 'Continue as Guest',
                            onPressed: () => controller.loginAnonymously(),
                          ),
                          AppSpacing.heightMD,
                          Row(
                            children: [
                              Expanded(
                                child: Divider(
                                  color: colorScheme.outline.withValues(alpha: 0.2),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.md,
                                ),
                                child: Text(
                                  'OR',
                                  style: AppTypography.getCaption(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Divider(
                                  color: colorScheme.outline.withValues(alpha: 0.2),
                                ),
                              ),
                            ],
                          ),
                          AppSpacing.heightMD,
                          Obx(() => AppButton.secondary(
                                text: 'Sign in with Google',
                                icon: Icons.g_mobiledata_outlined,
                                isLoading: controller.isLoading.value,
                                onPressed: controller.loginWithGoogle,
                              )),
                          AppSpacing.heightLG,
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "Don't have an account? ",
                                style: AppTypography.getCaption(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                              TextButton(
                                onPressed: () => Get.toNamed(AppRoutes.register),
                                child: Text(
                                  'Sign Up',
                                  style: AppTypography.getCaption(
                                    color: colorScheme.primary,
                                  ).copyWith(fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
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
