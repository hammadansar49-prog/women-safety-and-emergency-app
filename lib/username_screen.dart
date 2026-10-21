import 'package:flutter/material.dart';

import 'social_controller.dart';
import 'theme/tokens.dart';
import 'ui/design.dart';

class UsernameScreen extends StatefulWidget {
  const UsernameScreen({super.key, required this.social, this.onReserve});
  final SocialController social;

  /// Reserves the name in the cloud before it is claimed locally.
  final Future<void> Function(String username)? onReserve;

  @override
  State<UsernameScreen> createState() => _UsernameScreenState();
}

class _UsernameScreenState extends State<UsernameScreen> {
  final _controller = TextEditingController();
  String? _saveError;
  String? _liveError;
  bool _busy = false;

  Future<void> _save() async {
    final problem = widget.social.usernameError(_controller.text);
    if (problem != null) {
      setState(() => _liveError = problem);
      return;
    }
    setState(() {
      _saveError = null;
      _busy = true;
    });
    try {
      await widget.onReserve?.call(_controller.text);
      widget.social.claimUsername(_controller.text);
    } on StateError catch (error) {
      if (mounted) setState(() => _saveError = error.message);
    } catch (error) {
      if (mounted) setState(() => _saveError = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: false,
      body: HeaderPage(
        headerHeight: 270,
        overlap: 18,
        bottomPadding: 40,
        header: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Wordmark(),
            const SizedBox(height: 20),
            Text(
              'STEP 2 OF 2',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
                color: AppColors.onHeader,
              ),
            ),
            const SizedBox(height: 6),
            const HeaderTitle(
              'Pick your username.',
              subtitle:
                  'Buddies find you by it. It is unique and cannot be reused later.',
              size: 32,
            ),
          ],
        ),
        children: [
          DesignField(
            controller: _controller,
            hint: 'meethamad',
            icon: Icons.alternate_email,
            accentBorder: true,
            shadow: true,
            textInputAction: TextInputAction.done,
            onChanged: (v) => setState(
              () => _liveError = v.isEmpty
                  ? null
                  : widget.social.usernameError(v),
            ),
            onSubmitted: (_) => _save(),
            trailing: _controller.text.isNotEmpty && _liveError == null
                ? Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.success,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 14,
                    ),
                  )
                : null,
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              _controller.text.isEmpty
                  ? ' '
                  : _liveError ?? '@${_controller.text.trim().toLowerCase()} is available',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _liveError == null && _controller.text.isNotEmpty
                    ? (AppColors.light
                          ? const Color(0xFF1F6B45)
                          : AppColors.success)
                    : AppColors.danger,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: AppColors.surface,
              border: Border.all(color: AppColors.border),
            ),
            child: Text(
              'Rules\n3 to 20 characters\nLetters, numbers and underscore only\nSaved in lowercase. It cannot be changed later.',
              style: TextStyle(
                fontSize: 13,
                height: 1.7,
                color: AppColors.textMuted,
              ),
            ),
          ),
          if (_saveError != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                _saveError!,
                style: TextStyle(color: AppColors.danger),
              ),
            ),
          const SizedBox(height: 18),
          BerryButton(
            label: _busy ? 'Saving…' : 'Save and continue',
            busy: _busy,
            onTap: _save,
          ),
        ],
      ),
    );
  }
}
