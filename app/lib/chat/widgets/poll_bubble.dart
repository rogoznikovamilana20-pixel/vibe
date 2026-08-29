import 'package:flutter/material.dart';

import '../../core/theme/vibe_spacing.dart';
import '../../core/theme/vibe_theme.dart';
import '../../core/theme/vibe_typography.dart';

class PollBubble extends StatefulWidget {
  const PollBubble({super.key, required this.question, required this.options, required this.incoming});
  final String question;
  final List<String> options;
  final bool incoming;
  @override
  State<PollBubble> createState() => _PollBubbleState();
}

class _PollBubbleState extends State<PollBubble> {
  int? _voted;
  final _counts = <int>[];
  @override
  void initState() { super.initState(); _counts.addAll(List.filled(widget.options.length, 0)); }

  @override
  Widget build(BuildContext context) {
    final total = _counts.fold(0, (a,b)=>a+b);
    return Container(
      padding: const EdgeInsets.all(VibeSpacing.md),
      decoration: BoxDecoration(color: widget.incoming ? context.vibeSurfaceHigh : const Color(0xFF7C4DFF), borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(widget.question, style: VibeTypography.bodyMedium.copyWith(color: widget.incoming ? context.vibeTextPrimary : Colors.white, fontWeight: FontWeight.w600)),
        const SizedBox(height: VibeSpacing.sm),
        for (int i=0;i<widget.options.length;i++) Padding(padding: const EdgeInsets.only(bottom: 6), child: InkWell(onTap: ()=> setState((){ if(_voted==null){_voted=i; _counts[i]++;} }), borderRadius: BorderRadius.circular(8), child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), decoration: BoxDecoration(border: Border.all(color: _voted==i ? context.vibePrimary : context.vibeBorder), borderRadius: BorderRadius.circular(8), color: _voted==i ? context.vibePrimary.withValues(alpha:0.12) : Colors.transparent), child: Row(children: [Expanded(child: Text(widget.options[i], style: VibeTypography.body.copyWith(color: widget.incoming ? context.vibeTextPrimary : Colors.white))), if(total>0) Text('${(_counts[i]*100~/ (total==0?1:total))}%', style: VibeTypography.caption.copyWith(color: widget.incoming ? context.vibeTextSecondary : Colors.white70))])))),
      ]),
    );
  }
}
