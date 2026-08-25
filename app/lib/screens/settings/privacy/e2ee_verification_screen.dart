import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/localization/vibe_localizations.dart';
import '../../../core/theme/vibe_colors.dart';
import '../../../core/theme/vibe_spacing.dart';
import '../../../core/theme/vibe_theme.dart';
import '../../../core/theme/vibe_typography.dart';
import '../../../core/widgets/vibe_button.dart';
import '../../../core/widgets/vibe_top_bar.dart';
import '../../../core/widgets/vibe_toast.dart';
import '../../../data/e2e_v2_identity_verification.dart';

/// E2EE Identity Verification Screen.
///
/// Displays the identity safety code and allows the user to:
/// - View the current safety code
/// - Explicitly verify the identity (UNKNOWN в†’ VERIFIED)
/// - See key change warnings (CHANGED state)
/// - Re-verify after key change (CHANGED в†’ VERIFIED)
///
/// ## Security Properties
///
/// - VERIFIED state requires EXPLICIT user confirmation
/// - Server CANNOT trigger VERIFIED state
/// - Key changes are detected and warned
/// - No private key material is exposed
class E2eeVerificationScreen extends StatefulWidget {
  const E2eeVerificationScreen({
    super.key,
    required this.peerId,
    required this.peerName,
    required this.peerIdentityKey,
  });

  final String peerId;
  final String peerName;
  final List<int> peerIdentityKey;

  @override
  State<E2eeVerificationScreen> createState() => _E2eeVerificationScreenState();
}

class _E2eeVerificationScreenState extends State<E2eeVerificationScreen> {
  late final E2eV2IdentityVerification _verification;
  IdentityTrustState _trustState = IdentityTrustState.unknown;
  String _safetyCode = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _verification = E2eV2IdentityVerification.instance;
    _loadState();
  }

  Future<void> _loadState() async {
    final state = await _verification.getTrustState(widget.peerId);
    final code = await E2eV2IdentityVerification.generateFingerprint(widget.peerIdentityKey);
    if (mounted) {
      setState(() {
        _trustState = state;
        _safetyCode = code;
        _loading = false;
      });
    }
  }

  Future<void> _verifyIdentity() async {
    final confirmed = await _showConfirmDialog();
    if (!confirmed || !mounted) return;

    await _verification.verifyIdentity(
      peerId: widget.peerId,
      identityKey: widget.peerIdentityKey,
    );
    if (mounted) {
      setState(() => _trustState = IdentityTrustState.verified);
    }
  }

  Future<bool> _showConfirmDialog() async {
    final l = VibeLocalizations.of(context);
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.e2eeConfirmVerify),
        content: Text(l.e2eeVerifyDescription),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l.e2eeConfirmCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l.e2eeConfirmYes),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _copyCode() {
    Clipboard.setData(ClipboardData(text: _safetyCode.replaceAll(' ', '')));
    final l = VibeLocalizations.of(context);
    VibeToast.show(context, l.e2eeCopied);
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
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            onPressed: () => Navigator.of(context).pop(),
            color: context.vibeTextPrimary,
          ),
          title: VibeTopBarTitle(l.e2eeVerification),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(VibeSpacing.lg),
              children: [
                _buildStatusCard(),
                const SizedBox(height: VibeSpacing.lg),
                _buildSafetyCodeCard(),
                const SizedBox(height: VibeSpacing.lg),
                _buildActionSection(),
              ],
            ),
    );
  }

  Widget _buildStatusCard() {
    final l = VibeLocalizations.of(context);

    IconData icon;
    Color color;
    String title;
    String description;

    switch (_trustState) {
      case IdentityTrustState.unknown:
        icon = Icons.help_outline_rounded;
        color = VibeColors.warning;
        title = l.e2eeNotVerified;
        description = l.e2eeVerifyDescription;
      case IdentityTrustState.verified:
        icon = Icons.verified_rounded;
        color = VibeColors.success;
        title = l.e2eeVerified;
        description = l.e2eeVerifiedDescription;
      case IdentityTrustState.changed:
        icon = Icons.warning_amber_rounded;
        color = VibeColors.error;
        title = l.e2eeChanged;
        description = l.e2eeChangedDescription;
    }

    return Container(
      padding: const EdgeInsets.all(VibeSpacing.lg),
      decoration: BoxDecoration(
        color: context.vibeSurfaceVariant,
        borderRadius: BorderRadius.circular(VibeRadius.card),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: VibeSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: VibeTypography.subtitle.copyWith(
                    color: context.vibeTextPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: VibeSpacing.xs),
                Text(
                  description,
                  style: VibeTypography.body.copyWith(
                    color: context.vibeTextSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSafetyCodeCard() {
    final l = VibeLocalizations.of(context);

    // Format code in groups of 5 digits, 4 lines
    final cleanCode = _safetyCode.replaceAll(' ', '');
    final lines = <String>[];
    for (var i = 0; i < cleanCode.length; i += 20) {
      final end = (i + 20).clamp(0, cleanCode.length);
      final chunk = cleanCode.substring(i, end);
      final grouped = StringBuffer();
      for (var j = 0; j < chunk.length; j += 5) {
        if (j > 0) grouped.write(' ');
        grouped.write(chunk.substring(j, (j + 5).clamp(0, chunk.length)));
      }
      lines.add(grouped.toString());
    }

    return Container(
      padding: const EdgeInsets.all(VibeSpacing.lg),
      decoration: BoxDecoration(
        color: context.vibeSurfaceVariant,
        borderRadius: BorderRadius.circular(VibeRadius.card),
      ),
      child: Column(
        children: [
          Text(
            l.e2eeSafetyCode,
            style: VibeTypography.caption.copyWith(
              color: context.vibeTextSecondary,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: VibeSpacing.md),
          ...lines.map((line) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  line,
                  style: VibeTypography.headline.copyWith(
                    color: context.vibeTextPrimary,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 2.0,
                  ),
                ),
              )),
          const SizedBox(height: VibeSpacing.md),
          GestureDetector(
            onTap: _copyCode,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.copy_rounded,
                  size: 16,
                  color: context.vibePrimary,
                ),
                const SizedBox(width: VibeSpacing.xs),
                Text(
                  l.e2eeCopyCode,
                  style: VibeTypography.body.copyWith(
                    color: context.vibePrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionSection() {
    final l = VibeLocalizations.of(context);

    switch (_trustState) {
      case IdentityTrustState.unknown:
        return VibeButton(
          label: l.e2eeVerifyAction,
          type: VibeButtonType.primary,
          onPressed: _verifyIdentity,
        );
      case IdentityTrustState.verified:
        return VibeButton(
          label: l.e2eeReverifyAction,
          type: VibeButtonType.secondary,
          onPressed: _verifyIdentity,
        );
      case IdentityTrustState.changed:
        return VibeButton(
          label: l.e2eeReverifyNewKey,
          type: VibeButtonType.primary,
          onPressed: _verifyIdentity,
        );
    }
  }
}
