import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/aurion/aurion_service.dart';
import '../core/theme/vibe_colors.dart';
import '../core/theme/vibe_spacing.dart';
import '../core/theme/vibe_theme.dart';
import '../core/theme/vibe_typography.dart';
import '../core/widgets/vibe_collapsed_top_bar.dart';
import '../core/widgets/vibe_collapsible_screen.dart';
import '../core/widgets/vibe_input.dart';
import '../core/widgets/vibe_top_bar.dart';

/// Aurion — персональный AI-ассистент (слой, отдельной вкладки нет).
///
/// Экран честно отражает состояние фичи:
///  - disabled — панель подключения (API-ключ), AI-элементов нет;
///  - enabled — живые запросы, ответ в AI_PREVIEW (draft-first: не шлётся,
///    пока пользователь не вставит в поле);
///  - degraded — статус «аварийный», при сбое «Aurion временно недоступен»
///    + «Повторить».
class AurionScreen extends StatefulWidget {
  const AurionScreen({super.key, required this.userName});

  final String userName;

  @override
  State<AurionScreen> createState() => _AurionScreenState();
}

class _AurionScreenState extends State<AurionScreen> {
  final _controller = TextEditingController();
  final _keyController = TextEditingController();
  bool _connecting = false;
  bool _thinking = false;
  String? _preview;
  String? _error;

  static const _suggestions = [
    ('Перескажи вчерашний чат по работе', Icons.summarize_rounded),
    ('Перепиши позлее 💅', Icons.edit_note_rounded),
    ('Сделай из этого список задач', Icons.checklist_rounded),
    ('Идеи для поста в канал', Icons.lightbulb_outline_rounded),
  ];

  @override
  void dispose() {
    _controller.dispose();
    _keyController.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    final key = _keyController.text.trim();
    if (key.isEmpty || _connecting) return;
    setState(() {
      _connecting = true;
      _error = null;
    });
    final service = AurionService.instance;
    await service.enable(key);
    if (!mounted) return;
    setState(() {
      _connecting = false;
      if (service.status == AurionStatus.disabled) {
        _error = 'Не удалось подключиться: проверьте ключ доступа.';
      }
    });
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _thinking) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _thinking = true;
      _preview = null;
      _error = null;
    });
    try {
      final answer = await AurionService.instance.complete(text);
      if (!mounted) return;
      setState(() {
        _thinking = false;
        _preview = answer;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _thinking = false;
        _error = 'Aurion временно недоступен.';
      });
    }
  }

  void _insertPreview() {
    if (_preview == null) return;
    _controller.text = _preview!;
    _controller.selection = TextSelection.collapsed(
      offset: _controller.text.length,
    );
    setState(() => _preview = null);
  }

  void _setSuggestion(String s) {
    HapticFeedback.selectionClick();
    _controller.text = s;
    setState(() {});
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AurionService.instance,
      builder: (context, _) {
        final status = AurionService.instance.status;
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
                            child: Center(child: _StatusBadge(status: status)),
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
                          _buildHero(context),
                          if (status == AurionStatus.disabled ||
                              status == AurionStatus.introspection) ...[
                            const SizedBox(height: VibeSpacing.xl),
                            _buildConnectCard(context),
                          ] else ...[
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
                                padding: const EdgeInsets.only(
                                  bottom: VibeSpacing.sm,
                                ),
                                child: _SuggestionCard(
                                  text: s,
                                  icon: icon,
                                  onTap: () => _setSuggestion(s),
                                ),
                              ),
                            if (_error != null) ...[
                              const SizedBox(height: VibeSpacing.md),
                              _ErrorCard(message: _error!, onRetry: _send),
                            ],
                            if (_preview != null) ...[
                              const SizedBox(height: VibeSpacing.md),
                              _PreviewCard(
                                text: _preview!,
                                onInsert: _insertPreview,
                                onCopy: _snackCopy,
                              ),
                            ],
                          ],
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: VibeSpacing.sm,
                        ),
                        child: Center(
                          child: _StatusBadge(status: status),
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
                      onPressed: _thinking
                          ? null
                          : (status == AurionStatus.enabled ||
                                  status == AurionStatus.degraded)
                              ? _send
                              : _connect,
                      icon: _thinking
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.arrow_upward_rounded),
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
      },
    );
  }

  Widget _buildHero(BuildContext context) {
    return Container(
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
    );
  }

  /// Подключение по API-ключу (GigaChat). Ключ уходит в secure storage,
  /// в код/логи не попадает.
  Widget _buildConnectCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(VibeSpacing.lg),
      decoration: BoxDecoration(
        color: context.vibeSurface,
        borderRadius: BorderRadius.circular(VibeRadius.card),
        border: Border.all(color: context.vibeDivider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Подключите Aurion',
            style: VibeTypography.subtitle.copyWith(
              color: context.vibeTextPrimary,
            ),
          ),
          const SizedBox(height: VibeSpacing.xs),
          Text(
            'Введите персональный ключ GigaChat (GigaChat Studio). '
            'Ключ хранится в защищённом хранилище устройства.',
            style: VibeTypography.body.copyWith(
              color: context.vibeTextSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: VibeSpacing.md),
          TextField(
            controller: _keyController,
            obscureText: true,
            onSubmitted: (_) => _connect(),
            style: VibeTypography.body.copyWith(
              color: context.vibeTextPrimary,
            ),
            cursorColor: context.vibePrimary,
            decoration: InputDecoration(
              hintText: 'API-ключ',
              hintStyle: VibeTypography.body.copyWith(
                color: context.vibeTextTertiary,
              ),
              prefixIcon: Icon(
                Icons.key_rounded,
                color: context.vibeTextTertiary,
              ),
              filled: true,
              fillColor: context.vibeSurfaceVariant,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(VibeRadius.input),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: VibeSpacing.md),
            Text(
              _error!,
              style: VibeTypography.body.copyWith(
                color: VibeColors.error,
                fontSize: 13,
              ),
            ),
          ],
          const SizedBox(height: VibeSpacing.md),
          SizedBox(
            width: double.infinity,
            height: VibeSizes.buttonHeight,
            child: FilledButton(
              onPressed: _connecting ? null : _connect,
              style: FilledButton.styleFrom(
                backgroundColor: context.vibePrimary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(VibeRadius.button),
                ),
                textStyle: VibeTypography.button,
              ),
              child: _connecting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Подключить'),
            ),
          ),
        ],
      ),
    );
  }

  void _snackCopy() {
    Clipboard.setData(ClipboardData(text: _preview ?? ''));
    _snack('Скопировано');
  }
}

/// Честный статус: онлайн / аварийный / выключен (никакого «захардкоженного
/// онлайн», как в превью).
class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final AurionStatus status;

  @override
  Widget build(BuildContext context) {
    final off = context.vibeTextTertiary;
    final (color, label) = switch (status) {
      AurionStatus.enabled => (VibeColors.success, 'онлайн'),
      AurionStatus.degraded => (VibeColors.warning, 'аварийный'),
      _ => (off, 'выключен'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: VibeSpacing.sm,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(VibeRadius.badge),
      ),
      child: Text(
        label,
        style: VibeTypography.label.copyWith(color: color),
      ),
    );
  }
}

/// AI_PREVIEW (draft-first): ответ не отправляется, пользователь
/// вставляет его в композер сам.
class _PreviewCard extends StatelessWidget {
  const _PreviewCard({
    required this.text,
    required this.onInsert,
    required this.onCopy,
  });

  final String text;
  final VoidCallback onInsert;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(VibeSpacing.md),
      decoration: BoxDecoration(
        color: context.vibeSurface,
        borderRadius: BorderRadius.circular(VibeRadius.card),
        border: Border.all(color: context.vibePrimary.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.auto_awesome_rounded,
                size: 16,
                color: context.vibePrimary,
              ),
              const SizedBox(width: VibeSpacing.xs),
              Text(
                'Ответ Aurion',
                style: VibeTypography.caption.copyWith(
                  color: context.vibePrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: VibeSpacing.sm),
          Text(
            text,
            style: VibeTypography.body.copyWith(
              color: context.vibeTextPrimary,
              height: 1.45,
            ),
          ),
          const SizedBox(height: VibeSpacing.md),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: VibeSpacing.xs,
            runSpacing: VibeSpacing.xs,
            children: [
              TextButton(
                onPressed: onCopy,
                child: const Text('Копировать'),
              ),
              TextButton(
                onPressed: onInsert,
                child: const Text('Вставить в поле'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(VibeSpacing.md),
      decoration: BoxDecoration(
        color: VibeColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(VibeRadius.card),
        border: Border.all(color: VibeColors.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: VibeColors.error, size: 20),
          const SizedBox(width: VibeSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: VibeTypography.body.copyWith(
                color: context.vibeTextPrimary,
                fontSize: 13,
              ),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Повторить')),
        ],
      ),
    );
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