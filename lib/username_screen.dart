import 'package:flutter/material.dart';
import 'social_controller.dart';

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
  final _form = GlobalKey<FormState>();
  String? _saveError;

  Future<void> _save() async {
    setState(() => _saveError = null);
    if (!_form.currentState!.validate()) return;
    try {
      await widget.onReserve?.call(_controller.text);
      widget.social.claimUsername(_controller.text);
    } on StateError catch (error) {
      setState(() => _saveError = error.message);
    } catch (error) {
      if (mounted) setState(() => _saveError = error.toString());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('SafeHer')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.alternate_email,
                  size: 56,
                  color: Color(0xFF6552A3),
                ),
                const SizedBox(height: 24),
                Text(
                  'Choose your username',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Your friends can find and add you using this unique username.',
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _controller,
                  autocorrect: false,
                  enableSuggestions: false,
                  textInputAction: TextInputAction.done,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  decoration: const InputDecoration(
                    labelText: 'Username',
                    prefixText: '@',
                    hintText: 'meethamad',
                    border: OutlineInputBorder(),
                    helperText: '3–20 letters, numbers or underscores',
                  ),
                  validator: (value) =>
                      widget.social.usernameError(value ?? ''),
                  onFieldSubmitted: (_) => _save(),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Usernames use lowercase letters. Choose carefully: your username cannot be changed here.',
                ),
                if (_saveError != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _saveError!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _save,
                  child: const Text('Save username'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
