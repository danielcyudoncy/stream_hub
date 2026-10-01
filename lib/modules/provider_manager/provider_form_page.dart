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

  late final FocusNode _nameFocusNode;
  late final Map<ProviderType, FocusNode> _typeFocusNodes;
  late final FocusNode _serverUrlFocusNode;
  late final FocusNode _serverUrlPasteFocusNode;
  late final FocusNode _usernameFocusNode;
  late final FocusNode _passwordFocusNode;
  late final FocusNode _macFocusNode;
  late final FocusNode _xmltvFocusNode;
  late final FocusNode _xmltvPasteFocusNode;
  late final FocusNode _notesFocusNode;
  late final FocusNode _cancelFocusNode;
  late final FocusNode _scanToAddFocusNode;
  late final FocusNode _submitFocusNode;

  String? _activeEditingField;

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

    _initFocusNodes();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _isTv) {
        _nameFocusNode.requestFocus();
      }
    });
  }

  void _initFocusNodes() {
    _nameFocusNode = FocusNode(
      debugLabel: 'provider_name_field',
      onKeyEvent: (node, event) => _handleFieldKeyEvent(
        node: node,
        event: event,
        fieldId: 'name',
        controller: _nameController,
        nextNode: _getNextNodeForField('name'),
        prevNode: _getPrevNodeForField('name'),
      ),
    );
    _nameFocusNode.addListener(() => _handleFieldFocusChange('name', _nameFocusNode));

    _typeFocusNodes = {
      for (final type in ProviderType.values)
        type: FocusNode(
          debugLabel: 'provider_type_${type.name}',
          onKeyEvent: (node, event) => _handleTypeChipKeyEvent(type, event),
        ),
    };

    _serverUrlFocusNode = FocusNode(
      debugLabel: 'provider_server_url_field',
      onKeyEvent: (node, event) => _handleFieldKeyEvent(
        node: node,
        event: event,
        fieldId: 'serverUrl',
        controller: _serverUrlController,
        nextNode: _getNextNodeForField('serverUrl'),
        prevNode: _getPrevNodeForField('serverUrl'),
        rightNode: _serverUrlPasteFocusNode,
      ),
    );
    _serverUrlFocusNode.addListener(
      () => _handleFieldFocusChange('serverUrl', _serverUrlFocusNode),
    );

    _serverUrlPasteFocusNode = FocusNode(
      debugLabel: 'provider_server_url_paste_button',
      onKeyEvent: _handleServerUrlPasteKeyEvent,
    );

    _usernameFocusNode = FocusNode(
      debugLabel: 'provider_username_field',
      onKeyEvent: (node, event) => _handleFieldKeyEvent(
        node: node,
        event: event,
        fieldId: 'username',
        controller: _usernameController,
        nextNode: _getNextNodeForField('username'),
        prevNode: _getPrevNodeForField('username'),
      ),
    );
    _usernameFocusNode.addListener(
      () => _handleFieldFocusChange('username', _usernameFocusNode),
    );

    _passwordFocusNode = FocusNode(
      debugLabel: 'provider_password_field',
      onKeyEvent: (node, event) => _handleFieldKeyEvent(
        node: node,
        event: event,
        fieldId: 'password',
        controller: _passwordController,
        nextNode: _getNextNodeForField('password'),
        prevNode: _getPrevNodeForField('password'),
      ),
    );
    _passwordFocusNode.addListener(
      () => _handleFieldFocusChange('password', _passwordFocusNode),
    );

    _macFocusNode = FocusNode(
      debugLabel: 'provider_mac_field',
      onKeyEvent: (node, event) => _handleFieldKeyEvent(
        node: node,
        event: event,
        fieldId: 'mac',
        controller: _macController,
        nextNode: _getNextNodeForField('mac'),
        prevNode: _getPrevNodeForField('mac'),
      ),
    );
    _macFocusNode.addListener(
      () => _handleFieldFocusChange('mac', _macFocusNode),
    );

    _xmltvFocusNode = FocusNode(
      debugLabel: 'provider_xmltv_field',
      onKeyEvent: (node, event) => _handleFieldKeyEvent(
        node: node,
        event: event,
        fieldId: 'xmltv',
        controller: _xmltvController,
        nextNode: _getNextNodeForField('xmltv'),
        prevNode: _getPrevNodeForField('xmltv'),
        rightNode: _xmltvPasteFocusNode,
      ),
    );
    _xmltvFocusNode.addListener(
      () => _handleFieldFocusChange('xmltv', _xmltvFocusNode),
    );

    _xmltvPasteFocusNode = FocusNode(
      debugLabel: 'provider_xmltv_paste_button',
      onKeyEvent: _handleXmltvPasteKeyEvent,
    );

    _notesFocusNode = FocusNode(
      debugLabel: 'provider_notes_field',
      onKeyEvent: (node, event) => _handleFieldKeyEvent(
        node: node,
        event: event,
        fieldId: 'notes',
        controller: _notesController,
        nextNode: _getNextNodeForField('notes'),
        prevNode: _getPrevNodeForField('notes'),
        isMultiLine: true,
      ),
    );
    _notesFocusNode.addListener(
      () => _handleFieldFocusChange('notes', _notesFocusNode),
    );

    _cancelFocusNode = FocusNode(
      debugLabel: 'provider_cancel_button',
      onKeyEvent: _handleCancelKeyEvent,
    );

    _scanToAddFocusNode = FocusNode(
      debugLabel: 'provider_scan_to_add_button',
      onKeyEvent: _handleScanToAddKeyEvent,
    );

    _submitFocusNode = FocusNode(
      debugLabel: 'provider_submit_button',
      onKeyEvent: _handleSubmitKeyEvent,
    );
  }

  FocusNode? _getNextNodeForField(String fieldId) {
    switch (fieldId) {
      case 'name':
        return _typeFocusNodes[_selectedType.value];
      case 'serverUrl':
        return switch (_selectedType.value) {
          ProviderType.xtream => _usernameFocusNode,
          ProviderType.stalker => _macFocusNode,
          _ => _notesFocusNode,
        };
      case 'username':
        return _passwordFocusNode;
      case 'password':
      case 'mac':
      case 'xmltv':
        return _notesFocusNode;
      case 'notes':
        return !isEditing ? _scanToAddFocusNode : _submitFocusNode;
      default:
        return null;
    }
  }

  FocusNode? _getPrevNodeForField(String fieldId) {
    switch (fieldId) {
      case 'serverUrl':
        return _typeFocusNodes[_selectedType.value];
      case 'username':
        return _serverUrlFocusNode;
      case 'password':
        return _usernameFocusNode;
      case 'mac':
        return _serverUrlFocusNode;
      case 'xmltv':
        return _typeFocusNodes[ProviderType.xmltv];
      case 'notes':
        return switch (_selectedType.value) {
          ProviderType.xtream => _passwordFocusNode,
          ProviderType.stalker => _macFocusNode,
          ProviderType.xmltv => _xmltvFocusNode,
          _ => _serverUrlFocusNode,
        };
      default:
        return null;
    }
  }

  @override
  void dispose() {
    _serverUrlController.removeListener(_handleServerUrlChanged);
    _nameController.dispose();
    _serverUrlController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _macController.dispose();
    _xmltvController.dispose();
    _notesController.dispose();

    _nameFocusNode.dispose();
    for (final node in _typeFocusNodes.values) {
      node.dispose();
    }
    _serverUrlFocusNode.dispose();
    _serverUrlPasteFocusNode.dispose();
    _usernameFocusNode.dispose();
    _passwordFocusNode.dispose();
    _macFocusNode.dispose();
    _xmltvFocusNode.dispose();
    _xmltvPasteFocusNode.dispose();
    _notesFocusNode.dispose();
    _cancelFocusNode.dispose();
    _scanToAddFocusNode.dispose();
    _submitFocusNode.dispose();
    super.dispose();
  }

  void _stopEditing() {
    if (_activeEditingField != null) {
      if (mounted) {
        setState(() => _activeEditingField = null);
        SystemChannels.textInput.invokeMethod('TextInput.hide');
      }
    }
  }

  void _handleFieldFocusChange(String fieldId, FocusNode node) {
    if (!node.hasFocus && _activeEditingField == fieldId) {
      _stopEditing();
    }
    if (mounted) {
      setState(() {});
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

  KeyEventResult _handleTypeChipKeyEvent(ProviderType pt, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      _nameFocusNode.requestFocus();
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      if (_selectedType.value == ProviderType.xmltv) {
        _xmltvFocusNode.requestFocus();
      } else {
        _serverUrlFocusNode.requestFocus();
      }
      return KeyEventResult.handled;
    }

    final values = ProviderType.values;
    final currentIndex = values.indexOf(pt);

    if (event.logicalKey == LogicalKeyboardKey.arrowLeft && currentIndex > 0) {
      _typeFocusNodes[values[currentIndex - 1]]?.requestFocus();
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowRight &&
        currentIndex < values.length - 1) {
      _typeFocusNodes[values[currentIndex + 1]]?.requestFocus();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  KeyEventResult _handleFieldKeyEvent({
    required FocusNode node,
    required KeyEvent event,
    required String fieldId,
    required FocusNode? nextNode,
    required FocusNode? prevNode,
    FocusNode? rightNode,
    FocusNode? leftNode,
    bool isMultiLine = false,
    TextEditingController? controller,
  }) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    final isSelect = event.logicalKey == LogicalKeyboardKey.select ||
        event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter ||
        event.logicalKey == LogicalKeyboardKey.gameButtonA;

    final isEditing = _activeEditingField == fieldId;

    if (isSelect) {
      if (_isTv && !isEditing) {
        setState(() => _activeEditingField = fieldId);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            node.requestFocus();
            SystemChannels.textInput.invokeMethod('TextInput.show');
          }
        });
        return KeyEventResult.handled;
      }
    }

    if (event.logicalKey == LogicalKeyboardKey.escape) {
      if (isEditing) {
        _stopEditing();
        return KeyEventResult.handled;
      }
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      final canExitDown =
          !isMultiLine || controller == null || _isAtLastLine(controller);
      if (!isEditing || canExitDown) {
        if (isEditing) {
          _stopEditing();
        }
        if (nextNode != null && nextNode.canRequestFocus) {
          nextNode.requestFocus();
          return KeyEventResult.handled;
        }
        final moved = node.focusInDirection(TraversalDirection.down);
        if (!moved) node.nextFocus();
        return KeyEventResult.handled;
      }
    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      final canExitUp =
          !isMultiLine || controller == null || _isAtFirstLine(controller);
      if (!isEditing || canExitUp) {
        if (isEditing) {
          _stopEditing();
        }
        if (prevNode != null && prevNode.canRequestFocus) {
          prevNode.requestFocus();
          return KeyEventResult.handled;
        }
        final moved = node.focusInDirection(TraversalDirection.up);
        if (!moved) node.previousFocus();
        return KeyEventResult.handled;
      }
    } else if (event.logicalKey == LogicalKeyboardKey.arrowRight &&
        rightNode != null &&
        !isEditing) {
      if (rightNode.canRequestFocus) {
        rightNode.requestFocus();
        return KeyEventResult.handled;
      }
    } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft &&
        leftNode != null &&
        !isEditing) {
      if (leftNode.canRequestFocus) {
        leftNode.requestFocus();
        return KeyEventResult.handled;
      }
    }

    return KeyEventResult.ignored;
  }

  KeyEventResult _handleCancelKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      _notesFocusNode.requestFocus();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      final nextNode = !isEditing ? _scanToAddFocusNode : _submitFocusNode;
      nextNode.requestFocus();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  KeyEventResult _handleScanToAddKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      _notesFocusNode.requestFocus();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _cancelFocusNode.requestFocus();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      _submitFocusNode.requestFocus();
      return KeyEventResult.handled;
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
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      final prevNode = !isEditing ? _scanToAddFocusNode : _cancelFocusNode;
      prevNode.requestFocus();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  KeyEventResult _handleServerUrlPasteKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _serverUrlFocusNode.requestFocus();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      _getNextNodeForField('serverUrl')?.requestFocus();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      _typeFocusNodes[_selectedType.value]?.requestFocus();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  KeyEventResult _handleXmltvPasteKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _xmltvFocusNode.requestFocus();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      _notesFocusNode.requestFocus();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      _typeFocusNodes[ProviderType.xmltv]?.requestFocus();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Widget _buildTvFormField({
    required String fieldId,
    required FocusNode focusNode,
    required TextEditingController controller,
    required String labelText,
    required String defaultHint,
    TextInputType keyboardType = TextInputType.text,
    TextCapitalization textCapitalization = TextCapitalization.none,
    bool isPassword = false,
    bool isMultiLine = false,
    int maxLines = 1,
    int? maxLength,
    Widget? suffixIcon,
    FormFieldValidator<String>? validator,
  }) {
    final isEditing = _activeEditingField == fieldId;
    final isTvMode = _isTv;
    final isFocused = focusNode.hasFocus;

    return TextFormField(
      focusNode: focusNode,
      controller: controller,
      readOnly: isTvMode && !isEditing,
      showCursor: !isTvMode || isEditing,
      enableInteractiveSelection: !isTvMode || isEditing,
      obscureText: isPassword,
      keyboardType: isMultiLine ? TextInputType.multiline : keyboardType,
      textCapitalization: textCapitalization,
      maxLines: maxLines,
      maxLength: maxLength,
      textInputAction: isTvMode
          ? (isMultiLine ? TextInputAction.newline : TextInputAction.next)
          : (isMultiLine ? TextInputAction.newline : TextInputAction.next),
      onTap: () {
        if (isTvMode && !isEditing) {
          setState(() => _activeEditingField = fieldId);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              focusNode.requestFocus();
              SystemChannels.textInput.invokeMethod('TextInput.show');
            }
          });
        }
      },
      onFieldSubmitted: (_) {
        if (isTvMode) {
          _stopEditing();
          final next = _getNextNodeForField(fieldId);
          if (next != null && next.canRequestFocus) {
            next.requestFocus();
          }
        }
      },
      decoration: InputDecoration(
        labelText: labelText,
        hintText: (isTvMode && !isEditing)
            ? 'Press OK to edit $labelText'
            : defaultHint,
        helperText: (isTvMode && isFocused && !isEditing)
            ? 'Press OK on remote to enter text'
            : null,
        suffixIcon: suffixIcon,
      ),
      validator: validator,
    );
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
                  _buildTvFormField(
                    fieldId: 'name',
                    focusNode: _nameFocusNode,
                    controller: _nameController,
                    labelText: 'Provider Name',
                    defaultHint: 'Enter a memorable name',
                    textCapitalization: TextCapitalization.words,
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
                          focusNode: _typeFocusNodes[pt],
                          descendantsAreFocusable: false,
                          onTap: () => _selectedType.value = pt,
                          borderRadius: AppRadius.pill,
                          scale: 1.05,
                          onKeyEvent: (node, event) =>
                              _handleTypeChipKeyEvent(pt, event),
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
                          _buildTvFormField(
                            fieldId: 'serverUrl',
                            focusNode: _serverUrlFocusNode,
                            controller: _serverUrlController,
                            labelText: 'Server URL',
                            defaultHint: 'https://example.com',
                            keyboardType: TextInputType.url,
                            suffixIcon: _buildPasteButton(
                              _serverUrlController,
                              focusNode: _serverUrlPasteFocusNode,
                              onKeyEvent: _handleServerUrlPasteKeyEvent,
                            ),
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
                          _buildTvFormField(
                            fieldId: 'username',
                            focusNode: _usernameFocusNode,
                            controller: _usernameController,
                            labelText: 'Username',
                            defaultHint: 'Enter username',
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Username is required.';
                              }
                              return null;
                            },
                          ),
                          AppSpacing.heightMD,
                          _buildTvFormField(
                            fieldId: 'password',
                            focusNode: _passwordFocusNode,
                            controller: _passwordController,
                            labelText: 'Password',
                            defaultHint: 'Enter password',
                            isPassword: true,
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
                          _buildTvFormField(
                            fieldId: 'mac',
                            focusNode: _macFocusNode,
                            controller: _macController,
                            labelText: 'MAC Address',
                            defaultHint: 'Required for Stalker Portal',
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
                          _buildTvFormField(
                            fieldId: 'xmltv',
                            focusNode: _xmltvFocusNode,
                            controller: _xmltvController,
                            labelText: 'XMLTV URL',
                            defaultHint: 'https://example.com/guide.xml',
                            keyboardType: TextInputType.url,
                            suffixIcon: _buildPasteButton(
                              _xmltvController,
                              focusNode: _xmltvPasteFocusNode,
                              onKeyEvent: _handleXmltvPasteKeyEvent,
                            ),
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
                  _buildTvFormField(
                    fieldId: 'notes',
                    focusNode: _notesFocusNode,
                    controller: _notesController,
                    labelText: 'Notes',
                    defaultHint: 'Optional notes about this provider',
                    isMultiLine: true,
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
                  onKeyEvent: _handleCancelKeyEvent,
                  onTap: () => Get.back(),
                  borderRadius: AppRadius.medium,
                  scale: 1.05,
                  descendantsAreFocusable: false,
                  child: const OutlinedButton(
                    onPressed: null,
                    child: Text('Cancel'),
                  ),
                ),
                AppSpacing.widthMD,
                if (!isEditing)
                  TvFocusable(
                    focusNode: _scanToAddFocusNode,
                    onKeyEvent: _handleScanToAddKeyEvent,
                    onTap: _showPairingDialog,
                    borderRadius: AppRadius.medium,
                    scale: 1.05,
                    descendantsAreFocusable: false,
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
                  onKeyEvent: _handleSubmitKeyEvent,
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

  Widget _buildPasteButton(
    TextEditingController controller, {
    FocusNode? focusNode,
    FocusOnKeyEventCallback? onKeyEvent,
  }) {
    Future<void> paste() async {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text;
      if (text != null && text.trim().isNotEmpty) {
        controller.text = text.trim();
      }
    }

    return TvFocusable(
      focusNode: focusNode,
      onKeyEvent: onKeyEvent,
      borderRadius: AppRadius.small,
      scale: 1.0,
      descendantsAreFocusable: false,
      onTap: paste,
      child: IconButton(
        icon: const Icon(AppIcons.paste, size: 20),
        tooltip: 'Paste',
        onPressed: paste,
      ),
    );
  }
}
