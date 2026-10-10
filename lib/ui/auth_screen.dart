import 'package:flutter/material.dart';

import '../core/app_state.dart';
import 'common.dart';
import 'shell.dart';

/// Вход и регистрация.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _register = false;
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    await guarded(context, () => AppScope.read(context).signIn(_email.text.trim(), _password.text, register: _register));
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final tr = s.tr;
    return Scaffold(
      appBar: AppBar(
        title: const BrandTitle(),
        actions: const [LanguageMenu(), SizedBox(width: 8)],
      ),
      body: AppPage(children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Section(children: [
              if (s.sessionExpired) Notice(tr('auth.expired'), bad: true),
              Text(tr(_register ? 'auth.register' : 'auth.login'),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(tr('auth.lead'), style: TextStyle(color: Theme.of(context).hintColor)),
              const SizedBox(height: 20),
              Form(
                key: _form,
                child: AutofillGroup(
                  child: Column(children: [
                    TextFormField(
                      key: const Key('email'),
                      controller: _email,
                      decoration: field(tr('auth.email')),
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      validator: (v) => v != null && v.contains('@') ? null : tr('auth.email'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      key: const Key('password'),
                      controller: _password,
                      obscureText: true,
                      decoration: field(tr('auth.password'), helper: _register ? tr('auth.passwordHint') : null),
                      autofillHints: [_register ? AutofillHints.newPassword : AutofillHints.password],
                      validator: (v) => (v ?? '').length >= (_register ? 8 : 1) ? null : tr('auth.passwordHint'),
                      onFieldSubmitted: (_) => _submit(),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        key: const Key('submit'),
                        onPressed: _busy ? null : _submit,
                        child: Text(tr(_register ? 'auth.submitRegister' : 'auth.submitLogin')),
                      ),
                    ),
                  ]),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                key: const Key('toggle'),
                onPressed: () => setState(() => _register = !_register),
                child: Text(tr(_register ? 'auth.toLogin' : 'auth.toRegister')),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}
