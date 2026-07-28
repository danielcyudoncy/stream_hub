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

class CompleteProfilePage extends GetView<AuthController> {
  const CompleteProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final displayNameController = TextEditingController();

    return AppScaffold(
      title: 'Complete Profile',
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
                        'Complete Your Profile',
                        style: AppTypography.getHeadline(color: colorScheme.onSurface),
                      ),
                    ],
                  ),
                  AppSpacing.heightLG,
                  Text(
                    'Tell us a bit more about yourself to get started.',
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
                            labelText: 'Display Name',
                            hintText: 'How should we call you?',
                            controller: displayNameController,
                            keyboardType: TextInputType.name,
                            prefixIcon: Icons.person_outline,
                            onChanged: (_) => controller.clearError(),
                          ),
                          AppSpacing.heightLG,
                          Obx(() => AppButton.primary(
                                text: 'Continue',
                                isLoading: controller.isLoading.value,
                                onPressed: () {
                                  Get.offAllNamed(AppRoutes.dashboard);
                                },
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
