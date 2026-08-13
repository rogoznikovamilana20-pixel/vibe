import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../core/theme/vibe_spacing.dart';
import '../core/theme/vibe_theme.dart';
import '../core/theme/vibe_typography.dart';
import '../core/widgets/vibe_top_bar.dart';
import '../data/backend.dart';
import 'package:vibe_app/core/widgets/vibe_toast.dart';
import 'package:vibe_app/core/widgets/vibe_icon_font.dart';

/// «Мои ссылки» — список ссылок на профиль (как в Telegram
/// «Расширенные права» → ссылки): vibe.me-ссылка, @ник, телефон, QR-код.
/// Каждый пункт — скопировать одним тапом; QR — отдельным шитом.
class MyLinksScreen extends StatefulWidget {
  const MyLinksScreen({super.key, this.userName = ''});

  final String userName;

  @override
  State<MyLinksScreen> createState() => _MyLinksScreenState();
}

class _MyLinksScreenState extends State<MyLinksScreen> {
  String _nick(VibeProfile? p) {
    final u = p?.username;
    if (u != null && u.isNotEmpty) return u;
    return widget.userName.toLowerCase();
  }

  String _link(VibeProfile? p) => 'vibe.me/@${_nick(p)}';

  Future<void> _copy(BuildContext context, String text, String snack) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    VibeToast.show(context, snack);
  }

  void _showQrSheet(BuildContext context, VibeProfile? p) {
    final link = _link(p);
    showModalBottomSheet(
      context: context,
      backgroundColor: context.vibeSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(VibeSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(VibeSpacing.md),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: QrImageView(
                  data: link,
                  size: 220,
                  backgroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: VibeSpacing.lg),
              Text(
                link,
                style: VibeTypography.bodyMedium.copyWith(
                  color: context.vibeTextPrimary,
                ),
              ),
              const SizedBox(height: VibeSpacing.lg),
              FilledButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  _copy(context, link, 'Ссылка скопирована: $link');
                },
                icon: const Icon(VibeIcons.copy, size: 18),
                label: const Text('Копировать ссылку'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          VibeTopBar(
            leading: IconButton(
              icon: const Icon(VibeIcons.back),
              onPressed: () => Navigator.of(context).pop(),
              color: context.vibeTextPrimary,
            ),
            title: const VibeTopBarTitle('Мои ссылки'),
          ),
          Expanded(
            child: ValueListenableBuilder<VibeProfile?>(
              valueListenable: VibeBackend.myProfileNotifier,
              builder: (context, profile, _) {
                final link = _link(profile);
                final nick = _nick(profile);
                final phone = profile?.phone;
                final hasPhone = phone != null && phone.isNotEmpty;
                final rows = <({IconData icon, String title, String value})>[
                  (
                    icon: Icons.link_rounded,
                    title: 'Ссылка на профиль',
                    value: link,
                  ),
                  if (nick.isNotEmpty)
                    (
                      icon: Icons.alternate_email_rounded,
                      title: 'Имя пользователя',
                      value: '@$nick',
                    ),
                  if (hasPhone)
                    (
                      icon: Icons.call_outlined,
                      title: 'Телефон',
                      value: phone,
                    ),
                ];
                return ListView.separated(
                  padding: const EdgeInsets.all(VibeSpacing.lg),
                  itemCount: rows.length + 1,
                  separatorBuilder: (_, _) => const SizedBox(height: VibeSpacing.sm),
                  itemBuilder: (context, i) {
                    if (i == rows.length) {
                      return Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _showQrSheet(context, profile),
                              icon: const Icon(
                                Icons.qr_code_2_rounded,
                                size: 18,
                              ),
                              label: const Text('QR-код профиля'),
                            ),
                          ),
                        ],
                      );
                    }
                    final row = rows[i];
                    return _LinkTile(
                      icon: row.icon,
                      title: row.title,
                      value: row.value,
                      onTap: () =>
                          _copy(context, row.value, 'Скопировано: ${row.value}'),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _LinkTile extends StatelessWidget {
  const _LinkTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.vibeSurfaceVariant,
      borderRadius: BorderRadius.circular(16),
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, color: context.vibePrimary),
        title: Text(
          title,
          style: VibeTypography.bodyMedium.copyWith(
            color: context.vibeTextPrimary,
          ),
        ),
        trailing: Text(
          value,
          style: VibeTypography.caption.copyWith(
            color: context.vibeTextSecondary,
          ),
        ),
      ),
    );
  }
}