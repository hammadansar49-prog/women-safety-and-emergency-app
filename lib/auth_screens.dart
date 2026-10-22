import 'package:flutter/material.dart';

import 'theme/tokens.dart';
import 'ui/brand_mark.dart';
import 'ui/design.dart';
import 'ui/motion.dart';
import 'username_check.dart';

/// Sign-in and sign-up, in the baby pink design: a blush header carrying the
/// wordmark and headline, with the form rising over its bottom edge.

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    required this.icon,
    this.obscure = false,
    this.keyboardType,
    this.prefixText,
    this.textInputAction,
    this.onSubmitted,
    this.onChanged,
    this.shadow = false,
  });

  final ValueChanged<String>? onChanged;
  final bool shadow;
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool obscure;
  final TextInputType? keyboardType;
  final String? prefixText;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: DesignField(
      controller: controller,
      hint: label,
      icon: icon,
      obscure: obscure,
      keyboardType: keyboardType,
      prefixText: prefixText,
      textInputAction: textInputAction,
      onSubmitted: onSubmitted,
      onChanged: onChanged,
      shadow: shadow,
    ),
  );
}

class _GoogleButton extends StatelessWidget {
  const _GoogleButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => OutlinedPill(
    label: 'Continue with Google',
    onTap: onTap,
    leading: Container(
      width: 26,
      height: 26,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.secondary,
      ),
      child: Text(
        'G',
        style: TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 14,
          color: AppColors.accent,
        ),
      ),
    ),
  );
}

Widget _orDivider(BuildContext context) => Row(
  children: [
    Expanded(child: Divider(color: AppColors.border)),
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.x3),
      child: Text('or', style: Theme.of(context).textTheme.bodySmall),
    ),
    Expanded(child: Divider(color: AppColors.border)),
  ],
);

Widget _centerHeader(BuildContext context, String title, String subtitle) {
  final theme = Theme.of(context);
  return Column(
    children: [
      // The one place the mark appears in the app itself: the first screen a
      // new person sees, where the name alone has nothing to stand beside.
      // Set beside the name rather than above it, because this screen has no
      // vertical room to spare on a short phone.
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          BrandMark(size: 34, faceColor: AppColors.header),
          const SizedBox(width: 10),
          const Wordmark(),
        ],
      ),
      const SizedBox(height: 24),
      Text(
        title,
        textAlign: TextAlign.center,
        style: theme.textTheme.headlineLarge?.copyWith(fontSize: 34),
      ),
      const SizedBox(height: 8),
      Text(
        subtitle,
        textAlign: TextAlign.center,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: AppColors.light
              ? const Color(0xFF6A3A52)
              : AppColors.textMuted,
        ),
      ),
    ],
  );
}

Widget _errorText(BuildContext context, String message) => Padding(
  padding: const EdgeInsets.only(bottom: Space.x3),
  child: Text(
    message,
    style: Theme.of(
      context,
    ).textTheme.bodyMedium?.copyWith(color: AppColors.danger),
  ),
);

Widget _footer(
  BuildContext context,
  String text,
  String action,
  VoidCallback onTap,
) => Padding(
  padding: EdgeInsets.zero,
  // Wrap, not Row: at a large text size the two halves need their own lines
  // rather than running off the edge.
  child: Wrap(
    alignment: WrapAlignment.center,
    crossAxisAlignment: WrapCrossAlignment.center,
    spacing: 6,
    children: [
      Text(text, style: Theme.of(context).textTheme.bodyMedium),
      GestureDetector(
        onTap: onTap,
        child: Text(
          action,
          style: TextStyle(
            color: AppColors.accent,
            fontWeight: FontWeight.w700,
            fontSize: 14.5,
          ),
        ),
      ),
    ],
  ),
);

/// Sign-in: username or email + password, forgot-password, create-account, Google.
class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    required this.onLogin,
    required this.onGoogle,
    required this.onCreateAccount,
    this.onForgotPassword,
  });

  /// Each callback returns an error message to show, or null on success.
  final Future<String?> Function(String username, String password) onLogin;
  final Future<String?> Function() onGoogle;
  final VoidCallback onCreateAccount;

  /// Sends a reset email; returns an error message, or null when sent.
  final Future<String?> Function(String email)? onForgotPassword;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _username = TextEditingController();
  final _password = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    for (final c in [_username, _password]) {
      c.addListener(_clearError);
    }
  }

  void _clearError() {
    if (_error != null) setState(() => _error = null);
  }

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
    for (final c in [_username, _password]) {
      c.removeListener(_clearError);
      c.dispose();
    }
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
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.transparent,
    resizeToAvoidBottomInset: false,
    body: HeaderPage(
      headerHeight: 270,
      overlap: 20,
      bottomPadding: 40,
      header: _centerHeader(
        context,
        'Welcome back.',
        'Sign in to keep your circle close.',
      ),
      children: [
        _Field(
          shadow: true,
          controller: _username,
          label: 'Username or email',
          icon: Icons.person_outline,
          textInputAction: TextInputAction.next,
        ),
        _Field(
          controller: _password,
          label: 'Password',
          icon: Icons.lock_outline,
          obscure: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submit(),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: GestureDetector(
            onTap: () => Navigator.of(context).push(
              SafeRoute<void>(
                builder: (_) => ForgotPasswordScreen(
                  initial: _username.text.contains('@')
                      ? _username.text.trim()
                      : '',
                  onSend: widget.onForgotPassword ?? (_) async => null,
                ),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(
                'Forgot password?',
                style: TextStyle(
                  color: AppColors.accent,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ),
        if (_error != null) _errorText(context, _error!),
        const SizedBox(height: 6),
        BerryButton(
          label: _busy ? 'Signing in…' : 'Sign in',
          busy: _busy,
          onTap: _submit,
        ),
        const SizedBox(height: 18),
        _orDivider(context),
        const SizedBox(height: 18),
        _GoogleButton(onTap: () => _run(widget.onGoogle)),
      ],
      footer: _footer(
        context,
        'New to SafeHer?',
        'Create account',
        widget.onCreateAccount,
      ),
    ),
  );
}

/// Sign-up: email, username and password, or Google.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({
    super.key,
    required this.onRegister,
    required this.onGoogle,
    required this.onBackToLogin,
    this.checker,
  });

  /// Live username availability; optional so tests can leave it out.
  final UsernameChecker? checker;

  final Future<String?> Function(
    String email,
    String username,
    String password,
    String name,
  )
  onRegister;
  final Future<String?> Function() onGoogle;
  final VoidCallback onBackToLogin;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _username = TextEditingController();
  final _password = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // A complaint about a field stops the moment that field is being fixed,
    // instead of sitting there until the next submit.
    for (final c in [_name, _email, _username, _password]) {
      c.addListener(_clearError);
    }
  }

  void _clearError() {
    if (_error != null) setState(() => _error = null);
  }

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
    for (final c in [_name, _email, _username, _password]) {
      c.removeListener(_clearError);
      c.dispose();
    }
    super.dispose();
  }

  void _submit() {
    final name = _name.text.trim();
    final email = _email.text.trim();
    final u = _username.text.trim();
    final p = _password.text;
    if (name.isEmpty) {
      setState(() => _error = 'Enter your full name.');
      return;
    }
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
    _run(() => widget.onRegister(email, u, p, name));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.transparent,
    resizeToAvoidBottomInset: false,
    body: HeaderPage(
      headerHeight: 232,
      overlap: 20,
      bottomPadding: 40,
      header: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Wordmark(),
              const Spacer(),
              HeaderBackIcon(onTap: widget.onBackToLogin),
            ],
          ),
          const SizedBox(height: 18),
          const HeaderTitle(
            'Create your account.',
            subtitle: 'It takes under a minute.',
            size: 32,
          ),
        ],
      ),
      children: [
        _Field(
          controller: _name,
          label: 'Full name',
          icon: Icons.person_outline,
          textInputAction: TextInputAction.next,
        ),
        _Field(
          controller: _email,
          label: 'Email',
          icon: Icons.mail_outline,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
        ),
        _Field(
          controller: _username,
          label: 'Username',
          icon: Icons.alternate_email,
          textInputAction: TextInputAction.next,
          onChanged: widget.checker?.update,
        ),
        if (widget.checker != null) UsernameStatusLine(checker: widget.checker!),
        _Field(
          controller: _password,
          label: 'Password (6+ characters)',
          icon: Icons.lock_outline,
          obscure: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submit(),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 20,
                height: 20,
                margin: const EdgeInsets.only(top: 1),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  color: AppColors.primary,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Colors.white,
                  size: 15,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'I understand SafeHer shares my location only when I start an SOS.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(fontSize: 12.5, height: 1.5),
                ),
              ),
            ],
          ),
        ),
        if (_error != null) _errorText(context, _error!),
        BerryButton(
          label: _busy ? 'Creating…' : 'Create account',
          busy: _busy,
          onTap: _submit,
        ),
        const SizedBox(height: 18),
        _orDivider(context),
        const SizedBox(height: 18),
        _GoogleButton(onTap: () => _run(widget.onGoogle)),
      ],
      footer: _footer(
        context,
        'Already have an account?',
        'Sign in',
        widget.onBackToLogin,
      ),
    ),
  );
}

/// Small close/back icon for the register header (no navigator route here).
class HeaderBackIcon extends StatelessWidget {
  const HeaderBackIcon({super.key, required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Pressable(
    borderRadius: BorderRadius.circular(999),
    onTap: onTap,
    semanticLabel: 'Back to sign in',
    child: Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.light ? Colors.white : AppColors.surface,
      ),
      child: Icon(Icons.arrow_back_rounded, color: AppColors.text, size: 20),
    ),
  );
}

/// Forgot password: one field, one button, then a calm confirmation. The
/// confirmation never says whether the email is registered.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({
    super.key,
    required this.onSend,
    this.initial = '',
  });

  final Future<String?> Function(String email) onSend;
  final String initial;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  late final _email = TextEditingController(text: widget.initial);
  String? _error;
  bool _busy = false;
  bool _sent = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final email = _email.text.trim();
    if (!email.contains('@') || !email.contains('.')) {
      setState(() => _error = 'Enter the email you signed up with.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final error = await widget.onSend(email);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = error;
      _sent = error == null;
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.transparent,
    body: HeaderPage(
      headerHeight: 262,
      overlap: 20,
      bottomPadding: 40,
      header: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Wordmark(),
              const Spacer(),
              HeaderBackIcon(onTap: () => Navigator.of(context).maybePop()),
            ],
          ),
          const SizedBox(height: 18),
          const HeaderTitle(
            'Forgot your password?',
            subtitle: 'We will email you a link to choose a new one.',
            size: 30,
          ),
        ],
      ),
      children: [
        if (!_sent) ...[
          _Field(
            controller: _email,
            label: 'Email',
            icon: Icons.mail_outline,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _send(),
            shadow: true,
          ),
          if (_error != null) _errorText(context, _error!),
          const SizedBox(height: 6),
          BerryButton(
            label: _busy ? 'Sending…' : 'Send reset link',
            busy: _busy,
            onTap: _send,
          ),
        ] else
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: AppColors.light
                  ? const Color(0xFFE4F2E9)
                  : AppColors.surface,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.mark_email_read_outlined,
                  color: AppColors.light
                      ? const Color(0xFF1E4A33)
                      : AppColors.success,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'If an account uses that email, a reset link is on its way. Check your inbox and spam.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.light
                          ? const Color(0xFF1E4A33)
                          : null,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
      footer: _footer(
        context,
        'Remembered it?',
        'Back to sign in',
        () => Navigator.of(context).maybePop(),
      ),
    ),
  );
}
