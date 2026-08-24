import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/localization/vibe_localizations.dart';
import '../core/theme/vibe_spacing.dart';
import '../core/theme/vibe_theme.dart';
import '../core/theme/vibe_typography.dart';
import '../core/widgets/vibe_icon_button.dart';
import '../core/widgets/vibe_top_bar.dart';
import '../data/account_service.dart';
import '../data/backend.dart';
import 'package:vibe_app/core/widgets/vibe_icon_font.dart';
import '../core/widgets/vibe_toast.dart';

/// Переключатель аккаунтов как в ТГ: до 3 аккаунтов, тап — переключение сессии.
class AccountSwitcherScreen extends StatefulWidget {
  const AccountSwitcherScreen({super.key});

  @override
  State<AccountSwitcherScreen> createState() => _AccountSwitcherScreenState();
}

class _AccountSwitcherScreenState extends State<AccountSwitcherScreen> {
  bool _switching = false;

  @override
  Widget build(BuildContext context) {
    final l = VibeLocalizations.of(context);
    final svc = AccountService.instance;
    final accounts = svc.accounts;
    final curIdx = svc.currentIndex;
    final me = VibeBackend.myProfileNotifier.value;

    return Scaffold(
      backgroundColor: context.vibeBackground,
      appBar: VibeTopBarAppBar(
        topInset: MediaQuery.paddingOf(context).top,
        child: VibeTopBar(
          leading: VibeIconButton(
            icon: VibeIcons.back,
            onPressed: () => Navigator.of(context).maybePop(),
            tooltip: l.tooltipBack,
          ),
          title: VibeTopBarTitle(l.profileAddAccount),
        ),
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(VibeSpacing.lg),
            children: [
              if (me != null)
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: context.vibePrimary.withValues(alpha: 0.15),
                    child: Text(me.displayName.isNotEmpty ? me.displayName[0].toUpperCase() : 'Я',
                        style: TextStyle(color: context.vibePrimary)),
                  ),
                  title: Text(me.displayName.isEmpty ? 'Я' : me.displayName,
                      style: VibeTypography.body.copyWith(color: context.vibeTextPrimary, fontWeight: FontWeight.w600)),
                  subtitle: Text('@${me.username.isEmpty ? 'нет ника' : me.username}',
                      style: VibeTypography.caption.copyWith(color: context.vibeTextSecondary)),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: context.vibePrimary, borderRadius: BorderRadius.circular(8)),
                    child: const Text('Активен', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                  ),
                ),
              const SizedBox(height: VibeSpacing.md),
              const Divider(height: 1),
              const SizedBox(height: VibeSpacing.md),
              if (accounts.isNotEmpty) ...[
                Text('Сохранённые аккаунты (${accounts.length}/3)',
                    style: VibeTypography.caption.copyWith(color: context.vibeTextTertiary)),
                const SizedBox(height: VibeSpacing.sm),
                for (var i = 0; i < accounts.length; i++)
                  Dismissible(
                    key: ValueKey('acc_$i:${accounts[i].phone}'),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 16),
                      decoration: BoxDecoration(
                        color: context.vibeError,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
                    ),
                    confirmDismiss: (_) async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text('Удалить аккаунт?'),
                          content: Text('Аккаунт ${accounts[i].phone} будет удалён с устройства.'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Отмена')),
                            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Удалить')),
                          ],
                        ),
                      );
                      return ok == true;
                    },
                    onDismissed: (_) async {
                      await svc.removeAccount(i);
                      if (mounted) setState(() {});
                      if (context.mounted) VibeToast.show(context, 'Аккаунт удалён');
                    },
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: i == curIdx ? context.vibePrimary : Colors.grey.shade300,
                        child: Icon(VibeIcons.user, color: Colors.white, size: 20),
                      ),
                      title: Text(
                        accounts[i].displayName.isNotEmpty ? accounts[i].displayName : accounts[i].phone,
                        style: VibeTypography.body.copyWith(color: context.vibeTextPrimary),
                      ),
                      subtitle: Text(accounts[i].phone,
                          style: VibeTypography.caption.copyWith(color: context.vibeTextSecondary)),
                      trailing: i == curIdx
                          ? Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration:
                                  BoxDecoration(color: context.vibePrimary, borderRadius: BorderRadius.circular(8)),
                              child: const Text('Текущий',
                                  style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                            )
                          : const Icon(Icons.chevron_right_rounded),
                      onTap: _switching
                          ? null
                          : () async {
                              if (i == curIdx) return;
                              HapticFeedback.selectionClick();
                              setState(() => _switching = true);
                              final ok = await svc.switchToAccount(i);
                              if (!mounted) return;
                              setState(() => _switching = false);
                              if (ok) {
                                if (context.mounted) VibeToast.show(context, 'Переключено на ${accounts[i].phone}');
                                if (mounted) setState(() {});
                              } else {
                                if (context.mounted) VibeToast.show(context, 'Не удалось переключить аккаунт');
                              }
                            },
                    ),
                  ),
                const SizedBox(height: VibeSpacing.md),
              ],
              ListTile(
                enabled: !_switching && accounts.length < 3,
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: accounts.length >= 3 ? Colors.grey : context.vibePrimary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.add_rounded, color: Colors.white),
                ),
                title: Text('Добавить аккаунт',
                    style: VibeTypography.body.copyWith(
                        color: accounts.length >= 3 ? Colors.grey : context.vibePrimary, fontWeight: FontWeight.w600)),
                subtitle: Text(
                  accounts.length >= 3 ? 'Достигнут лимит 3 аккаунта' : 'до 3 аккаунтов как в ТГ',
                  style: VibeTypography.caption.copyWith(color: context.vibeTextSecondary),
                ),
                onTap: accounts.length >= 3 || _switching
                    ? null
                    : () async {
                        HapticFeedback.mediumImpact();
                        // Открываем экран логина для добавления нового аккаунта
                        // Новый аккаунт сохранится через AccountService.saveAccount в AuthScreen
                        if (!mounted) return;
                        // Просто подсказка — юзер должен выйти и залогиниться заново,
                        // либо мы могли бы сразу пушить AuthScreen.
                        // Для MVP — показываем диалог с инструкцией.
                        if (context.mounted) {
                          VibeToast.show(context, 'Выйдите и войдите другим номером — он сохранится');
                        }
                      },
              ),
              const SizedBox(height: VibeSpacing.lg),
              Text(
                'Мультиаккаунт как в Телеграме: до 3 аккаунтов, тап для переключения, свайп влево — удалить. Пароли в защищённом хранилище.',
                style: VibeTypography.caption.copyWith(color: context.vibeTextTertiary),
              ),
            ],
          ),
          if (_switching)
            Container(
              color: Colors.black38,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 12),
                    Text('Переключение…', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
