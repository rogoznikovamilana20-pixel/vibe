import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/vibe_spacing.dart';
import '../../core/theme/vibe_theme.dart';
import '../../core/theme/vibe_typography.dart';
import '../../core/widgets/vibe_top_bar.dart';

class BusinessShowcasesScreen extends StatefulWidget {
  const BusinessShowcasesScreen({super.key, required this.businessId});
  final String businessId;
  @override
  State<BusinessShowcasesScreen> createState() => _BusinessShowcasesScreenState();
}

class _BusinessShowcasesScreenState extends State<BusinessShowcasesScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final rows = await Supabase.instance.client.from('business_showcases').select().eq('business_id', widget.businessId).order('created_at');
      if (mounted) setState(() { _items = List<Map<String, dynamic>>.from(rows); _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _add() async {
    final c = TextEditingController();
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: const Text('Новая витрина'), content: TextField(controller: c, decoration: const InputDecoration(hintText: 'Название')), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')), TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Создать'))]));
    if (ok != true || c.text.trim().isEmpty) return;
    try {
      await Supabase.instance.client.from('business_showcases').insert({'business_id': widget.businessId, 'title': c.text.trim()});
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.vibeBackground,
      appBar: VibeTopBarAppBar(topInset: MediaQuery.paddingOf(context).top, child: VibeTopBar(leading: VibeTopBarIcon(icon: Icons.arrow_back_rounded, onTap: () => Navigator.maybePop(context), tooltip: 'Назад'), title: const VibeTopBarTitle('Витрины'), actions: [IconButton(icon: const Icon(Icons.add_rounded), onPressed: _add)])),
      body: _loading ? const Center(child: CircularProgressIndicator()) : _items.isEmpty ? Center(child: Text('Нет витрин', style: VibeTypography.body.copyWith(color: context.vibeTextSecondary))) : ListView.builder(padding: const EdgeInsets.all(VibeSpacing.lg), itemCount: _items.length, itemBuilder: (_, i) => Card(color: context.vibeSurface, child: ListTile(title: Text(_items[i]['title'] ?? '', style: VibeTypography.bodyMedium.copyWith(color: context.vibeTextPrimary)), subtitle: Text(_items[i]['is_active'] == false ? 'Неактивна' : 'Активна', style: VibeTypography.caption.copyWith(color: context.vibeTextSecondary)), trailing: IconButton(icon: const Icon(Icons.delete_outline_rounded), onPressed: () async { await Supabase.instance.client.from('business_showcases').delete().eq('id', _items[i]['id']); await _load(); })))),
    );
  }
}
