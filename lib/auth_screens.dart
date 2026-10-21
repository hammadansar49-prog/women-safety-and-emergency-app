import 'package:flutter/material.dart';

import 'theme/tokens.dart';
import 'ui/glass.dart';
import 'ui/motion.dart';

/// Sign-in and sign-up surfaces, styled to the aurora-glass system.
///
/// These collect the inputs and drive navigation; the actual authentication
/// (email/password + Google) is wired to Firebase Auth in a later step. For
/// now the shell "signs in" against local data, so the flow is real even
/// though the identity check is not yet.

/// A glass-backed text field with a leading icon and an optional reveal toggle.
class _GlassField extends StatefulWidget {
  const _GlassField({
    required this.controller,
    required this.label,
    required this.icon,
    this.obscure = false,
    this.keyboardType,
    this.prefixText,
    this.textInputAction,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool obscure;
  final TextInputType? keyboardType;
  final String? prefixText;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;

  @override
  State<_GlassField> createState() => _GlassFieldState();
}

class _GlassFieldState extends State<_GlassField> {
  late bool _hidden = widget.obscure;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.symmetric(
        horizontal: Space.x4,
        vertical: Space.x1,
      ),
      borderRadius: Radii.brSm,
      opacity: 0.5,
      child: TextField(
        controller: widget.controller,
        obscureText: _hidden,
        keyboardType: widget.keyboardType,
        textInputAction: widget.textInputAction,
        autocorrect: false,
        enableSuggestions: false,
        onSubmitted: widget.onSubmitted,
        style: Theme.of(context).textTheme.bodyLarge,
        decoration: InputDecoration(
          labelText: widget.label,
          prefixText: widget.prefixText,
          prefixIcon: Icon(widget.icon, color: AppColors.accent, size: 20),
          filled: false,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          suffixIcon: widget.obscure
              ? IconButton(
                  icon: Icon(
                    _hidden
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: AppColors.textMuted,
                    size: 20,
                  ),
                  onPressed: () => setState(() => _hidden = !_hidden),
                )
              : null,
        ),
      ),
    );
  }
}

/// The gradient primary action used across auth.
class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Pressable(
    borderRadius: Radii.brSm,
    glow: AppColors.accent,
    onTap: onTap,
    semanticLabel: label,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: Space.x4 + 2),
      decoration: BoxDecoration(
        borderRadius: Radii.brSm,
        gradient: const LinearGradient(
          colors: [AppColors.accent, AppColors.primary],
        ),
        border: Border.all(color: AppColors.glassHairline),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: Theme.of(
          context,
        ).textTheme.labelLarge?.copyWith(color: Colors.white, fontSize: 16),
      ),
    ),
  );
}

/// "Continue with Google" — a glass pill with the Google "G" wordmark glyph.
class _GoogleButton extends StatelessWidget {
  const _GoogleButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Pressable(
    borderRadius: Radii.brSm,
    onTap: onTap,
    semanticLabel: 'Continue with Google',
    child: GlassPanel(
      borderRadius: Radii.brSm,
      opacity: 0.5,
      padding: const EdgeInsets.symmetric(vertical: Space.x4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const _GoogleGlyph(),
          const SizedBox(width: Space.x3),
          Text(
            'Continue with Google',
            style: Theme.of(context).textTheme.labelLarge,
          ),
        ],
      ),
    ),
  );
}

/// A small, recognisable multi-colour Google "G" drawn from text, so no
/// external logo asset is needed.
class _GoogleGlyph extends StatelessWidget {
  const _GoogleGlyph();

  @override
  Widget build(BuildContext context) => Container(
    width: 24,
    height: 24,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(6),
    ),
    child: const Text(
      'G',
      style: TextStyle(
        fontWeight: FontWeight.w700,
        fontSize: 16,
        color: Color(0xFF4285F4),
      ),
    ),
  );
}

Widget _authHeader(BuildContext context, String title, String subtitle) {
  final theme = Theme.of(context);
  return Column(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              AppColors.primary.withValues(alpha: 0.35),
              AppColors.primary.withValues(alpha: 0.0),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.accent.withValues(alpha: 0.28),
              blurRadius: 32,
              spreadRadius: 2,
            ),
          ],
        ),
        child: const Icon(
          Icons.shield_rounded,
          size: 36,
          color: AppColors.accent,
        ),
      ),
      const SizedBox(height: Space.x6),
      Text(
        title,
        textAlign: TextAlign.center,
        style: theme.textTheme.headlineLarge,
      ),
      const SizedBox(height: Space.x2),
      Text(
        subtitle,
        textAlign: TextAlign.center,
        style: theme.textTheme.bodyMedium,
      ),
    ],
  );
}

/// A thin "or" divider between the primary form and the social option.
Widget _orDivider(BuildContext context) => Row(
  children: [
    const Expanded(child: Divider(color: AppColors.border)),
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.x3),
      child: Text('or', style: Theme.of(context).textTheme.bodySmall),
    ),
    const Expanded(child: Divider(color: AppColors.border)),
  ],
);

Widget _authShell(BuildContext context, List<Widget> children) => Scaffold(
  backgroundColor: Colors.transparent,
  body: SafeArea(
    child: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: Space.x6,
          vertical: Space.x8,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ),
    ),
  ),
);

/// Sign-in: username + password, forgot-password, create-account, and Google.
class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    required this.onLogin,
    required this.onGoogle,
    required this.onCreateAccount,
  });

  /// Each callback returns an error message to show, or null on success.
  final Future<String?> Function(String username, String password) onLogin;
  final Future<String?> Function() onGoogle;
  final VoidCallback onCreateAccount;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _username = TextEditingController();
  final _password = TextEditingController();
  String? _error;
  bool _busy = false;

  Future<void> _run(Future<String?> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final error = await action();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = (error == null || error.isEmpty) ? null : error;
    });
  }

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    final u = _username.text.trim();
    final p = _password.text;
    if (u.isEmpty || p.isEmpty) {
      setState(() => _error = 'Enter your username and password.');
      return;
    }
    _run(() => widget.onLogin(u, p));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _authShell(context, [
      EntranceFade(child: _authHeader(context, 'Welcome back', 'Sign in to your SafeHer circle.')),
      const SizedBox(height: Space.x8),
      EntranceFade(
        index: 1,
        child: _GlassField(
          controller: _username,
          label: 'Username',
          icon: Icons.alternate_email,
          prefixText: '@',
          textInputAction: TextInputAction.next,
        ),
      ),
      const SizedBox(height: Space.x3),
      EntranceFade(
        index: 2,
        child: _GlassField(
          controller: _password,
          label: 'Password',
          icon: Icons.lock_outline,
          obscure: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submit(),
        ),
      ),
      Align(
        alignment: Alignment.centerRight,
        child: TextButton(
          onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Password reset arrives with cloud sign-in.'),
            ),
          ),
          child: const Text('Forgot password?'),
        ),
      ),
      if (_error != null)
        Padding(
          padding: const EdgeInsets.only(bottom: Space.x3),
          child: Text(
            _error!,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.danger,
            ),
          ),
        ),
      const SizedBox(height: Space.x2),
      EntranceFade(index: 3, child: _PrimaryButton(
          label: _busy ? 'Signing in…' : 'Sign in',
          onTap: _submit,
        )),
      const SizedBox(height: Space.x6),
      EntranceFade(index: 4, child: _orDivider(context)),
      const SizedBox(height: Space.x6),
      EntranceFade(index: 5, child: _GoogleButton(onTap: () => _run(widget.onGoogle))),
      const SizedBox(height: Space.x6),
      EntranceFade(
        index: 6,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text("New here?", style: theme.textTheme.bodyMedium),
            TextButton(
              onPressed: widget.onCreateAccount,
              child: const Text('Create an account'),
            ),
          ],
        ),
      ),
    ]);
  }
}

/// Sign-up: register with email (then username + password), or Google.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({
    super.key,
    required this.onRegister,
    required this.onGoogle,
    required this.onBackToLogin,
  });

  final Future<String?> Function(
    String email,
    String username,
    String password,
  )
  onRegister;
  final Future<String?> Function() onGoogle;
  final VoidCallback onBackToLogin;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _email = TextEditingController();
  final _username = TextEditingController();
  final _password = TextEditingController();
  String? _error;
  bool _busy = false;

  Future<void> _run(Future<String?> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final error = await action();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = (error == null || error.isEmpty) ? null : error;
    });
  }

  @override
  void dispose() {
    _email.dispose();
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    final email = _email.text.trim();
    final u = _username.text.trim();
    final p = _password.text;
    if (!email.contains('@') || !email.contains('.')) {
      setState(() => _error = 'Enter a valid email address.');
      return;
    }
    if (u.length < 3) {
      setState(() => _error = 'Username needs at least 3 characters.');
      return;
    }
    if (p.length < 6) {
      setState(() => _error = 'Password needs at least 6 characters.');
      return;
    }
    _run(() => widget.onRegister(email, u, p));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _authShell(context, [
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: widget.onBackToLogin,
          icon: const Icon(Icons.arrow_back, size: 18),
          label: const Text('Back'),
        ),
      ),
      EntranceFade(
        child: _authHeader(
          context,
          'Create your account',
          'Join with your email, then pick a username.',
        ),
      ),
      const SizedBox(height: Space.x8),
      EntranceFade(
        index: 1,
        child: _GlassField(
          controller: _email,
          label: 'Email',
          icon: Icons.mail_outline,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
        ),
      ),
      const SizedBox(height: Space.x3),
      EntranceFade(
        index: 2,
        child: _GlassField(
          controller: _username,
          label: 'Username',
          icon: Icons.alternate_email,
          prefixText: '@',
          textInputAction: TextInputAction.next,
        ),
      ),
      const SizedBox(height: Space.x3),
      EntranceFade(
        index: 3,
        child: _GlassField(
          controller: _password,
          label: 'Password',
          icon: Icons.lock_outline,
          obscure: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submit(),
        ),
      ),
      if (_error != null)
        Padding(
          padding: const EdgeInsets.only(top: Space.x3),
          child: Text(
            _error!,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.danger,
            ),
          ),
        ),
      const SizedBox(height: Space.x6),
      EntranceFade(
        index: 4,
        child: _PrimaryButton(
          label: _busy ? 'Creating…' : 'Create account',
          onTap: _submit,
        ),
      ),
      const SizedBox(height: Space.x6),
      EntranceFade(index: 5, child: _orDivider(context)),
      const SizedBox(height: Space.x6),
      EntranceFade(index: 6, child: _GoogleButton(onTap: () => _run(widget.onGoogle))),
    ]);
  }
}
