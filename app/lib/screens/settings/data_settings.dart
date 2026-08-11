import 'package:flutter/material.dart';
import '../../core/localization/vibe_localizations.dart';
import '../../core/theme/vibe_spacing.dart';
import '../../core/theme/vibe_theme.dart';
import '../../core/theme/vibe_typography.dart';
import '../../core/widgets/settings_widgets.dart';
import '../../core/widgets/vibe_top_bar.dart';
import '../../data/settings_service.dart';

class DataSettingsScreen extends StatefulWidget {
  const DataSettingsScreen({super.key});

  @override
  State<DataSettingsScreen> createState() => _DataSettingsScreenState();
}

class _DataSettingsScreenState extends State<DataSettingsScreen> {
  late bool _mobile;
  late bool _wifi;
  late bool _roaming;

  @override
  void initState() {
    super.initState();
    final s = SettingsService.instance;
    _mobile = s.autoMediaMobile;
    _wifi = s.autoMediaWifi;
    _roaming = s.autoMediaRoaming;
  }

  @override
  Widget build(BuildContext context) {
    final l = VibeLocalizations.of(context);

    return Scaffold(
      backgroundColor: context.vibeBackground,
      appBar: VibeTopBarAppBar(
        topInset: MediaQuery.paddingOf(context).top,
        child: VibeTopBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => Navigator.of(context).pop(),
            color: context.vibeTextPrimary,
          ),
          title: VibeTopBarTitle(l.data),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(VibeSpacing.lg),
        children: [
          SettingsSection(
            title: l.storageUsage,
            children: [
              SettingsTile(
                icon: Icons.pie_chart_outline_rounded,
                iconColor: context.vibePrimary,
                title: l.storageUsage,
                subtitle: l.locale.languageCode == 'ru' ? '124 МБ кэша' : '124 MB cache',
                onTap: () {},
              ),
              SettingsTile(
                icon: Icons.data_usage_rounded,
                iconColor: context.vibePrimary,
                title: l.networkUsage,
                subtitle: l.locale.languageCode == 'ru' ? 'Всего передано: 1.2 ГБ' : 'Total sent: 1.2 GB',
                onTap: () {},
              ),
            ],
          ),
          const SizedBox(height: VibeSpacing.lg),
          SettingsSection(
            title: l.autoMediaDownload,
            children: [
              _buildDataTile(
                context,
                l.mobileNetwork,
                l.locale.languageCode == 'ru' ? 'Фото, Видео (до 10 МБ)' : 'Photos, Videos (up to 10 MB)',
                _mobile,
                (v) {
                  setState(() => _mobile = v);
                  SettingsService.instance.setAutoMediaMobile(v);
                },
              ),
              _buildDataTile(
                context,
                l.wiFi,
                l.locale.languageCode == 'ru' ? 'Все файлы' : 'All files',
                _wifi,
                (v) {
                  setState(() => _wifi = v);
                  SettingsService.instance.setAutoMediaWifi(v);
                },
              ),
              _buildDataTile(
                context,
                l.roaming,
                l.off,
                _roaming,
                (v) {
                  setState(() => _roaming = v);
                  SettingsService.instance.setAutoMediaRoaming(v);
                },
              ),
            ],
          ),
          const SizedBox(height: VibeSpacing.lg),
          SettingsSection(
            title: l.calls,
            children: [
              SettingsTile(
                icon: Icons.call_outlined,
                iconColor: context.vibePrimary,
                title: l.dataSaver,
                subtitle: l.locale.languageCode == 'ru' ? 'Никогда' : 'Never',
                onTap: () {},
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDataTile(
    BuildContext context,
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: VibeSpacing.lg),
      title: Text(
        title,
        style: VibeTypography.bodyMedium.copyWith(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        subtitle,
        style: VibeTypography.caption.copyWith(color: context.vibeTextSecondary),
      ),
      trailing: Switch(value: value, onChanged: onChanged),
    );
  }
}
