import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../backend/backend.dart';
import '../backend/config.dart';
import '../store/app_store.dart';
import '../theme/colors.dart';
import '../theme/spacing.dart';
import '../widgets/buttons.dart';

/// First-run flow shared by both apps: welcome → identity (email OTP in live,
/// phone demo offline) → profile + KYC (PAN+payout for farmers, GST for
/// dealers). On finish it calls Supabase (live) or the store (mock) and the
/// [AuthGate] swaps in the real app.
class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({super.key});

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  int _step = 0;
  bool _busy = false;
  String? _error;

  final _id = TextEditingController();   // email (live) / phone (mock)
  final _otp = TextEditingController();
  final _name = TextEditingController();
  final _doc = TextEditingController();
  bool _docUploaded = false;

  bool get _live => AppConfig.isLive;

  @override
  void initState() {
    super.initState();
    for (final c in [_id, _otp, _name, _doc]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    for (final c in [_id, _otp, _name, _doc]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _guard(Future<void> Function() op) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await op();
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final farmer = context.store.isFarmer;
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            _topBar(),
            if (_error != null)
              Container(
                width: double.infinity,
                color: AppColors.dangerTint,
                padding: const EdgeInsets.all(Insets.s3),
                child: Text(_error!,
                    style: const TextStyle(color: AppColors.danger, fontSize: 13)),
              ),
            Expanded(
              child: AnimatedSwitcher(
                duration: Motion.base,
                child: switch (_step) {
                  0 => _welcome(farmer),
                  1 => _idStep(),
                  2 => _otpStep(),
                  _ => _kycStep(farmer),
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _topBar() {
    if (_step == 0) return const SizedBox(height: Insets.s2);
    return Padding(
      padding: const EdgeInsets.fromLTRB(Insets.s2, Insets.s2, Insets.s4, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: _busy ? null : () => setState(() => _step--),
            icon: const Icon(Icons.arrow_back, color: AppColors.ink),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(Radii.pill),
              child: LinearProgressIndicator(
                value: _step / 3,
                minHeight: 4,
                backgroundColor: AppColors.surface2,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(width: Insets.s4),
        ],
      ),
    );
  }

  Widget _welcome(bool farmer) {
    final points = farmer
        ? const [
            ('🌾', 'List your produce', 'Reach hundreds of verified buyers directly'),
            ('📈', 'Sell at a fair price', 'See the live mandi rate before you decide'),
            ('🔒', 'Get paid, guaranteed', 'Money held in escrow, released on delivery'),
          ]
        : const [
            ('🚚', 'Source direct from farms', 'Verified farmers, fresh produce, no middlemen'),
            ('🔎', 'Find exactly what you need', 'Filter by grade, distance, quantity, organic'),
            ('🔒', 'Pay safely', 'Escrow protects every order until delivery'),
          ];
    return Padding(
      key: const ValueKey('welcome'),
      padding: const EdgeInsets.all(Insets.s6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Spacer(),
          const _Logo(),
          const SizedBox(height: Insets.s5),
          Text(
              farmer
                  ? 'Sell your harvest\nfor what it’s worth.'
                  : 'Source fresh produce,\nstraight from the farm.',
              style: const TextStyle(
                  fontSize: 30, fontWeight: FontWeight.w700, height: 1.1, letterSpacing: -0.6)),
          const SizedBox(height: Insets.s6),
          for (final (e, t, d) in points)
            Padding(
              padding: const EdgeInsets.only(bottom: Insets.s4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(e, style: const TextStyle(fontSize: 26)),
                  const SizedBox(width: Insets.s3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                        Text(d, style: const TextStyle(fontSize: 14, color: AppColors.muted)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          const Spacer(),
          AppButton.primary('Get started', onPressed: () => setState(() => _step = 1)),
          const SizedBox(height: Insets.s2),
          const Center(
            child: Text('Free for farmers · No commission on your first 5 deals',
                style: TextStyle(fontSize: 12, color: AppColors.muted)),
          ),
        ],
      ),
    );
  }

  // step 1: email (live) or phone (mock)
  Widget _idStep() {
    final valid = _live ? _id.text.contains('@') : _id.text.length == 10;
    return _formScaffold(
      key: 'id',
      title: _live ? 'What’s your email?' : 'What’s your mobile number?',
      hint: _live
          ? 'We’ll email you a 6-digit code to verify it.'
          : 'We’ll send a one-time code to verify it.',
      child: TextField(
        controller: _id,
        autofocus: true,
        keyboardType: _live ? TextInputType.emailAddress : TextInputType.phone,
        maxLength: _live ? null : 10,
        inputFormatters: _live ? null : [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          prefixText: _live ? null : '+91  ',
          hintText: _live ? 'you@example.com' : '00000 00000',
          counterText: '',
        ),
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
      ),
      cta: 'Continue',
      onCta: (valid && !_busy) ? () => setState(() => _step = 2) : null,
    );
  }

  Widget _otpStep() {
    if (_live) {
      final valid = _otp.text.length >= 6 && !_busy;
      return _formScaffold(
        key: 'pw',
        title: 'Create a password',
        hint: 'At least 6 characters. You’ll sign in with your email + password.',
        child: TextField(
          controller: _otp,
          autofocus: true,
          obscureText: true,
          decoration: const InputDecoration(hintText: 'Password'),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        cta: 'Continue',
        onCta: valid
            ? () => _guard(() async {
                  await Backend.I.signUpOrIn(_id.text.trim(), _otp.text,
                      role: context.store.role, fullName: '');
                  setState(() => _step = 3);
                })
            : null,
      );
    }
    // mock demo: any 4-digit OTP
    final valid = _otp.text.length >= 4;
    return _formScaffold(
      key: 'otp',
      title: 'Enter the code',
      hint: 'Sent to +91 ${_id.text}. Use any 4 digits for this demo.',
      child: TextField(
        controller: _otp,
        autofocus: true,
        keyboardType: TextInputType.number,
        maxLength: 4,
        textAlign: TextAlign.center,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: const InputDecoration(hintText: '••••', counterText: ''),
        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: 10),
      ),
      cta: 'Verify',
      onCta: (valid && !_busy) ? () => setState(() => _step = 3) : null,
    );
  }

  Widget _kycStep(bool farmer) {
    final docLabel = farmer ? 'PAN number' : 'GST number';
    final valid = _name.text.trim().isNotEmpty &&
        _doc.text.trim().length >= 4 &&
        _docUploaded &&
        !_busy;
    return _formScaffold(
      key: 'kyc',
      title: 'Verify your identity',
      hint: farmer
          ? 'Verified farmers get more offers and faster payouts.'
          : 'GST verification unlocks ordering and payments.',
      cta: 'Submit & finish',
      onCta: valid ? () => _guard(() => _finish(farmer)) : null,
      child: Column(
        children: [
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(labelText: farmer ? 'Your name' : 'Business name'),
          ),
          const SizedBox(height: Insets.s4),
          TextField(
            controller: _doc,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(labelText: docLabel),
          ),
          const SizedBox(height: Insets.s4),
          _UploadTile(
            uploaded: _docUploaded,
            label: farmer ? 'Upload PAN card photo' : 'Upload GST certificate',
            onTap: () => setState(() => _docUploaded = true),
          ),
          if (farmer) ...[
            const SizedBox(height: Insets.s4),
            const _InfoNote(
              icon: Icons.account_balance,
              text: 'Add your bank / UPI for payouts after verification — you can do this later in Profile.',
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _finish(bool farmer) async {
    final store = context.store;
    final last4 = _doc.text.trim().length >= 4
        ? _doc.text.trim().substring(_doc.text.trim().length - 4)
        : _doc.text.trim();
    if (_live) {
      await Backend.I.updateMyName(_name.text.trim());
      if (farmer) {
        await Backend.I.submitFarmerKyc(panLast4: last4, aadhaarLast4: '0000');
      } else {
        await Backend.I.submitDealerKyc(gstNumber: _doc.text.trim(), aadhaarLast4: '0000');
      }
      await store.reloadAll();
    } else {
      store.completeOnboarding(name: _name.text, phone: _id.text);
      store.submitKyc();
    }
  }

  Widget _formScaffold({
    required String key,
    required String title,
    required String hint,
    required Widget child,
    required String cta,
    required VoidCallback? onCta,
  }) {
    return Padding(
      key: ValueKey(key),
      padding: const EdgeInsets.all(Insets.s6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: Insets.s4),
          Text(title,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: -0.5)),
          const SizedBox(height: 6),
          Text(hint, style: const TextStyle(fontSize: 15, color: AppColors.muted)),
          const SizedBox(height: Insets.s6),
          child,
          const Spacer(),
          AppButton.primary(_busy ? 'Please wait…' : cta, onPressed: onCta),
        ],
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo();
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(Radii.md),
          ),
          child: const Icon(Icons.eco, color: AppColors.onPrimary, size: 26),
        ),
        const SizedBox(width: Insets.s3),
        const Text('OpenMandi',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.5)),
      ],
    );
  }
}

class _UploadTile extends StatelessWidget {
  const _UploadTile({required this.uploaded, required this.label, required this.onTap});
  final bool uploaded;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(Insets.s4),
        decoration: BoxDecoration(
          color: uploaded ? AppColors.okTint : AppColors.surface,
          borderRadius: BorderRadius.circular(Radii.md),
          border: Border.all(
              color: uploaded ? AppColors.ok : AppColors.lineStrong, width: 1.5),
        ),
        child: Row(
          children: [
            Icon(uploaded ? Icons.check_circle : Icons.upload_file,
                color: uploaded ? AppColors.ok : AppColors.muted),
            const SizedBox(width: Insets.s3),
            Expanded(
              child: Text(uploaded ? 'Document uploaded' : label,
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: uploaded ? AppColors.ok : AppColors.ink)),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoNote extends StatelessWidget {
  const _InfoNote({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: Insets.s2),
        Expanded(
          child: Text(text,
              style: const TextStyle(fontSize: 13, color: AppColors.muted, height: 1.4)),
        ),
      ],
    );
  }
}

/// Gates the app on auth. While login is paused (AppConfig.requireLogin =
/// false), there is no login/onboarding screen — the store auto-signs-in a
/// demo account, and we show a brief splash until the session is ready.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        if (store.onboarded) return child;
        if (!AppConfig.requireLogin) return const _AuthSplash();
        return const OnboardingFlow();
      },
    );
  }
}

class _AuthSplash extends StatelessWidget {
  const _AuthSplash();
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.eco, color: AppColors.onPrimary, size: 56),
            SizedBox(height: Insets.s5),
            SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(
                  color: AppColors.onPrimary, strokeWidth: 2.5),
            ),
          ],
        ),
      ),
    );
  }
}
