import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/localization/vibe_localizations.dart';
import '../../core/theme/vibe_colors.dart';
import '../../core/widgets/vibe_icon_font.dart';
import '../../core/theme/vibe_spacing.dart';
import '../../core/theme/vibe_theme.dart';
import '../../core/theme/vibe_typography.dart';
import 'chat_composer.dart';

/// Attachment menu bottom sheet — shows options like photo, voice, file, etc.
class AttachmentMenu extends StatelessWidget {
  const AttachmentMenu({
    super.key,
    required this.onPhoto,
    required this.onVoice,
    required this.onMedia,
    required this.onFile,
    required this.onLocation,
    required this.onContact,
    required this.onPoll,
    required this.onGif,
  });

  final VoidCallback onPhoto;
  final VoidCallback onVoice;
  final VoidCallback onMedia;
  final VoidCallback onFile;
  final VoidCallback onLocation;
  final VoidCallback onContact;
  final VoidCallback onPoll;
  final VoidCallback onGif;

  @override
  Widget build(BuildContext context) {
    final l = VibeLocalizations.of(context);
    Widget row(List<Widget> items) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: items,
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        VibeSpacing.xl,
        VibeSpacing.sm,
        VibeSpacing.xl,
        VibeSpacing.xxl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.attachmentTitle,
            style: VibeTypography.subtitle.copyWith(
              color: context.vibeTextPrimary,
            ),
          ),
          const SizedBox(height: VibeSpacing.lg),
          row([
            AttachmentItem(
              icon: VibeIcons.camera,
              color: VibeColors.vivid,
              label: l.attachmentPhoto,
              onTap: () {
                HapticFeedback.selectionClick();
                onPhoto();
              },
            ),
            AttachmentItem(
              icon: VibeIcons.mic,
              color: const Color(0xFFEC4899),
              label: l.attachmentVoice,
              onTap: () {
                HapticFeedback.selectionClick();
                onVoice();
              },
            ),
            AttachmentItem(
              icon: Icons.photo_library_rounded,
              color: VibeColors.primary,
              label: l.attachmentMedia,
              onTap: () {
                HapticFeedback.selectionClick();
                onMedia();
              },
            ),
          ]),
          const SizedBox(height: VibeSpacing.lg),
          row([
            AttachmentItem(
              icon: VibeIcons.file,
              color: const Color(0xFFF59E0B),
              label: l.attachmentFile,
              onTap: () {
                HapticFeedback.selectionClick();
                onFile();
              },
            ),
            AttachmentItem(
              icon: VibeIcons.pin,
              color: const Color(0xFF10B981),
              label: l.attachmentLocation,
              onTap: () {
                HapticFeedback.selectionClick();
                onLocation();
              },
            ),
            AttachmentItem(
              icon: VibeIcons.user,
              color: const Color(0xFF3B82F6),
              label: l.attachmentContact,
              onTap: () {
                HapticFeedback.selectionClick();
                onContact();
              },
            ),
          ]),
          const SizedBox(height: VibeSpacing.lg),
          row([
            AttachmentItem(
              icon: VibeIcons.bubble,
              color: context.vibePrimary,
              label: l.attachmentPoll,
              onTap: () {
                HapticFeedback.selectionClick();
                onPoll();
              },
            ),
            AttachmentItem(
              icon: Icons.gif_box_outlined,
              color: const Color(0xFF8B5CF6),
              label: 'GIF',
              onTap: () {
                HapticFeedback.selectionClick();
                onGif();
              },
            ),
          ]),
        ],
      ),
    );
  }
}
