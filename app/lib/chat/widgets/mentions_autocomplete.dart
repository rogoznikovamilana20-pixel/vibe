import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/vibe_colors.dart';
import '../../core/theme/vibe_spacing.dart';
import '../../core/theme/vibe_theme.dart';
import '../../core/theme/vibe_typography.dart';
import '../../core/widgets/vibe_avatar.dart';
import '../../data/backend.dart';

/// Telegram-style @mentions autocomplete overlay.
/// Shows a list of matching contacts when user types @ in the input.
class MentionsAutocomplete extends StatefulWidget {
  const MentionsAutocomplete({
    super.key,
    required this.query,
    required this.onMentionSelected,
    required this.child,
  });

  final String query;
  final ValueChanged<String> onMentionSelected;
  final Widget child;

  @override
  State<MentionsAutocomplete> createState() => _MentionsAutocompleteState();
}

class _MentionsAutocompleteState extends State<MentionsAutocomplete>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _slideAnim;
  List<VibeProfile> _results = [];
  bool _showOverlay = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _slideAnim = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void didUpdateWidget(covariant MentionsAutocomplete oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.query != oldWidget.query) {
      _searchMentions(widget.query);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _searchMentions(String query) async {
    if (query.isEmpty) {
      if (_showOverlay) {
        setState(() {
          _showOverlay = false;
          _results = [];
        });
        _controller.reverse();
      }
      return;
    }

    try {
      final results = await VibeBackend.instance.searchUsers(query);
      if (!mounted) return;
      setState(() {
        _results = results.take(5).toList();
        _showOverlay = _results.isNotEmpty;
      });
      if (_showOverlay) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    } catch (_) {
      // Silently fail
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        widget.child,
        if (_showOverlay)
          Positioned(
            left: 0,
            right: 0,
            bottom: 56,
            child: AnimatedBuilder(
              animation: _slideAnim,
              builder: (context, child) => Opacity(
                opacity: _slideAnim.value,
                child: Transform.translate(
                  offset: Offset(0, 8 * (1 - _slideAnim.value)),
                  child: child,
                ),
              ),
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(VibeRadius.lg),
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 200),
                  decoration: BoxDecoration(
                    color: context.isDarkMode
                        ? VibeColors.surface2Dark
                        : VibeColors.surface2Light,
                    borderRadius: BorderRadius.circular(VibeRadius.lg),
                    border: Border.all(
                      color: context.vibeDivider,
                      width: 0.5,
                    ),
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(vertical: VibeSpacing.xs),
                    itemCount: _results.length,
                    itemBuilder: (context, index) {
                      final user = _results[index];
                      return InkWell(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          widget.onMentionSelected(user.username.isNotEmpty ? user.username : user.displayName);
                          setState(() {
                            _showOverlay = false;
                            _results = [];
                          });
                          _controller.reverse();
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: VibeSpacing.md,
                            vertical: VibeSpacing.sm,
                          ),
                          child: Row(
                            children: [
                              VibeAvatar(
                                name: user.displayName,
                                size: 32,
                                photo: null,
                              ),
                              const SizedBox(width: VibeSpacing.sm),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      user.displayName,
                                      style: VibeTypography.body.copyWith(
                                        fontWeight: FontWeight.w500,
                                        color: context.vibeTextPrimary,
                                      ),
                                    ),
                                    if (user.username.isNotEmpty)
                                      Text(
                                        '@${user.username}',
                                        style: VibeTypography.caption.copyWith(
                                          color: context.vibeTextSecondary,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
