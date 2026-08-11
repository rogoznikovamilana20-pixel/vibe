import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme/vibe_colors.dart';
import '../core/theme/vibe_spacing.dart';
import '../core/theme/vibe_theme.dart';
import '../core/theme/vibe_typography.dart';
import '../core/widgets/vibe_collapsed_top_bar.dart';
import '../core/widgets/vibe_collapsible_screen.dart';
import '../core/widgets/vibe_input.dart';
import '../core/widgets/vibe_top_bar.dart';

/// Aurion — персональный AI-ассистент (UI-превью).
class AurionScreen extends StatefulWidget {
  const AurionScreen({super.key, required this.userName});

  final String userName;

  @override
  State<AurionScreen> createState() => _AurionScreenState();
}

class _AurionScreenState extends State<AurionScreen> {
  final _controller = TextEditingController();

  static const _suggestions = [
    ('Перескажи вчерашний чат по работе', Icons.summarize_rounded),
    ('Перепиши позлее 💅', Icons.edit_note_rounded),
    ('Сделай из этого список задач', Icons.checklist_rounded),
    ('Идеи для поста в канал', Icons.lightbulb_outline_rounded),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    HapticFeedback.mediumImpact();
    setState(() => _controller.clear());
    _snack('Aurion отвечает — в v2.0');
  }

  void _setSuggestion(String s) {
    HapticFeedback.selectionClick();
    _controller.text = s;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          Expanded(
            child: VibeCollapsibleScreen(
              slivers: [
          SliverToBoxAdapter(
            child: VibeTopBar(
              leading: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  VibeTopBarIcon(
                    icon: Icons.arrow_back_ios_new_rounded,
                    onTap: () => Navigator.of(context).pop(),
                    tooltip: 'Назад',
                  ),
                  const SizedBox(width: VibeSpacing.sm),
                  const _AurionAvatarSmall(),
                ],
              ),
              title: const VibeTopBarTitle('Aurion'),
              actions: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: VibeSpacing.sm,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: VibeColors.success.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(VibeRadius.badge),
                      ),
                      child: Text(
                        'онлайн',
                        style: VibeTypography.label.copyWith(
                          color: VibeColors.success,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.only(
              left: VibeSpacing.lg,
              right: VibeSpacing.lg,
              top: VibeSpacing.md,
            ),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                Container(
                  padding: const EdgeInsets.all(VibeSpacing.xl),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: VibeColors.aurionGradient,
                    ),
                    borderRadius: BorderRadius.circular(VibeRadius.card),
                    border: Border.all(color: context.vibeDivider),
                    boxShadow: const [VibeShadows.glowPrimary],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Привет, ${widget.userName}! 👋',
                        style: VibeTypography.title.copyWith(
                          color: VibeColors.textPrimaryDark,
                        ),
                      ),
                      const SizedBox(height: VibeSpacing.sm),
                      Text(
                        'Я Aurion — твой персональный ассистент. '
                        'Перескажу чат, переведу, помогу с текстом '
                        'и задачами.',
                        style: VibeTypography.body.copyWith(
                          color: VibeColors.textSecondaryDark,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: VibeSpacing.xl),
                Text(
                  'Попробуй спросить',
                  style: VibeTypography.subtitle.copyWith(
                    color: context.vibeTextPrimary,
                  ),
                ),
                const SizedBox(height: VibeSpacing.md),
                for (final (s, icon) in _suggestions)
                  Padding(
                    padding: const EdgeInsets.only(bottom: VibeSpacing.sm),
                    child: _SuggestionCard(
                      text: s,
                      icon: icon,
                      onTap: () => _setSuggestion(s),
                    ),
                  ),
              ]),
            ),
          ),
        ],
        collapsedBarBuilder: (_, progress) => VibeCollapsedTopBar(
          progress: progress,
          leading: const _AurionAvatarSmall(),
          title: const VibeTopBarTitle('Aurion'),
          actions: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: VibeSpacing.sm),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: VibeSpacing.sm,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: VibeColors.success.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(VibeRadius.badge),
                ),
                child: Text(
                  'онлайн',
                  style: VibeTypography.label.copyWith(
                    color: VibeColors.success,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              VibeSpacing.lg,
              VibeSpacing.sm,
              VibeSpacing.lg,
              VibeSizes.bottomNavHeight * 2 + VibeSpacing.lg,
            ),
            child: Row(
              children: [
                Expanded(
                  child: VibeInput(
                    controller: _controller,
                    hint: 'Спроси Aurion…',
                    onSubmitted: (_) => _send(),
                  ),
                ),
                const SizedBox(width: VibeSpacing.sm),
                IconButton.filled(
                  onPressed: _send,
                  icon: const Icon(Icons.arrow_upward_rounded),
                  style: IconButton.styleFrom(
                    backgroundColor: context.vibePrimary,
                    foregroundColor: Colors.white,
                  ),
                  tooltip: 'Отправить',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }
}

class _AurionAvatarSmall extends StatelessWidget {
  const _AurionAvatarSmall();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      margin: const EdgeInsets.only(left: VibeSpacing.xs),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: VibeColors.aurionGradient,
        ),
        border: Border.all(
          color: context.vibePrimary.withValues(alpha: 0.45),
          width: 1.5,
        ),
      ),
      child: Center(
        child: Icon(
          Icons.auto_awesome_rounded,
          color: Color.lerp(context.vibePrimary, Colors.white, 0.45),
        ),
      ),
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({
    required this.text,
    required this.icon,
    required this.onTap,
  });

  final String text;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(VibeRadius.md),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: VibeSpacing.md,
            vertical: 14,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: context.vibeTextSecondary,
                size: VibeSizes.iconSm,
              ),
              const SizedBox(width: VibeSpacing.md),
              Expanded(
                child: Text(
                  text,
                  style: VibeTypography.body.copyWith(
                    color: context.vibeTextPrimary,
                  ),
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: context.vibeTextTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
