// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:stream_hub/core/theme/app_spacing.dart';
import 'package:stream_hub/core/theme/app_typography.dart';
import 'package:stream_hub/core/helpers/platform_helper.dart';
import 'package:stream_hub/core/utils/responsive_helper.dart';
import 'package:stream_hub/modules/profiles/profile_controller.dart';
import 'package:stream_hub/shared/widgets/app_button.dart';
import 'package:stream_hub/shared/widgets/app_card.dart';
import 'package:stream_hub/shared/widgets/app_scaffold.dart';
import 'package:stream_hub/shared/widgets/section_header.dart';
import 'package:stream_hub/shared/widgets/tv_focusable.dart';
import 'package:stream_hub/data/models/profile_model.dart';
import 'profile_avatar_helper.dart';

// ─── Page ──────────────────────────────────────────────────────────────────

class ProfilePage extends GetView<ProfileController> {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Profiles',
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }
        return ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            // ── Multi-profile switcher ──────────────────────────────────
            SectionHeader(
              title: 'Your Profiles',
              subtitle: 'Tap to switch • Up to $kMaxProfiles profiles',
            ),
            AppSpacing.heightXS,
            _ProfileSwitcher(controller: controller),
            AppSpacing.heightLG,

            // ── Active profile editor ───────────────────────────────────
            SectionHeader(
              title: 'Edit Profile',
              subtitle: 'Customise the selected profile',
            ),
            AppSpacing.heightXS,
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Avatar picker
                  Text(
                    'Avatar',
                    style: AppTypography.getCaption(
                      color:
                          Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  AppSpacing.heightSM,
                  _AvatarPicker(controller: controller),
                  AppSpacing.heightMD,
                  // Display name
                  _ProfileTextField(
                    label: 'Display Name',
                    hint: 'Enter your display name',
                    initialValue: controller.displayName.value,
                    onChanged: (v) => controller.displayName.value = v,
                    onSubmitted: (v) {
                      controller.displayName.value = v;
                      controller.saveProfileChanges(showSnackbar: false);
                    },
                  ),
                ],
              ),
            ),
            AppSpacing.heightLG,

            // ── Preferences ─────────────────────────────────────────────
            SectionHeader(
              title: 'Preferences',
              subtitle: 'Language and theme settings',
            ),
            AppSpacing.heightXS,
            AppCard(
              child: Column(
                children: [
                  TvFocusable(
                    borderRadius: BorderRadius.circular(12),
                    scale: 1.02,
                    onTap: () => _showLanguagePicker(context),
                    child: ListTile(
                      leading: Icon(
                        Icons.language_outlined,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      title: Text(
                        'Language',
                        style: AppTypography.getBody(
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      subtitle: Text(
                        _languageLabel(
                          controller.activeProfile.value?.language ?? 'en',
                        ),
                        style: AppTypography.getCaption(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.6),
                        ),
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    ),
                  ),
                  TvFocusable(
                    borderRadius: BorderRadius.circular(12),
                    scale: 1.02,
                    onTap: () => _showThemePicker(context),
                    child: ListTile(
                      leading: Icon(
                        Icons.brightness_6_outlined,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      title: Text(
                        'Theme',
                        style: AppTypography.getBody(
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      subtitle: Text(
                        _themeLabel(
                          controller.activeProfile.value?.themeMode,
                        ),
                        style: AppTypography.getCaption(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.6),
                        ),
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    ),
                  ),
                ],
              ),
            ),
            AppSpacing.heightLG,

            // ── Save ────────────────────────────────────────────────────
            AppButton(
              text: 'Save Changes',
              onPressed: controller.saveProfileChanges,
            ),

            if (controller.errorMessage.value.isNotEmpty) ...[
              AppSpacing.heightMD,
              Text(
                controller.errorMessage.value,
                style: AppTypography.getBody(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ],
          ],
        );
      }),
    );
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  String _themeLabel(String? mode) {
    switch (mode) {
      case 'light':
        return 'Light';
      case 'dark':
        return 'Dark';
      default:
        return 'System Default';
    }
  }

  String _languageLabel(String langCode) {
    const map = {
      'en': 'English',
      'fr': 'Français',
      'es': 'Español',
      'de': 'Deutsch',
      'ar': 'العربية',
      'pt': 'Português',
      'it': 'Italiano',
      'ru': 'Русский',
    };
    return map[langCode] ?? langCode;
  }

  // ─── Pickers ──────────────────────────────────────────────────────────────

  void _showLanguagePicker(BuildContext context) {
    const languages = [
      ('en', 'English'),
      ('fr', 'Français'),
      ('es', 'Español'),
      ('de', 'Deutsch'),
      ('ar', 'العربية'),
      ('pt', 'Português'),
      ('it', 'Italiano'),
      ('ru', 'Русский'),
    ];

    final current = controller.activeProfile.value?.language ?? 'en';

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select Language',
              style: AppTypography.getHeadline(
                color: Theme.of(ctx).colorScheme.onSurface,
              ),
            ),
            AppSpacing.heightMD,
            ...languages.map(((String, String) pair) {
              final (code, label) = pair;
              return RadioListTile<String>(
                value: code,
                groupValue: current,
                title: Text(label),
                onChanged: (v) {
                  if (v != null) {
                    controller.changeLanguage(v);
                    Navigator.of(ctx).pop();
                  }
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  void _showThemePicker(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Obx(() {
          final currentMode =
              controller.activeProfile.value?.themeMode ?? 'system';
          return Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xl,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select Theme',
                  style: AppTypography.getHeadline(
                    color: Theme.of(ctx).colorScheme.onSurface,
                  ),
                ),
                AppSpacing.heightMD,
                RadioListTile<String>(
                  value: 'system',
                  groupValue: currentMode,
                  title: const Text('System Default'),
                  onChanged: (v) {
                    if (v != null) {
                      controller.changeThemeMode(v);
                      Navigator.of(ctx).pop();
                    }
                  },
                ),
                RadioListTile<String>(
                  value: 'dark',
                  groupValue: currentMode,
                  title: const Text('Dark'),
                  onChanged: (v) {
                    if (v != null) {
                      controller.changeThemeMode(v);
                      Navigator.of(ctx).pop();
                    }
                  },
                ),
                RadioListTile<String>(
                  value: 'light',
                  groupValue: currentMode,
                  title: const Text('Light'),
                  onChanged: (v) {
                    if (v != null) {
                      controller.changeThemeMode(v);
                      Navigator.of(ctx).pop();
                    }
                  },
                ),
              ],
            ),
          );
        });
      },
    );
  }
}

// ─── Profile Switcher widget ───────────────────────────────────────────────

class _ProfileSwitcher extends StatelessWidget {
  final ProfileController controller;
  const _ProfileSwitcher({required this.controller});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Obx(() {
      final profiles = controller.profiles;
      final active = controller.activeProfile.value;

      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // Existing profile chips.
            ...profiles.map((p) {
              final isActive = p.id == active?.id;
              return Padding(
                padding: const EdgeInsets.only(right: AppSpacing.sm),
                child: TvFocusable(
                  borderRadius: BorderRadius.circular(16),
                  scale: 1.04,
                  onTap: () => controller.selectProfile(p),
                  onLongPress: profiles.length > 1
                      ? () => _confirmDelete(context, p)
                      : null,
                  child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm,
                      ),
                      decoration: BoxDecoration(
                        color: isActive
                            ? colorScheme.primaryContainer
                            : colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(16),
                        border: isActive
                            ? Border.all(color: colorScheme.primary, width: 2)
                            : null,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ProfileAvatar(
                            profile: p,
                            radius: 18,
                            iconSize: 16,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                p.displayName,
                                style: AppTypography.getBody(
                                  color: isActive
                                      ? colorScheme.onPrimaryContainer
                                      : colorScheme.onSurface,
                                ).copyWith(fontWeight: FontWeight.w600),
                              ),
                              if (isActive)
                                Text(
                                  'Active',
                                  style: AppTypography.getCaption(
                                    color: colorScheme.primary,
                                  ),
                                ),
                            ],
                          ),
                          if (profiles.length > 1) ...[
                            const SizedBox(width: AppSpacing.xs),
                            TvFocusable(
                              borderRadius: BorderRadius.circular(12),
                              scale: 1.1,
                              onTap: () => _confirmDelete(context, p),
                              child: Tooltip(
                                message: 'Delete profile',
                                child: Padding(
                                  padding: const EdgeInsets.all(4.0),
                                  child: Icon(
                                    Icons.close_rounded,
                                    size: 16,
                                    color: isActive
                                        ? colorScheme.onPrimaryContainer
                                            .withValues(alpha: 0.6)
                                        : colorScheme.onSurface
                                            .withValues(alpha: 0.5),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
              );
            }),

            // Add profile button.
            if (profiles.length < kMaxProfiles)
              TvFocusable(
                borderRadius: BorderRadius.circular(16),
                scale: 1.04,
                onTap: () => _showCreateProfileDialog(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: colorScheme.outline.withValues(alpha: 0.4),
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_circle_outline_rounded,
                          color: colorScheme.primary),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        'Add Profile',
                        style: AppTypography.getBody(color: colorScheme.primary),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      );
    });
  }

  void _showCreateProfileDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Profile'),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Display Name',
            hintText: 'e.g. Kids, Work …',
          ),
          textCapitalization: TextCapitalization.words,
          onSubmitted: (_) => _submitCreate(ctx, nameCtrl.text),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => _submitCreate(ctx, nameCtrl.text),
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _submitCreate(BuildContext ctx, String name) {
    Navigator.of(ctx).pop();
    if (name.trim().isNotEmpty) {
      controller.createProfile(name.trim());
    }
  }

  void _confirmDelete(BuildContext context, ProfileModel profile) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Profile'),
        content: Text(
          'Are you sure you want to delete "${profile.displayName}"?\n'
          'This will permanently remove all favorites and watch history for this profile.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              controller.deleteProfile(profile);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

// ─── Avatar Picker widget ──────────────────────────────────────────────────

class _AvatarPicker extends StatelessWidget {
  final ProfileController controller;
  const _AvatarPicker({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final selectedPhoto = controller.photoUrl.value.trim();
      final currentIdx = int.tryParse(selectedPhoto) ??
          avatarIndexForProfile(controller.activeProfile.value);
      final accountPhoto =
          controller.currentUser.value?.photoUrl?.trim() ?? '';
      final hasAccountPhoto = isNetworkAvatar(accountPhoto);
      final isAccountPhotoSelected =
          hasAccountPhoto && selectedPhoto == accountPhoto;

      return Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [
          if (hasAccountPhoto) ...[
            TvFocusable(
              onTap: () {
                controller.photoUrl.value = accountPhoto;
              },
              borderRadius: BorderRadius.circular(30),
              scale: 1.08,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: isAccountPhotoSelected
                      ? Border.all(
                          color: Theme.of(context).colorScheme.primary,
                          width: 3,
                        )
                      : Border.all(color: Colors.transparent, width: 3),
                  boxShadow: isAccountPhotoSelected
                      ? [
                          BoxShadow(
                            color: Theme.of(context)
                                .colorScheme
                                .primary
                                .withValues(alpha: 0.4),
                            blurRadius: 8,
                          ),
                        ]
                      : null,
                ),
                child: ProfileAvatar(
                  photoUrl: accountPhoto,
                  radius: 26,
                  iconSize: 22,
                ),
              ),
            ),
          ],
          ...List.generate(kAvatarPresets.length, (i) {
            final preset = kAvatarPresets[i];
            final isSelected = !isAccountPhotoSelected && i == currentIdx;
            return TvFocusable(
              onTap: () {
                controller.photoUrl.value = '$i';
              },
              borderRadius: BorderRadius.circular(30),
              scale: 1.08,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: isSelected
                      ? Border.all(
                          color: Theme.of(context).colorScheme.primary,
                          width: 3,
                        )
                      : Border.all(color: Colors.transparent, width: 3),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: Theme.of(context)
                                .colorScheme
                                .primary
                                .withValues(alpha: 0.4),
                            blurRadius: 8,
                          ),
                        ]
                      : null,
                ),
                child: CircleAvatar(
                  radius: 26,
                  backgroundColor: preset.color,
                  child: Icon(preset.icon, color: Colors.white, size: 22),
                ),
              ),
            );
          }),
        ],
      );
    });
  }
}

// ─── Text field ────────────────────────────────────────────────────────────

class _ProfileTextField extends StatefulWidget {
  final String label;
  final String hint;
  final String initialValue;
  final ValueChanged<String> onChanged;
  final ValueChanged<String>? onSubmitted;

  const _ProfileTextField({
    required this.label,
    required this.hint,
    required this.initialValue,
    required this.onChanged,
    this.onSubmitted,
  });

  @override
  State<_ProfileTextField> createState() => _ProfileTextFieldState();
}

class _ProfileTextFieldState extends State<_ProfileTextField> {
  late final TextEditingController _controller;
  late final FocusNode _textFocusNode;
  late final FocusNode _tvTileFocusNode;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
    _textFocusNode = FocusNode(debugLabel: 'Profile_DisplayName_Text');
    _tvTileFocusNode = FocusNode(debugLabel: 'Profile_DisplayName_Tile');
    _textFocusNode.addListener(_onTextFocusChanged);
    _textFocusNode.onKeyEvent = _handleTextKeyEvent;
  }

  void _onTextFocusChanged() {
    if (!_textFocusNode.hasFocus && mounted && _isEditing) {
      setState(() => _isEditing = false);
      final isTv = PlatformHelper.isTV || ResponsiveHelper.isTvLayout(context);
      if (isTv) {
        _textFocusNode.canRequestFocus = false;
      }
    }
  }

  KeyEventResult _handleTextKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowDown) {
      _exitEditing();
      final moved = node.focusInDirection(TraversalDirection.down);
      if (!moved) {
        node.nextFocus();
      }
      return KeyEventResult.handled;
    } else if (key == LogicalKeyboardKey.arrowUp) {
      _exitEditing();
      final moved = node.focusInDirection(TraversalDirection.up);
      if (!moved) {
        node.previousFocus();
      }
      return KeyEventResult.handled;
    } else if (key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.goBack) {
      _exitEditing();
      _tvTileFocusNode.requestFocus();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  void _activateEditing() {
    setState(() => _isEditing = true);
    _textFocusNode.canRequestFocus = true;
    _textFocusNode.requestFocus();
    SystemChannels.textInput.invokeMethod('TextInput.show');
  }

  void _exitEditing() {
    if (mounted) {
      setState(() => _isEditing = false);
      _textFocusNode.canRequestFocus = false;
      SystemChannels.textInput.invokeMethod('TextInput.hide');
      widget.onSubmitted?.call(_controller.text);
    }
  }

  void _handleSubmitted(String value) {
    _exitEditing();
    _tvTileFocusNode.requestFocus();
  }

  @override
  void didUpdateWidget(covariant _ProfileTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialValue != widget.initialValue &&
        _controller.text != widget.initialValue) {
      _controller.text = widget.initialValue;
      _controller.selection =
          TextSelection.collapsed(offset: _controller.text.length);
    }
  }

  @override
  void dispose() {
    _textFocusNode.removeListener(_onTextFocusChanged);
    _textFocusNode.dispose();
    _tvTileFocusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isTv = PlatformHelper.isTV || ResponsiveHelper.isTvLayout(context);

    if (isTv) {
      _textFocusNode.canRequestFocus = _isEditing;
    }

    final fieldWidget = TextField(
      controller: _controller,
      focusNode: _textFocusNode,
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: isTv && !_isEditing
            ? '${widget.hint} (Press OK to edit)'
            : widget.hint,
      ),
      onChanged: widget.onChanged,
      onSubmitted: _handleSubmitted,
    );

    if (!isTv) {
      return fieldWidget;
    }

    return TvFocusable(
      focusNode: _tvTileFocusNode,
      canRequestFocus: !_isEditing,
      onTap: _activateEditing,
      borderRadius: BorderRadius.circular(12),
      scale: 1.01,
      child: AbsorbPointer(
        absorbing: !_isEditing,
        child: fieldWidget,
      ),
    );
  }
}
