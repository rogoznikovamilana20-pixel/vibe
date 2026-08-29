import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/vibe_spacing.dart';
import '../../core/theme/vibe_theme.dart';
import '../../core/theme/vibe_typography.dart';
import '../../core/widgets/vibe_top_bar.dart';

class BusinessMembersScreen extends StatefulWidget {
  const BusinessMembersScreen({super.key, required this.businessId});
  final String businessId;
  @override
  State<BusinessMembersScreen> createState() => _BusinessMembersScreenState();
}

class _BusinessMembersScreenState extends State<BusinessMembersScreen> {
  List<Map<String,dynamic>> _members=[];
  bool _loading=true;
  @override
  void initState(){ super.initState(); _load(); }
  Future<void> _load() async {
    try{
      final rows = await Supabase.instance.client.from('business_members').select().eq('business_id', widget.businessId);
      if(mounted) setState(()=> _members=List<Map<String,dynamic>>.from(rows));
    }catch(_){}
    if(mounted) setState(()=> _loading=false);
  }
  Future<void> _add() async {
    final c=TextEditingController();
    final ok=await showDialog<bool>(context: context, builder: (ctx)=> AlertDialog(title: const Text('Добавить сотрудника'), content: TextField(controller: c, decoration: const InputDecoration(hintText: 'user_id (UUID)')), actions: [TextButton(onPressed: ()=> Navigator.pop(ctx,false), child: const Text('Отмена')), TextButton(onPressed: ()=> Navigator.pop(ctx,true), child: const Text('Добавить'))]));
    if(ok!=true||c.text.trim().isEmpty) return;
    try{ await Supabase.instance.client.from('business_members').insert({'business_id': widget.businessId, 'user_id': c.text.trim(), 'role': 'employee'}); await _load(); }catch(e){ if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e'))); }
  }
  @override
  Widget build(BuildContext context){
    return Scaffold(
      backgroundColor: context.vibeBackground,
      appBar: VibeTopBarAppBar(topInset: MediaQuery.paddingOf(context).top, child: VibeTopBar(leading: VibeTopBarIcon(icon: Icons.arrow_back_rounded, onTap: ()=> Navigator.maybePop(context), tooltip: 'Назад'), title: const VibeTopBarTitle('Команда'), actions: [IconButton(icon: const Icon(Icons.person_add_rounded), onPressed: _add)])),
      body: _loading? const Center(child: CircularProgressIndicator()): _members.isEmpty? Center(child: Text('Нет сотрудников', style: VibeTypography.body.copyWith(color: context.vibeTextSecondary))): ListView.builder(padding: const EdgeInsets.all(VibeSpacing.lg), itemCount: _members.length, itemBuilder: (_,i){ final m=_members[i]; return Card(color: context.vibeSurface, child: ListTile(title: Text(m['user_id'].toString().substring(0,8), style: VibeTypography.bodyMedium.copyWith(color: context.vibeTextPrimary)), subtitle: Text(m['role']??'', style: VibeTypography.caption.copyWith(color: context.vibeTextSecondary)), trailing: IconButton(icon: const Icon(Icons.remove_circle_outline_rounded), onPressed: () async { await Supabase.instance.client.from('business_members').delete().eq('business_id', widget.businessId).eq('user_id', m['user_id']); await _load(); })) ); }),
    );
  }
}
