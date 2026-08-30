import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:stream_hub/core/constants/app_constants.dart';
import 'package:stream_hub/core/theme/app_icons.dart';
import 'package:stream_hub/core/theme/app_radius.dart';
import 'package:stream_hub/core/theme/app_spacing.dart';
import 'package:stream_hub/core/theme/app_typography.dart';
import 'package:stream_hub/core/utils/validators.dart';
import 'package:stream_hub/data/providers/xtream/xtream_url_detector.dart';
import 'package:stream_hub/shared/widgets/app_button.dart';
import 'package:stream_hub/shared/widgets/app_card.dart';
import 'package:stream_hub/shared/widgets/app_scaffold.dart';
import 'package:stream_hub/shared/widgets/section_header.dart';
import 'package:stream_hub/shared/widgets/tv_focusable.dart';
import 'package:stream_hub/modules/provider_manager/models/provider_enums.dart';
import 'package:stream_hub/modules/provider_manager/models/provider_model.dart';
import 'provider_manager_controller.dart';

class ProviderFormPage extends GetView<ProviderManagerController> {
  final ProviderModel? provider;

  ProviderFormPage({super.key, this.provider}) {
    _nameController = TextEditingController(text: provider?.name ?? '');
    _serverUrlController = TextEditingController(
      text: provider?.serverUrl ?? '',
    );
    _usernameController = TextEditingController(text: provider?.username ?? '');
    _passwordController = TextEditingController(text: provider?.password ?? '');
    _macController = TextEditingController(text: provider?.macAddress ?? '');
    _xmltvController = TextEditingController(text: provider?.xmltvUrl ?? '');
    _notesController = TextEditingController(text: provider?.notes ?? '');
    _selectedType = (provider?.providerType ?? ProviderType.m3u).obs;
    _serverUrlController.addListener(_handleServerUrlChanged);
  }

  bool get isEditing => provider != null;

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _serverUrlController;
  late final TextEditingController _usernameController;
  late final TextEditingController _passwordController;
  late final TextEditingController _macController;
  late final TextEditingController _xmltvController;
  late final TextEditingController _notesController;
  late final Rx<ProviderType> _selectedType;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isEditing = this.isEditing;

    return AppScaffold(
      title: isEditing ? 'Edit Provider' : 'Add Provider',
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg + MediaQuery.of(context).viewInsets.bottom,
          ),
          children: [
            SectionHeader(
              title: isEditing ? 'Edit Provider Details' : 'New Provider',
              subtitle: isEditing
                  ? 'Update provider configuration'
                  : 'Configure a new IPTV provider',
            ),
            AppSpacing.heightXS,
            AppCard(
              child: Column(
                children: [
                  TextFormField(
                    controller: _nameController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Provider Name',
                      hintText: 'Enter a memorable name',
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Provider name is required.';
                      }
                      if (value.trim().length <
                          AppConstants.minProviderNameLength) {
                        return 'Name must be at least ${AppConstants.minProviderNameLength} characters.';
                      }
                      if (value.trim().length >
                          AppConstants.maxProviderNameLength) {
                        return 'Name must be less than ${AppConstants.maxProviderNameLength} characters.';
                      }
                      return null;
                    },
                  ),
                  AppSpacing.heightMD,
                  Text(
                    'Provider Type',
                    style: AppTypography.getLabel(color: colorScheme.onSurface),
                  ),
                  AppSpacing.heightXS,
                  Obx(
                    () => Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      children: ProviderType.values.map((pt) {
                        final isSelected = _selectedType.value == pt;
                        return TvFocusable(
                          onTap: () => _selectedType.value = pt,
                          borderRadius: AppRadius.pill,
                          scale: 1.05,
                          child: ChoiceChip(
                            label: Text(pt.displayName),
                            selected: isSelected,
                            onSelected: (selected) {
                              if (selected) _selectedType.value = pt;
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  AppSpacing.heightMD,
                  Obx(() {
                    final type = _selectedType.value;
                    return Column(
                      children: [
                        if (type != ProviderType.xmltv) ...[
                          TextFormField(
                            controller: _serverUrlController,
                            decoration: InputDecoration(
                              labelText: 'Server URL',
                              hintText: 'https://example.com',
                              suffixIcon: _buildPasteButton(
                                _serverUrlController,
                              ),
                            ),
                            keyboardType: TextInputType.url,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Server URL is required.';
                              }
                              if (!Validators.isValidServerUrl(value.trim())) {
                                return 'Please enter a valid server URL.';
                              }
                              return null;
                            },
                          ),
                          AppSpacing.heightMD,
                        ],
                        if (type == ProviderType.xtream) ...[
                          TextFormField(
                            controller: _usernameController,
                            decoration: const InputDecoration(
                              labelText: 'Username',
                              hintText: 'Enter username',
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Username is required.';
                              }
                              return null;
                            },
                          ),
                          AppSpacing.heightMD,
                          TextFormField(
                            controller: _passwordController,
                            decoration: const InputDecoration(
                              labelText: 'Password',
                              hintText: 'Enter password',
                            ),
                            obscureText: true,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Password is required.';
                              }
                              return null;
                            },
                          ),
                          AppSpacing.heightMD,
                        ],
                        if (type == ProviderType.stalker) ...[
                          TextFormField(
                            controller: _macController,
                            decoration: const InputDecoration(
                              labelText: 'MAC Address',
                              hintText: 'Required for Stalker Portal',
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'MAC address is required.';
                              }
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
                            controller: _xmltvController,
                            decoration: InputDecoration(
                              labelText: 'XMLTV URL',
                              hintText: 'https://example.com/guide.xml',
                              suffixIcon: _buildPasteButton(_xmltvController),
                            ),
                            keyboardType: TextInputType.url,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return null;
                              }
                              if (!Validators.isValidUrl(value.trim())) {
                                return 'Please enter a valid URL.';
                              }
                              return null;
                            },
                          ),
                          AppSpacing.heightMD,
                        ],
                      ],
                    );
                  }),
                  TextFormField(
                    controller: _notesController,
                    decoration: const InputDecoration(
                      labelText: 'Notes',
                      hintText: 'Optional notes about this provider',
                    ),
                    maxLines: 3,
                    maxLength: AppConstants.maxNotesLength,
                  ),
                ],
              ),
            ),
            AppSpacing.heightLG,
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TvFocusable(
                  onTap: () => Get.back(),
                  borderRadius: AppRadius.medium,
                  scale: 1.05,
                  child: const OutlinedButton(
                    onPressed: null,
                    child: Text('Cancel'),
                  ),
                ),
                AppSpacing.widthMD,
                AppButton(
                  text: isEditing ? 'Save Changes' : 'Add Link',
                  onPressed: () {
                    if (_formKey.currentState?.validate() ?? false) {
                      final trimmedName = _nameController.text.trim();
                      final trimmedServerUrl =
                          _serverUrlController.text.trim().isEmpty
                          ? null
                          : _serverUrlController.text.trim();
                      final trimmedUsername =
                          _usernameController.text.trim().isEmpty
                          ? null
                          : _usernameController.text.trim();
                      final trimmedPassword =
                          _passwordController.text.trim().isEmpty
                          ? null
                          : _passwordController.text.trim();
                      final trimmedMac = _macController.text.trim().isEmpty
                          ? null
                          : _macController.text.trim();
                      final trimmedXmltv = _xmltvController.text.trim().isEmpty
                          ? null
                          : _xmltvController.text.trim();
                      final trimmedNotes = _notesController.text.trim().isEmpty
                          ? null
                          : _notesController.text.trim();

                      if (isEditing) {
                        controller.updateProvider(
                          provider!.copyWith(
                            name: trimmedName,
                            providerType: _selectedType.value,
                            serverUrl: trimmedServerUrl,
                            username: trimmedUsername,
                            password: trimmedPassword,
                            macAddress: trimmedMac,
                            xmltvUrl: trimmedXmltv,
                            notes: trimmedNotes,
                          ),
                        );
                      } else {
                        final newProvider = ProviderModel(
                          id: 'provider_${DateTime.now().millisecondsSinceEpoch}_${_randomSuffix()}',
                          name: trimmedName,
                          providerType: _selectedType.value,
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
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _randomSuffix() {
    final random = DateTime.now().microsecond % 10000;
    return random.toString().padLeft(4, '0');
  }

  /// When an Xtream panel export URL (e.g. `get.php?username=X&password=Y`)
  /// is entered, switch to the Xtream provider type and extract the
  /// credentials and base server URL from the link.
  void _handleServerUrlChanged() {
    final text = _serverUrlController.text;
    final parts = XtreamUrlDetector.parse(text);
    if (parts == null) return;

    _selectedType.value = ProviderType.xtream;
    final username = parts.username;
    if (username != null && _usernameController.text.trim().isEmpty) {
      _usernameController.text = username;
    }
    final password = parts.password;
    if (password != null && _passwordController.text.trim().isEmpty) {
      _passwordController.text = password;
    }
    _serverUrlController.text = parts.serverUrl;
    _serverUrlController.selection = TextSelection.collapsed(
      offset: _serverUrlController.text.length,
    );
  }

  Widget _buildPasteButton(TextEditingController controller) {
    return TvFocusable(
      borderRadius: AppRadius.small,
      scale: 1.0,
      child: IconButton(
        icon: const Icon(AppIcons.paste, size: 20),
        tooltip: 'Paste',
        onPressed: () async {
          final data = await Clipboard.getData(Clipboard.kTextPlain);
          final text = data?.text;
          if (text != null && text.trim().isNotEmpty) {
            controller.text = text.trim();
          }
        },
      ),
    );
  }
}
