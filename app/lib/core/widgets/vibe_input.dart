import 'package:flutter/material.dart';

import '../theme/vibe_animations.dart';
import '../theme/vibe_colors.dart';
import '../theme/vibe_spacing.dart';
import '../theme/vibe_theme.dart';
import '../theme/vibe_typography.dart';

/// Поле ввода Vibe: подложка-пилюля, фиолетовая рамка по точным границам
/// пилюли в фокусе (рисуется на контейнере, а не внутри InputDecor).
class VibeInput extends StatefulWidget {
  const VibeInput({
    super.key,
    required this.hint,
    this.controller,
    this.prefixIcon,
    this.suffixIcon,
    this.obscure = false,
    this.autofocus = false,
    this.keyboardType,
    this.errorText,
    this.maxLines = 1,
    this.onChanged,
    this.onSubmitted,
    this.textCapitalization = TextCapitalization.sentences,
  });

  final String hint;
  final TextEditingController? controller;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final bool obscure;
  final bool autofocus;
  final TextInputType? keyboardType;
  final String? errorText;
  final int maxLines;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextCapitalization textCapitalization;

  @override
  State<VibeInput> createState() => _VibeInputState();
}

class _VibeInputState extends State<VibeInput> {
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _focusNode.removeListener(() {});
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final error = widget.errorText;
    final focused = _focusNode.hasFocus;
    final isDark = context.isDarkMode;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedContainer(
          duration: VibeAnimations.pulse,
          curve: VibeAnimations.standard,
          decoration: BoxDecoration(
            color: isDark
                ? context.vibeSurfaceVariant
                : const Color(0xFFEFEDF8),
            borderRadius: BorderRadius.circular(VibeRadius.input),
            border: Border.all(
              color: error != null
                  ? VibeColors.inputErrorBorder
                  : focused
                      ? context.vibePrimary
                      : isDark
                          ? VibeColors.inputBorder
                          : const Color(0x291C1B22),
              width: error != null || focused ? 1.5 : 1,
            ),
          ),
          child: TextField(
            controller: widget.controller,
            focusNode: _focusNode,
            autofocus: widget.autofocus,
            obscureText: widget.obscure,
            keyboardType: widget.keyboardType,
            maxLines: widget.maxLines,
            onChanged: widget.onChanged,
            onSubmitted: widget.onSubmitted,
            textCapitalization: widget.textCapitalization,
            style: VibeTypography.body.copyWith(
              color: context.vibeTextPrimary,
            ),
            cursorColor: context.vibePrimary,
            decoration: InputDecoration(
              hintText: widget.hint,
              hintStyle: VibeTypography.body.copyWith(
                color: context.vibeTextSecondary,
              ),
              prefixIcon: widget.prefixIcon != null
                  ? Icon(
                      widget.prefixIcon,
                      size: 22,
                      color: context.vibeTextSecondary,
                    )
                  : null,
              suffixIcon: widget.suffixIcon,
              border: InputBorder.none,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: VibeSpacing.lg,
                vertical: VibeSpacing.lg,
              ),
            ),
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: VibeSpacing.xs),
          Text(
            error,
            style: VibeTypography.caption.copyWith(color: context.vibeError),
          ),
        ],
      ],
    );
  }
}