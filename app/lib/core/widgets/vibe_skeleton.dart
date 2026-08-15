import 'package:flutter/material.dart';
import '../theme/vibe_colors.dart';

/// Анимированный скелетон-плейсхолдер (как в Telegram).
/// Пульсирует градиентом от surfaceVariant к surface.
class VibeSkeleton extends StatefulWidget {
  const VibeSkeleton({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8,
    this.isCircle = false,
  });

  final double width;
  final double height;
  final double borderRadius;
  final bool isCircle;

  @override
  State<VibeSkeleton> createState() => _VibeSkeletonState();
}

class _VibeSkeletonState extends State<VibeSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _animation = Tween<double>(begin: 0.3, end: 0.7).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor =
        isDark
            ? VibeColors.surface2Dark.withValues(alpha: 0.6)
            : VibeColors.surface2Light.withValues(alpha: 0.6);
    final highlightColor =
        isDark
            ? VibeColors.surface2Dark.withValues(alpha: 0.9)
            : VibeColors.surface2Light.withValues(alpha: 0.9);

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.isCircle ? widget.width : null,
          height: widget.height,
          decoration: BoxDecoration(
            color: Color.lerp(baseColor, highlightColor, _animation.value),
            borderRadius: widget.isCircle
                ? BorderRadius.circular(widget.width / 2)
                : BorderRadius.circular(widget.borderRadius),
          ),
        );
      },
    );
  }
}

/// Скелетон строки чата (аватар + текст) с shimmer-эффектом.
class ChatListSkeleton extends StatefulWidget {
  const ChatListSkeleton({super.key, this.count = 8});

  final int count;

  @override
  State<ChatListSkeleton> createState() => _ChatListSkeletonState();
}

class _ChatListSkeletonState extends State<ChatListSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        widget.count,
        (i) => _ShimmerTile(controller: _controller, index: i),
      ),
    );
  }
}

class _ShimmerTile extends StatelessWidget {
  const _ShimmerTile({required this.controller, required this.index});

  final AnimationController controller;
  final int index;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final shimmerColor = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.04);
    final highlightColor = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.black.withValues(alpha: 0.08);

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final offset = (index * 0.1) % 1.0;
        final progress = (controller.value + offset) % 1.0;
        final dx = -1.0 + progress * 2.0;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: [
              _ShimmerBox(
                width: 52, height: 52, radius: 26,
                shimmerColor: shimmerColor, highlightColor: highlightColor, dx: dx,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _ShimmerBox(
                          width: 120 + (index % 3) * 20.0, height: 14, radius: 7,
                          shimmerColor: shimmerColor, highlightColor: highlightColor, dx: dx,
                        ),
                        const Spacer(),
                        _ShimmerBox(
                          width: 36, height: 10, radius: 5,
                          shimmerColor: shimmerColor, highlightColor: highlightColor, dx: dx,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _ShimmerBox(
                      width: double.infinity, height: 12, radius: 6,
                      shimmerColor: shimmerColor, highlightColor: highlightColor, dx: dx,
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
}

class _ShimmerBox extends StatelessWidget {
  const _ShimmerBox({
    required this.width,
    required this.height,
    required this.radius,
    required this.shimmerColor,
    required this.highlightColor,
    required this.dx,
  });

  final double width;
  final double height;
  final double radius;
  final Color shimmerColor;
  final Color highlightColor;
  final double dx;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          begin: Alignment(-1.0 + dx * 0.5, 0),
          end: Alignment(1.0 + dx * 0.5, 0),
          colors: [shimmerColor, highlightColor, shimmerColor],
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
    );
  }
}

/// Скелетон сообщения в чате.
class ChatMessageSkeleton extends StatelessWidget {
  const ChatMessageSkeleton({super.key, this.isMe = false});

  final bool isMe;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: EdgeInsets.only(
          left: isMe ? 64 : 16,
          right: isMe ? 16 : 64,
          top: 4,
          bottom: 4,
        ),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            VibeSkeleton(
              width: 180 + (isMe ? 20.0 : 0),
              height: 44,
              borderRadius: 16,
            ),
            const SizedBox(height: 4),
            const VibeSkeleton(width: 40, height: 8),
          ],
        ),
      ),
    );
  }
}
