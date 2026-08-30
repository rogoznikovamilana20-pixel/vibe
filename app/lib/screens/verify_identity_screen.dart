import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../core/theme/vibe_spacing.dart';
import '../core/theme/vibe_theme.dart';
import '../core/theme/vibe_typography.dart';
import '../core/widgets/vibe_top_bar.dart';
import '../data/e2e_v2_identity_verification.dart';

class VerifyIdentityScreen extends StatefulWidget {
  const VerifyIdentityScreen({super.key, required this.peerId, required this.identityKeyB64});
  final String peerId;
  final String identityKeyB64;
  @override
  State<VerifyIdentityScreen> createState() => _VerifyIdentityScreenState();
}

class _VerifyIdentityScreenState extends State<VerifyIdentityScreen> {
  String _code = '...';
  IdentityTrustState _trust = IdentityTrustState.unknown;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final c = await E2eV2IdentityVerification.generateFingerprintFromBase64(widget.identityKeyB64);
    final t = await E2eV2IdentityVerification.instance.getTrustState(widget.peerId);
    if (mounted) setState(()=> _code = c);
    if (mounted) setState(()=> _trust = t);
  }

  Future<void> _verify() async {
    await E2eV2IdentityVerification.instance.verifyIdentity(peerId: widget.peerId, identityKey: base64Decode(widget.identityKeyB64));
    if (mounted) setState(()=> _trust = IdentityTrustState.verified);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Верифицировано')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.vibeBackground,
      appBar: VibeTopBarAppBar(topInset: MediaQuery.paddingOf(context).top, child: VibeTopBar(leading: VibeTopBarIcon(icon: Icons.arrow_back_rounded, onTap: ()=> Navigator.maybePop(context), tooltip: 'Назад'), title: const VibeTopBarTitle('Безопасность'))),
      body: Padding(padding: const EdgeInsets.all(VibeSpacing.lg), child: Column(children: [
        Semantics(label: 'QR код безопасности для ${widget.peerId}', child: QrImageView(data: widget.identityKeyB64, version: QrVersions.auto, size: 200, backgroundColor: Colors.white)),
        const SizedBox(height: VibeSpacing.lg),
        Text('Код безопасности', style: VibeTypography.caption.copyWith(color: context.vibeTextSecondary)),
        const SizedBox(height: VibeSpacing.sm),
        Semantics(label: 'Код безопасности $_code', child: SelectableText(_code, textAlign: TextAlign.center, style: VibeTypography.body.copyWith(letterSpacing: 0.5, color: context.vibeTextPrimary))),
        const SizedBox(height: VibeSpacing.md),
        Text('Статус: ${_trust.name}', style: VibeTypography.caption.copyWith(color: _trust==IdentityTrustState.verified? Colors.green : context.vibeTextTertiary)),
        const SizedBox(height: VibeSpacing.lg),
        FilledButton.icon(icon: const Icon(Icons.verified_rounded), label: const Text('Верифицировать'), onPressed: _trust==IdentityTrustState.verified? null : _verify),
        const SizedBox(height: VibeSpacing.sm),
        Text('Сравните код лично или отсканируйте QR на устройстве собеседника', textAlign: TextAlign.center, style: VibeTypography.caption.copyWith(color: context.vibeTextTertiary)),
      ])),
    );
  }
}
