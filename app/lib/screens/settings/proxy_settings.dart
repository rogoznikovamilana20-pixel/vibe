import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/localization/vibe_localizations.dart';
import '../../core/theme/vibe_colors.dart';
import '../../core/theme/vibe_spacing.dart';
import '../../core/theme/vibe_theme.dart';
import '../../core/theme/vibe_typography.dart';
import '../../core/widgets/settings_widgets.dart';
import '../../core/widgets/vibe_toast.dart';
import '../../core/widgets/vibe_top_bar.dart';
import '../../core/widgets/vibe_icon_font.dart';
import '../../data/settings_service.dart';

class ProxySettingsScreen extends StatefulWidget {
  const ProxySettingsScreen({super.key});

  @override
  State<ProxySettingsScreen> createState() => _ProxySettingsScreenState();
}

class _ProxySettingsScreenState extends State<ProxySettingsScreen> {
  late bool _enabled;
  late String _host;
  late int _port;
  late String _username;
  late String _password;
  late bool _socks5;

  @override
  void initState() {
    super.initState();
    final s = SettingsService.instance;
    _enabled = s.proxyEnabled;
    _host = s.proxyHost;
    _port = s.proxyPort;
    _username = s.proxyUsername;
    _password = '';
    _socks5 = s.proxySocks5;
    _loadPassword();
  }

  Future<void> _loadPassword() async {
    final pw = await SettingsService.instance.proxyPassword();
    if (mounted) setState(() => _password = pw);
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
          title: VibeTopBarTitle(l.proxyTitle),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: VibeSpacing.lg),
        children: [
          SettingsSection(
            title: l.proxyConnection,
            children: [
              SwitchListTile(
                secondary: Icon(
                  Icons.vpn_key_rounded,
                  color: context.vibePrimary,
                ),
                title: Text(l.proxyEnable),
                subtitle: Text(
                  _enabled ? l.proxyConnected : l.proxyDisabled,
                  style: VibeTypography.caption.copyWith(
                    color: _enabled ? context.vibePrimary : context.vibeTextTertiary,
                  ),
                ),
                value: _enabled,
                onChanged: (v) {
                  HapticFeedback.selectionClick();
                  setState(() => _enabled = v);
                  SettingsService.instance.setProxyEnabled(v);
                },
                activeTrackColor: context.vibePrimary.withValues(alpha: 0.3),
                activeThumbColor: context.vibePrimary,
              ),
            ],
          ),
          if (_enabled) ...[
            SettingsSection(
              title: l.proxyServer,
              children: [
                ListTile(
                  leading: Icon(Icons.dns_rounded, color: context.vibePrimary),
                  title: Text(l.proxyHost),
                  subtitle: Text(
                    _host.isEmpty ? l.proxyHostHint : _host,
                    style: VibeTypography.bodyMedium.copyWith(
                      color: _host.isEmpty ? context.vibeTextTertiary : context.vibeTextPrimary,
                    ),
                  ),
                  onTap: _editHost,
                ),
                ListTile(
                  leading: Icon(Icons.numbers_rounded, color: context.vibePrimary),
                  title: Text(l.proxyPort),
                  subtitle: Text(
                    _port > 0 ? '$_port' : l.proxyPortHint,
                    style: VibeTypography.bodyMedium.copyWith(
                      color: _port > 0 ? context.vibeTextPrimary : context.vibeTextTertiary,
                    ),
                  ),
                  onTap: _editPort,
                ),
              ],
            ),
            SettingsSection(
              title: l.proxyType,
              children: [
                ListTile(
                  leading: Icon(Icons.cable_rounded, color: context.vibePrimary),
                  title: const Text('SOCKS5'),
                  trailing: Radio<bool>(
                    value: true,
                    groupValue: _socks5,
                    onChanged: (v) {
                      HapticFeedback.selectionClick();
                      setState(() => _socks5 = true);
                      SettingsService.instance.setProxySocks5(true);
                    },
                    activeColor: context.vibePrimary,
                  ),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _socks5 = true);
                    SettingsService.instance.setProxySocks5(true);
                  },
                ),
                ListTile(
                  leading: Icon(Icons.http_rounded, color: context.vibePrimary),
                  title: const Text('HTTP'),
                  trailing: Radio<bool>(
                    value: false,
                    groupValue: _socks5,
                    onChanged: (v) {
                      HapticFeedback.selectionClick();
                      setState(() => _socks5 = false);
                      SettingsService.instance.setProxySocks5(false);
                    },
                    activeColor: context.vibePrimary,
                  ),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _socks5 = false);
                    SettingsService.instance.setProxySocks5(false);
                  },
                ),
              ],
            ),
            SettingsSection(
              title: l.proxyAuth,
              children: [
                ListTile(
                  leading: Icon(Icons.person_outline_rounded, color: context.vibePrimary),
                  title: Text(l.proxyUsername),
                  subtitle: Text(
                    _username.isEmpty ? l.proxyUsernameHint : _username,
                    style: VibeTypography.bodyMedium.copyWith(
                      color: _username.isEmpty ? context.vibeTextTertiary : context.vibeTextPrimary,
                    ),
                  ),
                  onTap: _editUsername,
                ),
                ListTile(
                  leading: Icon(Icons.lock_outline_rounded, color: context.vibePrimary),
                  title: Text(l.proxyPassword),
                  subtitle: Text(
                    _password.isEmpty ? l.proxyPasswordHint : '••••••',
                    style: VibeTypography.bodyMedium.copyWith(
                      color: _password.isEmpty ? context.vibeTextTertiary : context.vibeTextPrimary,
                    ),
                  ),
                  onTap: _editPassword,
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: VibeSpacing.lg),
              child: FilledButton.icon(
                onPressed: _testConnection,
                icon: const Icon(Icons.wifi_tethering_rounded, size: 18),
                label: Text(l.proxyTest),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _editHost() {
    final ctrl = TextEditingController(text: _host);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(VibeLocalizations.of(context).proxyHost),
        content: TextField(
          controller: ctrl,
          decoration: InputDecoration(
            hintText: 'proxy.example.com',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(VibeLocalizations.of(context).dialogCancel),
          ),
          FilledButton(
            onPressed: () {
              HapticFeedback.selectionClick();
              setState(() => _host = ctrl.text.trim());
              SettingsService.instance.setProxyHost(ctrl.text.trim());
              Navigator.of(ctx).pop();
            },
            child: Text(VibeLocalizations.of(context).dialogSave),
          ),
        ],
      ),
    );
  }

  void _editPort() {
    final ctrl = TextEditingController(text: _port > 0 ? '$_port' : '');
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(VibeLocalizations.of(context).proxyPort),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(hintText: '1080'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(VibeLocalizations.of(context).dialogCancel),
          ),
          FilledButton(
            onPressed: () {
              final p = int.tryParse(ctrl.text.trim());
              if (p != null && p > 0 && p < 65536) {
                HapticFeedback.selectionClick();
                setState(() => _port = p);
                SettingsService.instance.setProxyPort(p);
              }
              Navigator.of(ctx).pop();
            },
            child: Text(VibeLocalizations.of(context).dialogSave),
          ),
        ],
      ),
    );
  }

  void _editUsername() {
    final ctrl = TextEditingController(text: _username);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(VibeLocalizations.of(context).proxyUsername),
        content: TextField(
          controller: ctrl,
          decoration: InputDecoration(hintText: VibeLocalizations.of(context).proxyUsernameHint),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(VibeLocalizations.of(context).dialogCancel),
          ),
          FilledButton(
            onPressed: () {
              HapticFeedback.selectionClick();
              setState(() => _username = ctrl.text.trim());
              SettingsService.instance.setProxyUsername(ctrl.text.trim());
              Navigator.of(ctx).pop();
            },
            child: Text(VibeLocalizations.of(context).dialogSave),
          ),
        ],
      ),
    );
  }

  void _editPassword() {
    final ctrl = TextEditingController(text: _password);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(VibeLocalizations.of(context).proxyPassword),
        content: TextField(
          controller: ctrl,
          obscureText: true,
          decoration: InputDecoration(hintText: VibeLocalizations.of(context).proxyPasswordHint),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(VibeLocalizations.of(context).dialogCancel),
          ),
          FilledButton(
            onPressed: () {
              HapticFeedback.selectionClick();
              setState(() => _password = ctrl.text);
              SettingsService.instance.setProxyPassword(ctrl.text);
              Navigator.of(ctx).pop();
            },
            child: Text(VibeLocalizations.of(context).dialogSave),
          ),
        ],
      ),
    );
  }

  void _testConnection() {
    HapticFeedback.mediumImpact();
    VibeToast.show(context, VibeLocalizations.of(context).proxyTesting);
    // TODO: Real proxy test via Supabase edge function or direct socket.
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        final ok = _host.isNotEmpty && _port > 0;
        VibeToast.show(
          context,
          ok ? VibeLocalizations.of(context).proxyTestOk : VibeLocalizations.of(context).proxyTestFail,
        );
      }
    });
  }
}
