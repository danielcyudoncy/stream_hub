import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:stream_hub/core/constants/app_constants.dart';
import 'package:stream_hub/core/theme/app_icons.dart';
import 'package:stream_hub/core/theme/app_radius.dart';
import 'package:stream_hub/core/theme/app_spacing.dart';
import 'package:stream_hub/core/theme/app_typography.dart';
import 'package:stream_hub/core/helpers/platform_helper.dart';
import 'package:stream_hub/core/utils/responsive_helper.dart';
import 'package:stream_hub/core/utils/validators.dart';
import 'package:stream_hub/data/providers/xtream/xtream_url_detector.dart';
import 'package:stream_hub/shared/widgets/app_button.dart';
import 'package:stream_hub/shared/widgets/app_card.dart';
import 'package:stream_hub/shared/widgets/app_scaffold.dart';
import 'package:stream_hub/shared/widgets/section_header.dart';
import 'package:stream_hub/shared/widgets/tv_focusable.dart';
import 'package:stream_hub/shared/widgets/tv_keyboard_aware_scroll_view.dart';
import 'package:stream_hub/modules/provider_manager/models/provider_enums.dart';
import 'package:stream_hub/modules/provider_manager/models/provider_model.dart';
import 'package:stream_hub/modules/provider_manager/widgets/pairing_dialog.dart';
import 'provider_manager_controller.dart';

class ProviderFormPage extends StatefulWidget {
  final ProviderModel? provider;

  const ProviderFormPage({super.key, this.provider});

  @override
  State<ProviderFormPage> createState() => _ProviderFormPageState();
}

class _ProviderFormPageState extends State<ProviderFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _serverUrlController;
  late final TextEditingController _usernameController;
  late final TextEditingController _passwordController;
  late final TextEditingController _macController;
  late final TextEditingController _xmltvController;
  late final TextEditingController _notesController;
  late final Rx<ProviderType> _selectedType;

  late final FocusNode _notesFocusNode;
  late final FocusNode _cancelFocusNode;
  late final FocusNode _scanToAddFocusNode;
  late final FocusNode _submitFocusNode;

  bool _isEditingNotes = false;

  bool get _isTv =>
      PlatformHelper.isTV ||
      PlatformHelper.supportsDPadNavigation ||
      (mounted && ResponsiveHelper.isTvLayout(context));

  ProviderModel? get effectiveProvider {
    if (widget.provider != null) return widget.provider;
    final args = Get.arguments;
    if (args is ProviderModel) return args;
    if (args is Map && args['provider'] is ProviderModel) {
      return args['provider'] as ProviderModel;
    }
    return null;
  }

  bool get isEditing => effectiveProvider != null;

  ProviderManagerController get controller =>
      Get.find<ProviderManagerController>();

  @override
  void initState() {
    super.initState();
    final effective = effectiveProvider;
    ProviderType initialType = ProviderType.m3u;
    if (effective != null) {
      initialType = effective.providerType;
    } else if (Get.arguments is ProviderType) {
      initialType = Get.arguments as ProviderType;
    } else if (Get.arguments is Map &&
        (Get.arguments as Map)['type'] is ProviderType) {
      initialType = (Get.arguments as Map)['type'] as ProviderType;
    }
    _nameController = TextEditingController(text: effective?.name ?? '');
    _serverUrlController = TextEditingController(
      text: effective?.serverUrl ?? '',
    );
    _usernameController = TextEditingController(text: effective?.username ?? '');
    _passwordController = TextEditingController(text: effective?.password ?? '');
    _macController = TextEditingController(text: effective?.macAddress ?? '');
    _xmltvController = TextEditingController(text: effective?.xmltvUrl ?? '');
    _notesController = TextEditingController(text: effective?.notes ?? '');
    _selectedType = initialType.obs;
    _serverUrlController.addListener(_handleServerUrlChanged);

    _notesFocusNode = FocusNode(
      debugLabel: 'provider_notes_field',
      onKeyEvent: _handleNotesKeyEvent,
    );
    _notesFocusNode.addListener(_handleNotesFocusChange);
    _cancelFocusNode = FocusNode(debugLabel: 'provider_cancel_button');
    _scanToAddFocusNode = FocusNode(debugLabel: 'provider_scan_to_add_button');
    _submitFocusNode = FocusNode(
      debugLabel: 'provider_submit_button',
      onKeyEvent: _handleSubmitKeyEvent,
    );
  }

  @override
  void dispose() {
    _notesFocusNode.removeListener(_handleNotesFocusChange);
    _serverUrlController.removeListener(_handleServerUrlChanged);
    _nameController.dispose();
    _serverUrlController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _macController.dispose();
    _xmltvController.dispose();
    _notesController.dispose();

    _notesFocusNode.dispose();
    _cancelFocusNode.dispose();
    _scanToAddFocusNode.dispose();
    _submitFocusNode.dispose();
    super.dispose();
  }

  void _handleNotesFocusChange() {
    if (!_notesFocusNode.hasFocus && _isEditingNotes) {
      if (mounted) {
        setState(() => _isEditingNotes = false);
        SystemChannels.textInput.invokeMethod('TextInput.hide');
      }
    }
  }

  bool _isAtLastLine(TextEditingController controller) {
    final text = controller.text;
    final selection = controller.selection;
    if (!selection.isValid || text.isEmpty) return true;
    final offset = selection.extentOffset;
    if (offset < 0 || offset >= text.length) return true;
    final nextNewline = text.indexOf('\n', offset);
    return nextNewline == -1;
  }

  bool _isAtFirstLine(TextEditingController controller) {
    final text = controller.text;
    final selection = controller.selection;
    if (!selection.isValid || text.isEmpty) return true;
    final offset = selection.baseOffset;
    if (offset <= 0) return true;
    final prevNewline = text.lastIndexOf('\n', offset - 1);
    return prevNewline == -1;
  }

  KeyEventResult _handleNotesKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    final isSelect = event.logicalKey == LogicalKeyboardKey.select ||
        event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter ||
        event.logicalKey == LogicalKeyboardKey.gameButtonA;

    if (isSelect) {
      if (_isTv && !_isEditingNotes) {
        setState(() => _isEditingNotes = true);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _notesFocusNode.requestFocus();
          }
        });
        return KeyEventResult.handled;
      }
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      if (!_isTv || !_isEditingNotes || _isAtLastLine(_notesController)) {
        if (_isEditingNotes) {
          setState(() => _isEditingNotes = false);
          SystemChannels.textInput.invokeMethod('TextInput.hide');
        }
        if (!isEditing && _scanToAddFocusNode.canRequestFocus) {
          _scanToAddFocusNode.requestFocus();
          return KeyEventResult.handled;
        } else if (isEditing && _submitFocusNode.canRequestFocus) {
          _submitFocusNode.requestFocus();
          return KeyEventResult.handled;
        }
        final moved = node.focusInDirection(TraversalDirection.down);
        if (!moved) {
          node.nextFocus();
        }
        return KeyEventResult.handled;
      }
    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      if (!_isTv || !_isEditingNotes || _isAtFirstLine(_notesController)) {
        if (_isEditingNotes) {
          setState(() => _isEditingNotes = false);
          SystemChannels.textInput.invokeMethod('TextInput.hide');
        }
        final moved = node.focusInDirection(TraversalDirection.up);
        if (!moved) {
          node.previousFocus();
        }
        return KeyEventResult.handled;
      }
    }

    return KeyEventResult.ignored;
  }

  KeyEventResult _handleSubmitKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      _notesFocusNode.requestFocus();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isEditing = this.isEditing;

    return AppScaffold(
      title: isEditing ? 'Edit Provider' : 'Add Provider',
      showNavigation: false,
      body: Form(
        key: _formKey,
        child: TvKeyboardAwareScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          maxWidth: 760.0,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
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
                    focusNode: _notesFocusNode,
                    controller: _notesController,
                    readOnly: _isTv && !_isEditingNotes,
                    showCursor: !_isTv || _isEditingNotes,
                    enableInteractiveSelection: !_isTv || _isEditingNotes,
                    textInputAction:
                        _isTv ? TextInputAction.done : TextInputAction.newline,
                    onTap: () {
                      if (_isTv && !_isEditingNotes) {
                        setState(() => _isEditingNotes = true);
                      }
                    },
                    decoration: InputDecoration(
                      labelText: 'Notes',
                      hintText: (_isTv && !_isEditingNotes)
                          ? 'Press OK to edit notes'
                          : 'Optional notes about this provider',
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
                   focusNode: _cancelFocusNode,
                   onTap: () => Get.back(),
                   borderRadius: AppRadius.medium,
                   scale: 1.05,
                   descendantsAreFocusable: false,
                   onKeyEvent: (node, event) {
                     if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
                       return KeyEventResult.ignored;
                     }
                     if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                       _notesFocusNode.requestFocus();
                       return KeyEventResult.handled;
                     }
                     return KeyEventResult.ignored;
                   },
                   child: const OutlinedButton(
                     onPressed: null,
                     child: Text('Cancel'),
                   ),
                 ),
                 AppSpacing.widthMD,
                 if (!isEditing)
                   TvFocusable(
                     focusNode: _scanToAddFocusNode,
                     onTap: _showPairingDialog,
                     borderRadius: AppRadius.medium,
                     scale: 1.05,
                     descendantsAreFocusable: false,
                     onKeyEvent: (node, event) {
                       if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
                         return KeyEventResult.ignored;
                       }
                       if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                         _notesFocusNode.requestFocus();
                         return KeyEventResult.handled;
                       }
                       return KeyEventResult.ignored;
                     },
                     child: OutlinedButton(
                       onPressed: null,
                       style: OutlinedButton.styleFrom(
                         foregroundColor: Theme.of(context).colorScheme.primary,
                         disabledForegroundColor:
                             Theme.of(context).colorScheme.primary,
                         side: BorderSide(
                           color: Theme.of(context).colorScheme.primary,
                         ),
                       ),
                       child: const Row(
                         mainAxisSize: MainAxisSize.min,
                         children: [
                           Icon(Icons.qr_code_scanner, size: 18),
                           SizedBox(width: 6),
                           Text('Scan to Add'),
                         ],
                       ),
                     ),
                   ),
                 if (!isEditing) AppSpacing.widthMD,
                AppButton(
                  focusNode: _submitFocusNode,
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
                        final parts = XtreamUrlDetector.parse(trimmedServerUrl ?? '');
                        final effectiveUsername = (trimmedUsername != null && trimmedUsername.isNotEmpty)
                            ? trimmedUsername
                            : parts?.username;
                        final effectivePassword = (trimmedPassword != null && trimmedPassword.isNotEmpty)
                            ? trimmedPassword
                            : parts?.password;

                        controller.updateProvider(
                          effectiveProvider!.copyWith(
                            name: trimmedName,
                            providerType: _selectedType.value,
                            serverUrl: parts?.serverUrl ?? trimmedServerUrl,
                            username: effectiveUsername,
                            password: effectivePassword,
                            macAddress: trimmedMac,
                            xmltvUrl: trimmedXmltv,
                            notes: trimmedNotes,
                          ),
                        );
                      } else {
                        final parts = XtreamUrlDetector.parse(trimmedServerUrl ?? '');
                        final effectiveUsername = (trimmedUsername != null && trimmedUsername.isNotEmpty)
                            ? trimmedUsername
                            : parts?.username;
                        final effectivePassword = (trimmedPassword != null && trimmedPassword.isNotEmpty)
                            ? trimmedPassword
                            : parts?.password;

                        final newProvider = ProviderModel(
                          id: 'provider_${DateTime.now().millisecondsSinceEpoch}_${_randomSuffix()}',
                          name: trimmedName,
                          providerType: _selectedType.value,
                          serverUrl: parts?.serverUrl ?? trimmedServerUrl,
                          username: effectiveUsername,
                          password: effectivePassword,
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
      ),
    );
  }

   String _randomSuffix() {
    final random = DateTime.now().microsecond % 10000;
    return random.toString().padLeft(4, '0');
  }

  void _showPairingDialog() {
    PairingDialog.show(
      context: context,
      providerType: _selectedType.value,
      onDataReceived: _applyPairingData,
    );
  }

  void _applyPairingData(Map<String, dynamic> formData) {
    _nameController.text = (formData['name'] as String?)?.trim() ?? '';
    if (formData['serverUrl'] != null) {
      _serverUrlController.text = (formData['serverUrl'] as String).trim();
    }
    if (formData['username'] != null) {
      _usernameController.text = (formData['username'] as String).trim();
    }
    if (formData['password'] != null) {
      _passwordController.text = (formData['password'] as String).trim();
    }
    if (formData['macAddress'] != null) {
      _macController.text = (formData['macAddress'] as String).trim();
    }
    if (formData['xmltvUrl'] != null) {
      _xmltvController.text = (formData['xmltvUrl'] as String).trim();
    }
    if (formData['notes'] != null) {
      _notesController.text = (formData['notes'] as String).trim();
    }
    final typeStr = formData['providerType'] as String?;
    if (typeStr != null) {
      final newType = ProviderType.values.firstWhere(
        (t) => t.name == typeStr,
        orElse: () => _selectedType.value,
      );
      _selectedType.value = newType;
    }
    Get.snackbar(
      'Provider Data Received',
      'Form auto-filled from your phone. Review and save.',
      backgroundColor: Colors.green.withValues(alpha: 0.15),
      colorText: Colors.white,
    );
  }


  /// When an Xtream panel export URL (e.g. `get.php?username=X&password=Y`)
  /// is entered, switch to the Xtream provider type and extract the
  /// credentials and base server URL from the link.
  void _handleServerUrlChanged() {
    // Only auto-convert Xtream panel export links when the user is actually
    // configuring an Xtream provider. M3U links (which commonly end in
    // get.php/player_api.php too) must be left untouched, otherwise the full
    // playlist URL is stripped down to a bare server host and the provider
    // cannot be added.
    if (_selectedType.value != ProviderType.xtream) return;
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
    Future<void> paste() async {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text;
      if (text != null && text.trim().isNotEmpty) {
        controller.text = text.trim();
      }
    }

    return TvFocusable(
      borderRadius: AppRadius.small,
      scale: 1.0,
      onTap: paste,
      child: IconButton(
        icon: const Icon(AppIcons.paste, size: 20),
        tooltip: 'Paste',
        onPressed: paste,
      ),
    );
  }
}
