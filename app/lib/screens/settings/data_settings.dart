import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/localization/vibe_localizations.dart';
import '../../core/theme/vibe_spacing.dart';
import '../../core/theme/vibe_theme.dart';
import '../../core/theme/vibe_typography.dart';
import '../../core/widgets/settings_widgets.dart';
import '../../core/widgets/vibe_toast.dart';
import '../../core/widgets/vibe_top_bar.dart';
import '../../data/settings_service.dart';
import 'package:vibe_app/core/widgets/vibe_icon_font.dart';

class DataSettingsScreen extends StatefulWidget {
  const DataSettingsScreen({super.key});

  @override
  State<DataSettingsScreen> createState() => _DataSettingsScreenState();
}

class _DataSettingsScreenState extends State<DataSettingsScreen> {
  late bool _mobile;
  late bool _wifi;
  late bool _roaming;
  String _cacheSize = '...';
  bool _clearing = false;
  Map<String, int> _cacheByType = {};

  @override
  void initState() {
    super.initState();
    final s = SettingsService.instance;
    _mobile = s.autoMediaMobile;
    _wifi = s.autoMediaWifi;
    _roaming = s.autoMediaRoaming;
    _calculateCacheSize();
  }

  Future<void> _calculateCacheSize() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final cacheDir = await getApplicationCacheDirectory();
      int total = 0;
      final byType = <String, int>{};

      for (final dir in [tempDir, cacheDir]) {
        if (!await dir.exists()) continue;
        await for (final entity in dir.list(recursive: true, followLinks: false)) {
          if (entity is File) {
            final size = await entity.length();
            total += size;
            final name = entity.path.toLowerCase();
            String type = 'Другое';
            if (name.endsWith('.gif') || name.endsWith('.mp4') || name.endsWith('.webm')) {
              type = 'Видео/GIF';
            } else if (name.endsWith('.jpg') || name.endsWith('.jpeg') || name.endsWith('.png') || name.endsWith('.webp')) {
              type = 'Фото';
            } else if (name.endsWith('.ogg') || name.endsWith('.aac') || name.endsWith('.m4a') || name.contains('voice')) {
              type = 'Голосовые';
            } else if (name.contains('vibe_gifs')) {
              type = 'GIF';
            }
            byType[type] = (byType[type] ?? 0) + size;
          }
        }
      }
      if (mounted) {
        setState(() {
          _cacheSize = _formatSize(total);
          _cacheByType = byType;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _cacheSize = '?');
    }
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes Б';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} КБ';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} МБ';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} ГБ';
  }

  Future<void> _clearCache() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.vibeSurface,
        title: Text('Очистить кэш?', style: TextStyle(color: context.vibeTextPrimary)),
        content: SizedBox(
          width: 300,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Общий размер: $_cacheSize',
                style: TextStyle(color: context.vibeTextSecondary),
              ),
              const SizedBox(height: 12),
              ..._cacheByType.entries.map((e) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(e.key, style: TextStyle(color: context.vibeTextPrimary)),
                    Text(_formatSize(e.value),
                        style: TextStyle(color: context.vibeTextSecondary)),
                  ],
                ),
              )),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Отмена', style: TextStyle(color: context.vibePrimary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Очистить всё', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _clearing = true);
    try {
      final tempDir = await getTemporaryDirectory();
      final cacheDir = await getApplicationCacheDirectory();
      if (await tempDir.exists()) {
        await _deleteDirContents(tempDir);
      }
      if (await cacheDir.exists()) {
        await _deleteDirContents(cacheDir);
      }
      await _calculateCacheSize();
      if (mounted) VibeToast.show(context, 'Кэш очищен');
    } catch (e) {
      if (mounted) VibeToast.show(context, 'Ошибка очистки');
    } finally {
      if (mounted) setState(() => _clearing = false);
    }
  }

  Future<void> _deleteDirContents(Directory dir) async {
    try {
      await for (final entity in dir.list(recursive: false, followLinks: false)) {
        if (entity is File) {
          await entity.delete();
        } else if (entity is Directory) {
          await entity.delete(recursive: true);
        }
      }
    } catch (_) {}
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
            icon: const Icon(VibeIcons.back),
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
                title: 'Очистить кэш',
                subtitle: _cacheSize,
                onTap: _clearing ? null : _clearCache,
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
      trailing: Switch(
        value: value,
        onChanged: (v) {
          HapticFeedback.selectionClick();
          onChanged(v);
        },
      ),
    );
  }
}
