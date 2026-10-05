import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'store.dart';
import 'config.dart';
import 'dialogs.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key, required this.store, required this.onSignIn});
  final ResumeStore store;
  final Future<void> Function(bool) onSignIn;
  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  bool waiting = false;
  String? notice;
  User? get user =>
      widget.store.cloudReady ? FirebaseAuth.instance.currentUser : null;
  Future<void> run(Future<String> Function() task) async {
    if (waiting) {
      return;
    }
    setState(() {
      waiting = true;
      notice = null;
    });
    try {
      final text = await task();
      if (mounted) {
        setState(() => notice = text);
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() => notice = authMessage(e));
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => notice =
              'This action could not finish. Check your connection and try again.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => waiting = false);
      }
    }
  }

  Widget card(List<Widget> children) => Card(
    margin: const EdgeInsets.only(bottom: 18),
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    ),
  );
  Widget action(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback? tap,
  ) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(icon),
    title: Text(title),
    subtitle: Text(subtitle),
    trailing: const Icon(Icons.chevron_right),
    onTap: waiting ? null : tap,
  );
  Future<void> editProfile() async {
    final current = user;
    if (current == null) {
      return;
    }
    final name = await showDialog<String>(
      context: context,
      builder: (_) => NameDialog(initial: current.displayName ?? ''),
    );
    if (name == null || !mounted) {
      return;
    }
    await run(() async {
      await current.updateDisplayName(name);
      return 'Profile updated.';
    });
  }

  Future<void> signOut() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
          'Your saved account resumes will be available when you sign in again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Stay signed in'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (yes == true && mounted) {
      await run(() async {
        await FirebaseAuth.instance.signOut();
        return 'Signed out.';
      });
    }
  }

  Future<void> checkConnection() => run(() async {
    final base = Config.api.replaceAll(RegExp(r'/+$'), '');
    if (base.isEmpty) {
      return 'AI server URL is missing. Add API_BASE_URL and restart the app.';
    }
    final response = await http
        .get(Uri.parse('$base/health'))
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      return 'AI server is not ready. Check the backend terminal.';
    }
    final data = jsonDecode(response.body) as Map;
    if (data['ai_configured'] != true) {
      return 'Server connected. Add GEMINI_API_KEY to backend/.env and restart the backend.';
    }
    if (data['firebase_configured'] != true) {
      return 'Server connected. Add FIREBASE_PROJECT_ID to backend/.env and restart the backend.';
    }
    return 'AI server is reachable and its configuration is present. Generate a draft to verify your session and Gemini quota.';
  });
  @override
  Widget build(BuildContext context) {
    final current = user;
    final display = (current?.displayName?.trim().isNotEmpty ?? false)
        ? current!.displayName!
        : (current == null ? 'Your career workspace' : 'Your profile');
    final initials = display
        .split(RegExp(r'\s+'))
        .where((s) => s.isNotEmpty)
        .take(2)
        .map((s) => s[0])
        .join()
        .toUpperCase();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'My account',
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: 8),
              const Text(
                'Your identity, your documents, your next opportunity.',
              ),
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xff173e9e),
                      Color(0xff245bdb),
                      Color(0xff078d9b),
                    ],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 34,
                      backgroundColor: Colors.white,
                      child: Text(
                        initials,
                        style: const TextStyle(
                          color: Color(0xff245bdb),
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      display,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      current?.email ??
                          'Build a resume locally or sign in to save it to your account.',
                      style: const TextStyle(
                        color: Colors.white70,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      children: [
                        Chip(
                          label: Text(
                            current == null
                                ? 'Device workspace'
                                : current.emailVerified
                                ? 'Email verified'
                                : 'Email not verified',
                          ),
                        ),
                        Chip(
                          label: Text('${widget.store.resumes.length} resumes'),
                        ),
                      ],
                    ),
                    if (current == null && widget.store.cloudReady) ...[
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          FilledButton.tonal(
                            onPressed: waiting
                                ? null
                                : () => widget.onSignIn(false),
                            child: const Text('Sign in'),
                          ),
                          OutlinedButton(
                            onPressed: waiting
                                ? null
                                : () => widget.onSignIn(true),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Colors.white70),
                            ),
                            child: const Text('Create account'),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),
              if (waiting)
                const Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: LinearProgressIndicator(),
                ),
              if (notice != null)
                card([
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline),
                      const SizedBox(width: 12),
                      Expanded(child: Text(notice!)),
                    ],
                  ),
                ]),
              if (current != null)
                card([
                  Text(
                    'Profile & security',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  action(
                    Icons.person_outline,
                    'Edit profile',
                    'Update the name shown on your account.',
                    editProfile,
                  ),
                  if (!current.emailVerified)
                    action(
                      Icons.mark_email_read_outlined,
                      'Verify your email',
                      'Send a verification link to your inbox.',
                      () => run(() async {
                        await current.sendEmailVerification();
                        return 'Verification email sent. Check your inbox and spam folder.';
                      }),
                    ),
                  action(
                    Icons.refresh,
                    'Refresh account',
                    'Update your email verification and session.',
                    () => run(() async {
                      await current.reload();
                      await FirebaseAuth.instance.currentUser?.getIdToken(true);
                      return 'Account refreshed.';
                    }),
                  ),
                  action(
                    Icons.lock_outline,
                    'Reset password',
                    'Send a secure password reset email.',
                    () => run(() async {
                      await FirebaseAuth.instance.sendPasswordResetEmail(
                        email: current.email!,
                      );
                      return 'Password reset email sent.';
                    }),
                  ),
                ]),
              card([
                Text(
                  'Documents & connection',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Text(
                  current == null
                      ? 'Drafts are saved on this device.'
                      : '${widget.store.pendingCount} local changes awaiting cloud save.',
                ),
                if (current != null)
                  action(
                    Icons.cloud_sync_outlined,
                    'Sync resumes',
                    'Retry pending saves to your account.',
                    () => run(() async {
                      await widget.store.retrySync();
                      return widget.store.error ?? 'Cloud sync finished.';
                    }),
                  ),
                action(
                  Icons.wifi_tethering,
                  'Check AI connection',
                  'Confirm the backend is reachable and configured.',
                  checkConnection,
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Text(
                    'Local and signed-in drafts are separate workspaces. Export a JSON backup in the editor and import it while signed in to move a draft.',
                  ),
                ),
              ]),
              card([
                Text(
                  'Preferences',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Dark appearance'),
                  subtitle: const Text(
                    'Choose the look that feels comfortable.',
                  ),
                  value: widget.store.dark,
                  onChanged: waiting ? null : widget.store.setDark,
                ),
                const Divider(),
                const Text(
                  'Your resume is sent to Gemini only when you use an AI tool. Review generated claims before sharing. Export backups before clearing app data.',
                  style: TextStyle(height: 1.5),
                ),
              ]),
              if (current != null)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: waiting ? null : signOut,
                    icon: const Icon(Icons.logout),
                    label: const Text('Sign out'),
                  ),
                ),
              const SizedBox(height: 20),
              const Center(child: Text('ResumeCraft AI · 1.1.0')),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

class NameDialog extends StatefulWidget {
  const NameDialog({super.key, required this.initial});
  final String initial;
  @override
  State<NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<NameDialog> {
  late final name = TextEditingController(text: widget.initial);
  final form = GlobalKey<FormState>();
  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Edit profile'),
    content: Form(
      key: form,
      child: TextFormField(
        controller: name,
        autofocus: true,
        maxLength: 80,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(labelText: 'Full name'),
        validator: (v) => (v?.trim().isEmpty ?? true) ? 'Enter a name.' : null,
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          if (form.currentState!.validate()) {
            Navigator.pop(context, name.text.trim());
          }
        },
        child: const Text('Save changes'),
      ),
    ],
  );
}
