import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

String authMessage(FirebaseAuthException e) {
  switch (e.code) {
    case 'email-already-in-use':
      return 'An account already uses this email. Sign in or reset your password.';
    case 'invalid-credential':
    case 'wrong-password':
    case 'user-not-found':
      return 'Email or password is incorrect.';
    case 'weak-password':
      return 'Choose a stronger password with at least 8 characters.';
    case 'network-request-failed':
      return 'No connection to Firebase. Check your internet and retry.';
    case 'too-many-requests':
      return 'Too many attempts. Wait a moment before trying again.';
    case 'operation-not-allowed':
      return 'Email/password sign-in is not enabled in your Firebase project.';
    default:
      return e.message ?? 'Authentication failed. Please try again.';
  }
}

class SignInDialog extends StatefulWidget {
  const SignInDialog({super.key, required this.signup});
  final bool signup;
  @override
  State<SignInDialog> createState() => _SignInDialogState();
}

class _SignInDialogState extends State<SignInDialog> {
  final email = TextEditingController();
  final password = TextEditingController();
  final name = TextEditingController();
  final form = GlobalKey<FormState>();
  bool waiting = false;
  bool hidden = true;
  String? error;
  @override
  void dispose() {
    email.dispose();
    password.dispose();
    name.dispose();
    super.dispose();
  }

  Future<void> submit({bool reset = false}) async {
    if (waiting) {
      return;
    }
    if (reset) {
      if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email.text.trim())) {
        setState(() => error = 'Enter your email above first.');
        return;
      }
    } else if (!form.currentState!.validate()) {
      return;
    }
    setState(() {
      waiting = true;
      error = null;
    });
    try {
      if (reset) {
        await FirebaseAuth.instance.sendPasswordResetEmail(
          email: email.text.trim(),
        );
        if (mounted) {
          setState(
            () => error = 'If the account exists, a reset link has been sent.',
          );
        }
      } else {
        if (widget.signup) {
          final result = await FirebaseAuth.instance
              .createUserWithEmailAndPassword(
                email: email.text.trim(),
                password: password.text,
              );
          await result.user?.updateDisplayName(name.text.trim());
        } else {
          await FirebaseAuth.instance.signInWithEmailAndPassword(
            email: email.text.trim(),
            password: password.text,
          );
        }
        if (mounted) {
          Navigator.pop(context);
        }
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() => error = authMessage(e));
      }
    } finally {
      if (mounted) {
        setState(() => waiting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !waiting,
    child: AlertDialog(
      title: Text(widget.signup ? 'Start your next chapter' : 'Welcome back'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.signup) ...[
                  TextFormField(
                    controller: name,
                    textCapitalization: TextCapitalization.words,
                    maxLength: 80,
                    decoration: const InputDecoration(
                      labelText: 'Full name',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    validator: (v) =>
                        (v?.trim().isEmpty ?? true) ? 'Enter your name.' : null,
                  ),
                  const SizedBox(height: 14),
                ],
                TextFormField(
                  controller: email,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  validator: (v) =>
                      RegExp(
                        r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                      ).hasMatch(v?.trim() ?? '')
                      ? null
                      : 'Enter a valid email.',
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: password,
                  obscureText: hidden,
                  autofillHints: [
                    widget.signup
                        ? AutofillHints.newPassword
                        : AutofillHints.password,
                  ],
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      tooltip: hidden ? 'Show password' : 'Hide password',
                      onPressed: () => setState(() => hidden = !hidden),
                      icon: Icon(
                        hidden
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                  validator: (v) => (v?.length ?? 0) >= (widget.signup ? 8 : 1)
                      ? null
                      : (widget.signup
                            ? 'Use at least 8 characters.'
                            : 'Enter your password.'),
                ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text(error!),
                  ),
                if (waiting)
                  const Padding(
                    padding: EdgeInsets.only(top: 14),
                    child: LinearProgressIndicator(),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        if (!widget.signup)
          TextButton(
            onPressed: waiting ? null : () => submit(reset: true),
            child: const Text('Forgot password?'),
          ),
        TextButton(
          onPressed: waiting ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: waiting ? null : () => submit(),
          child: Text(widget.signup ? 'Create account' : 'Sign in'),
        ),
      ],
    ),
  );
}

class FactsDialog extends StatefulWidget {
  const FactsDialog({
    super.key,
    this.profileImport = false,
    this.name = '',
    this.email = '',
  });
  final bool profileImport;
  final String name;
  final String email;
  @override
  State<FactsDialog> createState() => _FactsDialogState();
}

class _FactsDialogState extends State<FactsDialog> {
  final form = GlobalKey<FormState>();
  late final name = TextEditingController(text: widget.name);
  late final email = TextEditingController(text: widget.email);
  final role = TextEditingController();
  final facts = TextEditingController();
  final job = TextEditingController();
  @override
  void dispose() {
    for (final c in [name, email, role, facts, job]) {
      c.dispose();
    }
    super.dispose();
  }

  void done(String kind) {
    if (kind != 'pdf' && !form.currentState!.validate()) {
      return;
    }
    Navigator.pop(context, {
      'kind': kind,
      'name': name.text.trim(),
      'email': email.text.trim(),
      'role': role.text.trim(),
      'facts': facts.text.trim(),
      'job': job.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.profileImport ? 'Import your profile' : 'Build a resume with AI',
    ),
    content: SizedBox(
      width: 600,
      child: SingleChildScrollView(
        child: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.profileImport
                    ? 'Paste your own LinkedIn profile text or choose a readable exported PDF.'
                    : 'Give AI your real background. Missing qualifications will stay empty; you review the draft before saving.',
              ),
              const SizedBox(height: 16),
              if (!widget.profileImport) ...[
                TextFormField(
                  controller: name,
                  maxLength: 120,
                  decoration: const InputDecoration(labelText: 'Full name'),
                  validator: (v) =>
                      (v?.trim().isEmpty ?? true) ? 'Enter your name.' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: email,
                  maxLength: 254,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Contact email'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: role,
                  maxLength: 160,
                  decoration: const InputDecoration(
                    labelText: 'Target job title',
                  ),
                  validator: (v) => (v?.trim().isEmpty ?? true)
                      ? 'Enter a target role.'
                      : null,
                ),
                const SizedBox(height: 12),
              ],
              TextFormField(
                controller: facts,
                minLines: 5,
                maxLines: 10,
                maxLength: 20000,
                decoration: InputDecoration(
                  labelText: widget.profileImport
                      ? 'Profile text'
                      : 'Education, skills, experience and projects',
                ),
                validator: (v) => (v?.trim().length ?? 0) < 30
                    ? 'Add at least 30 characters of your real background.'
                    : null,
              ),
              if (!widget.profileImport) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: job,
                  minLines: 3,
                  maxLines: 6,
                  maxLength: 16000,
                  decoration: const InputDecoration(
                    labelText: 'Job description (optional)',
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      if (widget.profileImport)
        OutlinedButton(
          onPressed: () => done('pdf'),
          child: const Text('Choose PDF'),
        ),
      FilledButton(
        onPressed: () => done('text'),
        child: Text(widget.profileImport ? 'Import text' : 'Generate draft'),
      ),
    ],
  );
}
