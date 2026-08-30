import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/tv_focusable.dart';
import './constants/auth_constants.dart';
import 'auth_controller.dart';
import '../../../core/logging/logging_service.dart';

class RegisterPage extends GetView<AuthController> {
  RegisterPage({super.key});

  final fullNameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  final acceptedTerms = RxBool(false);
  final password = ''.obs;

  double _calculatePasswordStrength(String password) {
    if (password.isEmpty) return 0.0;
    double strength = 0.0;
    if (password.length >= 6) strength += 0.25;
    if (password.length >= 10) strength += 0.25;
    if (password.contains(RegExp(r'[A-Z]'))) strength += 0.25;
    if (password.contains(RegExp(r'[0-9]'))) strength += 0.25;
    if (password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) strength += 0.25;
    return strength.clamp(0.0, 1.0);
  }

  String _getPasswordStrengthLabel(double strength) {
    if (strength < AuthConstants.passwordStrengthFair) return 'Weak';
    if (strength < AuthConstants.passwordStrengthGood) return 'Fair';
    if (strength < AuthConstants.passwordStrengthStrong) return 'Good';
    return 'Strong';
  }

  Color _getPasswordStrengthColor(double strength, ColorScheme colorScheme) {
    if (strength < AuthConstants.passwordStrengthFair) return colorScheme.error;
    if (strength < AuthConstants.passwordStrengthGood) {
      return AppColors.darkWarning;
    }
    if (strength < AuthConstants.passwordStrengthStrong) {
      return AppColors.darkSecondary;
    }
    return AppColors.darkSuccess;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    emailController.text = controller.lastEmail.value;

    return AppScaffold(
      title: 'Create Account',
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
                        'Get Started',
                        style: AppTypography.getHeadline(
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                  AppSpacing.heightLG,
                  Obx(
                    () => Column(
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
                                Icon(
                                  AppIcons.error,
                                  color: colorScheme.error,
                                  size: 18.0,
                                ),
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
                          labelText: 'Full Name',
                          hintText: 'John Doe',
                          controller: fullNameController,
                          keyboardType: TextInputType.name,
                          prefixIcon: Icons.person_outline,
                          textInputAction: TextInputAction.next,
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
                        Obx(
                          () {
                            final strength = _calculatePasswordStrength(
                              password.value,
                            );
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                AppTextField(
                                  labelText: 'Password',
                                  hintText: 'Create a strong password',
                                  controller: passwordController,
                                  isPassword: true,
                                  prefixIcon: Icons.lock_outline,
                                  textInputAction: TextInputAction.next,
                                  onChanged: (_) {
                                    password.value = passwordController.text;
                                    controller.clearError();
                                  },
                                ),
                                AppSpacing.heightXS,
                                if (password.value.isNotEmpty)
                                  Column(
                                    children: [
                                      Container(
                                        height: 4.0,
                                        decoration: BoxDecoration(
                                          borderRadius: AppRadius.pill,
                                          color: colorScheme
                                              .surfaceContainerHighest
                                              .withValues(alpha: 0.3),
                                        ),
                                        child: FractionallySizedBox(
                                          widthFactor: strength,
                                          alignment: Alignment.centerLeft,
                                          child: Container(
                                            decoration: BoxDecoration(
                                              borderRadius: AppRadius.pill,
                                              color: _getPasswordStrengthColor(
                                                strength,
                                                colorScheme,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      AppSpacing.heightXXS,
                                      Align(
                                        alignment: Alignment.centerLeft,
                                        child: Text(
                                          _getPasswordStrengthLabel(strength),
                                          style: AppTypography.getCaption(
                                            color: _getPasswordStrengthColor(
                                              strength,
                                              colorScheme,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                            ],
                          );
                        }),
                        AppSpacing.heightMD,
                        AppTextField(
                          labelText: 'Confirm Password',
                          hintText: 'Repeat your password',
                          controller: confirmPasswordController,
                          isPassword: true,
                          prefixIcon: Icons.lock_outline,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) {
                            if (acceptedTerms.value) {
                              controller.registerWithEmail(
                                fullName: fullNameController.text,
                                email: emailController.text,
                                password: password.value,
                                confirmPassword: confirmPasswordController.text,
                                acceptedTerms: acceptedTerms.value,
                              );
                            }
                          },
                        ),
                        AppSpacing.heightMD,
                        Obx(
                          () => TvFocusable(
                            onTap: () {
                              acceptedTerms.value = !acceptedTerms.value;
                            },
                            borderRadius: AppRadius.medium,
                            scale: 1.0,
                            child: Row(
                              children: [
                                Checkbox(
                                  value: acceptedTerms.value,
                                  onChanged: (value) {
                                    acceptedTerms.value = value ?? false;
                                  },
                                ),
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () {
                                      acceptedTerms.value =
                                          !acceptedTerms.value;
                                    },
                                    child: RichText(
                                      text: TextSpan(
                                        style: AppTypography.getCaption(
                                          color: colorScheme.onSurface,
                                        ),
                                        children: [
                                          const TextSpan(text: 'I agree to the '),
                                          TextSpan(
                                            text: 'Terms of Service',
                                            style: const TextStyle(
                                              color: AppColors.darkPrimary,
                                              decoration:
                                                  TextDecoration.underline,
                                            ),
                                          ),
                                          const TextSpan(text: ' and '),
                                          TextSpan(
                                            text: 'Privacy Policy',
                                            style: const TextStyle(
                                              color: AppColors.darkPrimary,
                                              decoration:
                                                  TextDecoration.underline,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        AppSpacing.heightLG,
                        Obx(
                          () => AppButton.primary(
                            text: 'Create Account',
                            isLoading: controller.isLoading.value,
                            onPressed: acceptedTerms.value
                                ? () async {
                                    try {
                                      await controller.registerWithEmail(
                                        fullName: fullNameController.text,
                                        email: emailController.text,
                                        password: password.value,
                                        confirmPassword:
                                            confirmPasswordController.text,
                                        acceptedTerms: acceptedTerms.value,
                                      );
                                    } catch (e, st) {
                                      // Extra safety: log unexpected errors that
                                      // may escape controller handling.
                                      try {
                                        // Delay lookup to avoid initialization order issues
                                        // when this widget is created early in app lifecycle.
                                        final LoggingService? logger =
                                            Get.isRegistered<LoggingService>()
                                            ? Get.find<LoggingService>()
                                            : null;
                                        logger?.error(
                                          'Unexpected error during registration',
                                          tag: 'RegisterPage',
                                          error: e,
                                          stackTrace: st,
                                        );
                                      } catch (_) {}
                                      // Surface a user-friendly message
                                      Get.snackbar(
                                        'Registration Error',
                                        e.toString(),
                                        snackPosition: SnackPosition.BOTTOM,
                                      );
                                    }
                                  }
                                : null,
                          ),
                        ),
                        AppSpacing.heightSM,
                        Obx(
                          () => AppButton.secondary(
                            text: 'Sign in with Google',
                            icon: Icons.g_mobiledata_outlined,
                            isLoading: controller.isLoading.value,
                            onPressed: controller.loginWithGoogle,
                          ),
                        ),
                        AppSpacing.heightLG,
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Already have an account? ',
                              style: AppTypography.getCaption(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            TvFocusable(
                              onTap: () => Get.toNamed(AppRoutes.login),
                              borderRadius: AppRadius.medium,
                              scale: 1.05,
                              child: TextButton(
                                onPressed: null,
                                child: Text(
                                  'Sign In',
                                  style: AppTypography.getCaption(
                                    color: colorScheme.primary,
                                  ).copyWith(fontWeight: FontWeight.w600),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
