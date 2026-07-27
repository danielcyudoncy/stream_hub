import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/app_scaffold.dart';
import '../../shared/widgets/app_text_field.dart';
import 'auth_controller.dart';

class AuthPage extends GetView<AuthController> {
  const AuthPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    final emailController = TextEditingController();
    final passwordController = TextEditingController();

    return AppScaffold(
      title: 'Authentication',
      showNavigation: false, // Don't show sidebar navigation on auth screen
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
                        onPressed: () => Get.offAllNamed(AppRoutes.dashboard),
                      ),
                      AppSpacing.widthSM,
                      Text(
                        'Cloud Sync Login',
                        style: AppTypography.getHeadline(color: colorScheme.onSurface),
                      ),
                    ],
                  ),
                  AppSpacing.heightLG,
                  
                  AppTextField(
                    labelText: 'Email Address',
                    hintText: 'user@example.com',
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    prefixIcon: Icons.email_outlined,
                  ),
                  AppSpacing.heightMD,
                  
                  AppTextField(
                    labelText: 'Password',
                    hintText: 'Enter your password',
                    controller: passwordController,
                    isPassword: true,
                    prefixIcon: Icons.lock_outline,
                    textInputAction: TextInputAction.done,
                  ),
                  AppSpacing.heightXL,
                  
                  Obx(() => AppButton(
                    text: 'Sign In',
                    isLoading: controller.isLoading.value,
                    onPressed: () {
                      controller.login(emailController.text, passwordController.text);
                    },
                  )),
                  AppSpacing.heightSM,
                  
                  AppButton.text(
                    text: 'Back to Dashboard',
                    onPressed: () => Get.offAllNamed(AppRoutes.dashboard),
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
