import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:stream_hub/core/constants/app_constants.dart';
import 'package:stream_hub/core/theme/app_spacing.dart';
import 'package:stream_hub/core/theme/app_typography.dart';
import 'package:stream_hub/core/utils/validators.dart';
import 'package:stream_hub/shared/widgets/app_button.dart';
import 'package:stream_hub/shared/widgets/app_card.dart';
import 'package:stream_hub/shared/widgets/app_scaffold.dart';
import 'package:stream_hub/shared/widgets/section_header.dart';
import 'package:stream_hub/modules/provider_manager/models/provider_enums.dart';
import 'package:stream_hub/modules/provider_manager/models/provider_model.dart';
import 'provider_manager_controller.dart';

class ProviderFormPage extends GetView<ProviderManagerController> {
  final ProviderModel? provider;

  const ProviderFormPage({super.key, this.provider});

  bool get isEditing => provider != null;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isEditing = this.isEditing;

    final nameController = TextEditingController(text: provider?.name ?? '');
    final serverUrlController = TextEditingController(text: provider?.serverUrl ?? '');
    final usernameController = TextEditingController(text: provider?.username ?? '');
    final passwordController = TextEditingController(text: provider?.password ?? '');
    final macController = TextEditingController(text: provider?.macAddress ?? '');
    final xmltvController = TextEditingController(text: provider?.xmltvUrl ?? '');
    final notesController = TextEditingController(text: provider?.notes ?? '');

    final selectedType = (provider?.providerType ?? ProviderType.m3u).obs;

    return AppScaffold(
      title: isEditing ? 'Edit Provider' : 'Add Provider',
      body: Obx(() {
        final type = selectedType.value;
        return Form(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              SectionHeader(
                title: isEditing ? 'Edit Provider Details' : 'New Provider',
                subtitle: isEditing ? 'Update provider configuration' : 'Configure a new IPTV provider',
              ),
              AppSpacing.heightXS,
              AppCard(
                child: Column(
                  children: [
                    TextFormField(
                      controller: nameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(labelText: 'Provider Name', hintText: 'Enter a memorable name'),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Provider name is required.';
                        }
                        if (value.trim().length < AppConstants.minProviderNameLength) {
                          return 'Name must be at least ${AppConstants.minProviderNameLength} characters.';
                        }
                        if (value.trim().length > AppConstants.maxProviderNameLength) {
                          return 'Name must be less than ${AppConstants.maxProviderNameLength} characters.';
                        }
                        return null;
                      },
                    ),
                    AppSpacing.heightMD,
                    Text('Provider Type', style: AppTypography.getLabel(color: colorScheme.onSurface)),
                    AppSpacing.heightXS,
                    Wrap(
                      spacing: AppSpacing.xs,
                      children: ProviderType.values.map((pt) {
                        final isSelected = type == pt;
                        return ChoiceChip(
                          label: Text(pt.displayName),
                          selected: isSelected,
                          onSelected: (selected) {
                            if (selected) selectedType.value = pt;
                          },
                        );
                      }).toList(),
                    ),
                    AppSpacing.heightMD,
                    if (type != ProviderType.xmltv) ...[
                      TextFormField(
                        controller: serverUrlController,
                        decoration: const InputDecoration(labelText: 'Server URL', hintText: 'https://example.com'),
                        keyboardType: TextInputType.url,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) return null;
                          if (!Validators.isValidUrl(value.trim())) {
                            return 'Please enter a valid URL.';
                          }
                          return null;
                        },
                      ),
                      AppSpacing.heightMD,
                    ],
                    if (type == ProviderType.xtream || type == ProviderType.stalker) ...[
                      TextFormField(
                        controller: usernameController,
                        decoration: const InputDecoration(labelText: 'Username', hintText: 'Enter username'),
                      ),
                      AppSpacing.heightMD,
                      TextFormField(
                        controller: passwordController,
                        decoration: const InputDecoration(labelText: 'Password', hintText: 'Enter password'),
                        obscureText: true,
                      ),
                      AppSpacing.heightMD,
                    ],
                    if (type == ProviderType.stalker) ...[
                      TextFormField(
                        controller: macController,
                        decoration: const InputDecoration(labelText: 'MAC Address', hintText: 'Required for Stalker Portal'),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) return null;
                          if (!Validators.isValidMacAddress(value.trim())) {
                            return 'Please enter a valid MAC address.';
                          }
                          return null;
                        },
                      ),
                      AppSpacing.heightMD,
                    ],
                    if (type == ProviderType.xmltv) ...[
                      TextFormField(
                        controller: xmltvController,
                        decoration: const InputDecoration(labelText: 'XMLTV URL', hintText: 'https://example.com/guide.xml'),
                        keyboardType: TextInputType.url,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) return null;
                          if (!Validators.isValidUrl(value.trim())) {
                            return 'Please enter a valid URL.';
                          }
                          return null;
                        },
                      ),
                      AppSpacing.heightMD,
                    ],
                    TextFormField(
                      controller: notesController,
                      decoration: const InputDecoration(labelText: 'Notes', hintText: 'Optional notes about this provider'),
                      maxLines: 3,
                      maxLength: AppConstants.maxNotesLength,
                    ),
                  ],
                ),
              ),
              AppSpacing.heightLG,
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Get.back(),
                      child: const Text('Cancel'),
                    ),
                  ),
                  AppSpacing.widthMD,
                  Expanded(
                    child: AppButton(
                      text: isEditing ? 'Save Changes' : 'Add Provider',
                      onPressed: () {
                        final form = Form.of(context);
                        if (form.validate()) {
                          final trimmedName = nameController.text.trim();
                          final trimmedServerUrl = serverUrlController.text.trim().isEmpty ? null : serverUrlController.text.trim();
                          final trimmedUsername = usernameController.text.trim().isEmpty ? null : usernameController.text.trim();
                          final trimmedPassword = passwordController.text.trim().isEmpty ? null : passwordController.text.trim();
                          final trimmedMac = macController.text.trim().isEmpty ? null : macController.text.trim();
                          final trimmedXmltv = xmltvController.text.trim().isEmpty ? null : xmltvController.text.trim();
                          final trimmedNotes = notesController.text.trim().isEmpty ? null : notesController.text.trim();

                          if (isEditing) {
                            controller.updateProvider(provider!.copyWith(
                              name: trimmedName,
                              providerType: selectedType.value,
                              serverUrl: trimmedServerUrl,
                              username: trimmedUsername,
                              password: trimmedPassword,
                              macAddress: trimmedMac,
                              xmltvUrl: trimmedXmltv,
                              notes: trimmedNotes,
                            ));
                          } else {
                            final newProvider = ProviderModel(
                              id: 'provider_${DateTime.now().millisecondsSinceEpoch}_${_randomSuffix()}',
                              name: trimmedName,
                              providerType: selectedType.value,
                              serverUrl: trimmedServerUrl,
                              username: trimmedUsername,
                              password: trimmedPassword,
                              macAddress: trimmedMac,
                              xmltvUrl: trimmedXmltv,
                              notes: trimmedNotes,
                              createdAt: DateTime.now(),
                              updatedAt: DateTime.now(),
                              status: ProviderStatus.inactive,
                            );
                            controller.createProvider(newProvider);
                          }
                          Get.back();
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      }),
    );
  }

  String _randomSuffix() {
    final random = DateTime.now().microsecond % 10000;
    return random.toString().padLeft(4, '0');
  }
}
