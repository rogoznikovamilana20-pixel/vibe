import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/localization/vibe_localizations.dart';
import '../../../core/theme/vibe_spacing.dart';
import '../../../core/theme/vibe_theme.dart';
import '../../../core/theme/vibe_typography.dart';
import '../../../core/widgets/settings_widgets.dart';
import '../../../core/widgets/vibe_top_bar.dart';

class PrivacySelectorScreen extends StatefulWidget {
  const PrivacySelectorScreen({
    super.key,
    required this.title,
    required this.description,
    required this.initialValue,
    required this.onChanged,
  });

  final String title;
  final String description;
  final int initialValue;
  final ValueChanged<int> onChanged;

  @override
  State<PrivacySelectorScreen> createState() => _PrivacySelectorScreenState();
}

class _PrivacySelectorScreenState extends State<PrivacySelectorScreen> {
  late int _value;

  @override
  void initState() {
    super.initState();
    _value = widget.initialValue;
  }

  void _setValue(int val) {
    HapticFeedback.selectionClick();
    setState(() => _value = val);
    widget.onChanged(val);
  }

  @override
  Widget build(BuildContext context) {
    final l = VibeLocalizations.of(context);
    
    return Scaffold(
      backgroundColor: context.vibeBackground,
      appBar: VibeTopBarAppBar(
        topInset: MediaQuery.paddingOf(context).top,
        child: VibeTopBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => Navigator.of(context).pop(),
            color: context.vibeTextPrimary,
          ),
          title: VibeTopBarTitle(widget.title),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(VibeSpacing.lg),
        children: [
          SettingsSection(
            title: widget.title.toUpperCase(),
            children: [
              _buildRadioTile(0, l.all),
              _buildRadioTile(1, l.contacts),
              _buildRadioTile(2, l.nobody),
            ],
          ),
          const SizedBox(height: VibeSpacing.md),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: VibeSpacing.lg),
            child: Text(
              widget.description,
              style: VibeTypography.caption.copyWith(color: context.vibeTextSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRadioTile(int val, String title) {
    final active = _value == val;
    return SettingsTile(
      onTap: () => _setValue(val),
      icon: active ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
      iconColor: active ? context.vibePrimary : context.vibeTextSecondary,
      title: title,
      trailing: active ? Icon(Icons.check_rounded, color: context.vibePrimary) : const SizedBox.shrink(),
    );
  }
}

