import 'package:flutter/material.dart';

import '../core/theme/vibe_spacing.dart';
import '../core/theme/vibe_theme.dart';
import '../core/widgets/vibe_top_bar.dart';

class ReminderScreen extends StatefulWidget {
  const ReminderScreen({super.key});
  @override
  State<ReminderScreen> createState() => _ReminderScreenState();
}

class _ReminderScreenState extends State<ReminderScreen> {
  DateTime _date = DateTime.now().add(const Duration(hours: 1));
  final _text = TextEditingController(text: 'Напоминание');

  Future<void> _schedule() async {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Напоминание на $_date (локально, пуш — TODO)')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.vibeBackground,
      appBar: VibeTopBarAppBar(topInset: MediaQuery.paddingOf(context).top, child: VibeTopBar(leading: VibeTopBarIcon(icon: Icons.arrow_back_rounded, onTap: () => Navigator.maybePop(context), tooltip: 'Назад'), title: const VibeTopBarTitle('Напоминания'))),
      body: Padding(padding: const EdgeInsets.all(VibeSpacing.lg), child: Column(children: [TextField(controller: _text, decoration: const InputDecoration(labelText: 'Текст')), const SizedBox(height: VibeSpacing.md), ListTile(title: Text('Дата: $_date'), trailing: const Icon(Icons.calendar_today_rounded), onTap: () async { final d = await showDatePicker(context: context, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)), initialDate: _date); if (d != null) setState(()=> _date = DateTime(d.year, d.month, d.day, _date.hour, _date.minute)); }), const SizedBox(height: VibeSpacing.lg), FilledButton(onPressed: _schedule, child: const Text('Запланировать'))])),
    );
  }
}
