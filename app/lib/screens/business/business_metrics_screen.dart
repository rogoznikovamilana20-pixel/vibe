import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/vibe_spacing.dart';
import '../../core/theme/vibe_theme.dart';
import '../../core/theme/vibe_typography.dart';
import '../../core/widgets/vibe_top_bar.dart';

class BusinessMetricsScreen extends StatefulWidget {
  const BusinessMetricsScreen({super.key, required this.businessId});
  final String businessId;
  @override
  State<BusinessMetricsScreen> createState() => _BusinessMetricsScreenState();
}

class _BusinessMetricsScreenState extends State<BusinessMetricsScreen> {
  List<Map<String, dynamic>> _rows = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final rows = await Supabase.instance.client.from('business_metrics_daily').select().eq('business_id', widget.businessId).order('date', ascending: false).limit(14);
      if (mounted) setState(() { _rows = List<Map<String,dynamic>>.from(rows); _loading = false; });
    } catch (_) { if (mounted) setState(()=> _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.vibeBackground,
      appBar: VibeTopBarAppBar(topInset: MediaQuery.paddingOf(context).top, child: VibeTopBar(leading: VibeTopBarIcon(icon: Icons.arrow_back_rounded, onTap: ()=> Navigator.maybePop(context), tooltip: 'Назад'), title: const VibeTopBarTitle('Метрики'))),
      body: _loading ? const Center(child: CircularProgressIndicator()) : _rows.isEmpty ? Center(child: Text('Нет данных (нужна активность)', style: VibeTypography.body.copyWith(color: context.vibeTextSecondary))) : Column(children: [_buildChart(context), Expanded(child: ListView.builder(padding: const EdgeInsets.all(VibeSpacing.lg), itemCount: _rows.length, itemBuilder: (_, i) { final r=_rows[i]; return Card(color: context.vibeSurface, child: ListTile(title: Text('${r['date']}', style: VibeTypography.bodyMedium.copyWith(color: context.vibeTextPrimary)), subtitle: Text('Просм: ${r['views']} • Клик: ${r['clicks']} • Заказ: ${r['orders']} • ${r['revenue']}₽', style: VibeTypography.caption.copyWith(color: context.vibeTextSecondary)))); }))]),
    );
  }

  Widget _buildChart(BuildContext context) {
    if (_rows.isEmpty) return const SizedBox.shrink();
    final views = _rows.map((e) => (e['views'] as int?) ?? 0).toList().reversed.toList();
    final maxV = views.isEmpty ? 1 : views.reduce((a,b)=> a>b?a:b);
    final m = maxV == 0 ? 1 : maxV;
    return Container(
      height: 120,
      padding: const EdgeInsets.all(VibeSpacing.lg),
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [for (final v in views) Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 2), child: Container(height: 80 * v / m + 8, decoration: BoxDecoration(color: context.vibePrimary.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(4)))))]),
    );
  }
}
