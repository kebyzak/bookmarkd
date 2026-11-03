import 'package:bookmarkd/app/di.dart';
import 'package:bookmarkd/app/theme/app_theme.dart';
import 'package:bookmarkd/app/theme/tokens.dart';
import 'package:bookmarkd/core/errors/app_failure.dart';
import 'package:bookmarkd/core/repositories.dart';
import 'package:bookmarkd/core/widgets/states.dart';
import 'package:bookmarkd/features/auth/presentation/session_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'brand_mark.dart';

final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

String? validateEmail(String? v) => _emailPattern.hasMatch(v?.trim() ?? '') ? null : 'Enter a valid email address';

String? validateNewPassword(String? v) => (v ?? '').length >= 8 ? null : 'Use at least 8 characters';

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(Space.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Spacer(),
            const BrandMark(size: 56),
            const SizedBox(height: Space.lg),
            Text('A home for\neverything you read.', style: context.text.displaySmall),
            const SizedBox(height: Space.sm),
            Text(
              'Track your shelf, log your progress, and find your next book through friends.',
              style: context.text.bodyLarge?.copyWith(color: context.colors.textSecondary),
            ),
            const Spacer(flex: 2),
            FilledButton(
              onPressed: () => context.push('/register'),
              child: const Center(child: Text('Create account')),
            ),
            const SizedBox(height: Space.sm),
            OutlinedButton(
              onPressed: () => context.push('/login'),
              child: const Center(child: Text('I already have an account')),
            ),
          ],
        ),
      ),
    ),
  );
}

class _AuthScaffold extends StatelessWidget {
  const _AuthScaffold({required this.title, required this.subtitle, required this.formKey, required this.children});

  final String title;
  final String subtitle;
  final GlobalKey<FormState> formKey;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(),
    body: SafeArea(
      child: Form(
        key: formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Space.lg, Space.xs, Space.lg, Space.lg),
          children: [
            Text(title, style: context.text.headlineMedium),
            const SizedBox(height: Space.xs),
            Text(subtitle, style: context.text.bodyLarge?.copyWith(color: context.colors.textSecondary)),
            const SizedBox(height: Space.xl),
            ...children,
          ],
        ),
      ),
    ),
  );
}

mixin _Submitting<T extends StatefulWidget> on State<T> {
  bool busy = false;

  Future<bool> submit(Future<void> Function() call) async {
    if (busy) return false;
    setState(() => busy = true);
    try {
      await call();
      return true;
    } catch (e) {
      if (mounted) showMessage(context, AppFailure.from(e).message);
      return false;
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }
}

class _SubmitButton extends StatelessWidget {
  const _SubmitButton({required this.label, required this.busy, required this.onPressed});

  final String label;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => FilledButton(
    onPressed: busy ? null : onPressed,
    child: Center(
      child: busy
          ? SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: context.colors.onAccent),
            )
          : Text(label),
    ),
  );
}

class _PasswordField extends StatefulWidget {
  const _PasswordField({required this.controller, required this.validator, this.onSubmitted, this.newPassword = false});

  final TextEditingController controller;
  final FormFieldValidator<String> validator;
  final VoidCallback? onSubmitted;
  final bool newPassword;

  @override
  State<_PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<_PasswordField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: widget.controller,
    obscureText: _obscure,
    validator: widget.validator,
    autofillHints: [widget.newPassword ? AutofillHints.newPassword : AutofillHints.password],
    textInputAction: TextInputAction.done,
    onFieldSubmitted: (_) => widget.onSubmitted?.call(),
    decoration: InputDecoration(
      hintText: 'Password',
      suffixIcon: IconButton(
        tooltip: _obscure ? 'Show password' : 'Hide password',
        icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
        onPressed: () => setState(() => _obscure = !_obscure),
      ),
    ),
  );
}

Widget _emailField(TextEditingController c) => TextFormField(
  controller: c,
  validator: validateEmail,
  keyboardType: TextInputType.emailAddress,
  autofillHints: const [AutofillHints.email],
  autocorrect: false,
  textInputAction: TextInputAction.next,
  decoration: const InputDecoration(hintText: 'Email'),
);

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with _Submitting {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _go() {
    if (!_form.currentState!.validate()) return;
    submit(() => sl<AuthRepository>().signIn(email: _email.text, password: _password.text));
  }

  @override
  Widget build(BuildContext context) => _AuthScaffold(
    title: 'Welcome back',
    subtitle: 'Sign in to pick up where you left off.',
    formKey: _form,
    children: [
      AutofillGroup(
        child: Column(
          children: [
            _emailField(_email),
            const SizedBox(height: Space.sm),
            _PasswordField(
              controller: _password,
              validator: (v) => (v ?? '').isEmpty ? 'Enter your password' : null,
              onSubmitted: _go,
            ),
          ],
        ),
      ),
      Align(
        alignment: Alignment.centerRight,
        child: TextButton(onPressed: () => context.push('/forgot-password'), child: const Text('Forgot password?')),
      ),
      const SizedBox(height: Space.md),
      _SubmitButton(label: 'Sign in', busy: busy, onPressed: _go),
      TextButton(
        onPressed: () => context.pushReplacement('/register'),
        child: const Text('New here? Create an account'),
      ),
    ],
  );
}

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> with _Submitting {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _awaitingConfirmation = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _go() async {
    if (!_form.currentState!.validate()) return;
    late SignUpResult result;
    final ok = await submit(() async {
      result = await sl<AuthRepository>().signUp(email: _email.text, password: _password.text);
    });
    if (ok && result == SignUpResult.confirmEmail && mounted) setState(() => _awaitingConfirmation = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_awaitingConfirmation) {
      return Scaffold(
        appBar: AppBar(),
        body: EmptyState(
          icon: Icons.mark_email_unread_outlined,
          title: 'Check your inbox',
          message: 'We sent a confirmation link to ${_email.text.trim()}. Open it, then sign in.',
          action: FilledButton(onPressed: () => context.pushReplacement('/login'), child: const Text('Go to sign in')),
        ),
      );
    }
    return _AuthScaffold(
      title: 'Create your account',
      subtitle: 'Your shelf, your reviews, your reading life.',
      formKey: _form,
      children: [
        AutofillGroup(
          child: Column(
            children: [
              _emailField(_email),
              const SizedBox(height: Space.sm),
              _PasswordField(
                controller: _password,
                validator: validateNewPassword,
                onSubmitted: _go,
                newPassword: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: Space.lg),
        _SubmitButton(label: 'Create account', busy: busy, onPressed: _go),
        TextButton(
          onPressed: () => context.pushReplacement('/login'),
          child: const Text('Already have an account? Sign in'),
        ),
      ],
    );
  }
}

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> with _Submitting {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  bool _sent = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _go() async {
    if (!_form.currentState!.validate()) return;
    final ok = await submit(() => sl<AuthRepository>().sendPasswordReset(_email.text));
    if (ok && mounted) setState(() => _sent = true);
  }

  @override
  Widget build(BuildContext context) => _AuthScaffold(
    title: 'Reset password',
    subtitle: _sent
        ? 'If an account exists for ${_email.text.trim()}, a reset link is on its way.'
        : "Enter your email and we'll send you a reset link.",
    formKey: _form,
    children: [
      if (!_sent) ...[
        _emailField(_email),
        const SizedBox(height: Space.lg),
        _SubmitButton(label: 'Send reset link', busy: busy, onPressed: _go),
      ] else
        FilledButton(
          onPressed: () => context.pop(),
          child: const Center(child: Text('Back to sign in')),
        ),
    ],
  );
}

class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({super.key});

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> with _Submitting {
  final _form = GlobalKey<FormState>();
  final _password = TextEditingController();

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _go() async {
    if (!_form.currentState!.validate()) return;
    final ok = await submit(() => context.read<SessionCubit>().updatePassword(_password.text));
    if (!ok || !mounted) return;
    showMessage(context, 'Password updated');
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) => _AuthScaffold(
    title: 'Choose a new password',
    subtitle: "You're signed in from the reset link. Set a new password to continue.",
    formKey: _form,
    children: [
      _PasswordField(controller: _password, validator: validateNewPassword, onSubmitted: _go, newPassword: true),
      const SizedBox(height: Space.lg),
      _SubmitButton(label: 'Save password', busy: busy, onPressed: _go),
    ],
  );
}
