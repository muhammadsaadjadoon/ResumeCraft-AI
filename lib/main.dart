import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';

import 'config.dart';
import 'resume.dart';
import 'store.dart';
import 'ai_service.dart';
import 'pdf_service.dart';
import 'dialogs.dart';
import 'account_screen.dart';

const blue = Color(0xff245bdb);
const teal = Color(0xff16b8b5);
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  bool cloud = false;
  String? warning;
  if (Config.cloudConfigured) {
    try {
      await Firebase.initializeApp(options: Config.firebase);
      cloud = true;
    } catch (_) {
      warning = 'Firebase could not start. You can still create local drafts.';
    }
  }
  final store = ResumeStore(await SharedPreferences.getInstance(), cloud);
  await store.init();
  store.error ??= warning;
  runApp(ResumeCraft(store: store));
}

class ResumeCraft extends StatelessWidget {
  const ResumeCraft({super.key, required this.store});
  final ResumeStore store;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: store,
    builder: (context, _) {
      final scheme = ColorScheme.fromSeed(
        seedColor: blue,
        brightness: store.dark ? Brightness.dark : Brightness.light,
      );
      return MaterialApp(
        title: 'ResumeCraft AI',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: scheme,
          scaffoldBackgroundColor: store.dark
              ? const Color(0xff101827)
              : const Color(0xfff4f7fc),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: scheme.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: scheme.outlineVariant),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: scheme.outlineVariant),
            ),
            contentPadding: const EdgeInsets.all(16),
          ),
          cardTheme: CardThemeData(
            elevation: 0,
            color: scheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
          ),
          filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 17),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          textTheme: const TextTheme(
            headlineLarge: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              letterSpacing: -1,
            ),
            headlineSmall: TextStyle(fontWeight: FontWeight.w700),
            titleLarge: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        home: Workspace(store: store),
      );
    },
  );
}

class Workspace extends StatefulWidget {
  const Workspace({super.key, required this.store});
  final ResumeStore store;
  @override
  State<Workspace> createState() => _WorkspaceState();
}

class _WorkspaceState extends State<Workspace> {
  int page = 0;
  bool busy = false;
  String? busyLabel;
  final job = TextEditingController();
  ResumeStore get store => widget.store;
  @override
  void dispose() {
    job.dispose();
    super.dispose();
  }

  void message(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  Future<void> work(String label, Future<void> Function() task) async {
    if (busy) {
      return;
    }
    setState(() {
      busy = true;
      busyLabel = label;
    });
    try {
      await task();
    } catch (e) {
      if (mounted) {
        await showDialog<void>(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text('Could not finish this action'),
            content: SingleChildScrollView(
              child: Text(e.toString().replaceFirst('Exception: ', '')),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  void edit([Resume? r]) {
    if (r != null) {
      store.select(r);
    }
    if (store.selected == null) {
      store.add();
    }
    setState(() => page = 1);
  }

  Future<void> export() async {
    final r = store.selected;
    if (r == null) {
      return;
    }
    if (r.data['name']!.trim().isEmpty) {
      message('Add your name before exporting.');
      return;
    }
    await work('Preparing your PDF', () async {
      final bytes = await ResumePdf.build(r);
      await Printing.sharePdf(
        bytes: bytes,
        filename:
            '${r.title.replaceAll(RegExp(r'[^a-zA-Z0-9 _-]'), '').trim().isEmpty ? 'Resume' : r.title.replaceAll(RegExp(r'[^a-zA-Z0-9 _-]'), '')}.pdf',
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    const labels = [
      'Overview',
      'Resume editor',
      'Templates',
      'AI studio',
      'Account',
    ];
    const icons = [
      Icons.space_dashboard_outlined,
      Icons.edit_document,
      Icons.layers_outlined,
      Icons.auto_awesome_outlined,
      Icons.person_outline,
    ];
    final content = switch (page) {
      0 => dashboard(),
      1 => editor(),
      2 => templates(),
      3 => aiStudio(),
      _ => account(),
    };
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Row(
          children: [
            Image.asset('assets/logo.png', width: 36, height: 36),
            const SizedBox(width: 10),
            const Flexible(
              child: Text(
                'ResumeCraft',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(width: 6),
            const Text(
              'AI',
              style: TextStyle(
                color: blue,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Toggle dark theme',
            onPressed: () => store.setDark(!store.dark),
            icon: Icon(
              store.dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          if (store.error != null)
            MaterialBanner(
              content: Text(store.error!),
              actions: [
                TextButton(
                  onPressed: () => work('Retrying sync', store.retrySync),
                  child: const Text('Retry sync'),
                ),
                TextButton(
                  onPressed: () {
                    store.error = null;
                    setState(() {});
                  },
                  child: const Text('Dismiss'),
                ),
              ],
            ),
          if (busy)
            Column(
              children: [
                const LinearProgressIndicator(),
                Padding(
                  padding: const EdgeInsets.all(6),
                  child: Text(busyLabel ?? 'Working…'),
                ),
              ],
            ),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (wide)
                  NavigationRail(
                    extended: true,
                    selectedIndex: page,
                    onDestinationSelected: (i) => setState(() => page = i),
                    minExtendedWidth: 210,
                    labelType: NavigationRailLabelType.none,
                    destinations: List.generate(
                      labels.length,
                      (i) => NavigationRailDestination(
                        icon: Icon(icons[i]),
                        label: Text(labels[i]),
                      ),
                    ),
                  ),
                Expanded(
                  child: AbsorbPointer(absorbing: busy, child: content),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: page,
              onDestinationSelected: (i) => setState(() => page = i),
              destinations: List.generate(
                labels.length,
                (i) => NavigationDestination(
                  icon: Icon(icons[i]),
                  label: ['Home', 'Editor', 'Templates', 'AI', 'Account'][i],
                ),
              ),
            ),
    );
  }

  Widget body(List<Widget> children) => SingleChildScrollView(
    padding: EdgeInsets.all(MediaQuery.sizeOf(context).width < 500 ? 18 : 32),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      ),
    ),
  );
  Widget heading(String title, String subtitle) => Padding(
    padding: const EdgeInsets.only(bottom: 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.headlineLarge),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            height: 1.5,
          ),
        ),
      ],
    ),
  );
  Widget panel(Widget child) => Card(
    margin: const EdgeInsets.only(bottom: 18),
    child: Padding(padding: const EdgeInsets.all(22), child: child),
  );
  Widget dashboard() => body([
    heading(
      'Your next chapter starts here.',
      'Build a clear, confident resume. Keep your story authentic.',
    ),
    Container(
      width: double.infinity,
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xff133994), blue, Color(0xff078d9b)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.auto_awesome, color: Colors.white, size: 30),
          const SizedBox(height: 14),
          const Text(
            'Good experience deserves\na great introduction.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w800,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Turn your skills into a resume you are proud to send.',
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: blue,
            ),
            onPressed: () {
              store.add();
              edit();
            },
            icon: const Icon(Icons.add),
            label: const Text('Create a resume'),
          ),
        ],
      ),
    ),
    const SizedBox(height: 16),
    OutlinedButton.icon(
      onPressed: createWithAi,
      icon: const Icon(Icons.auto_awesome),
      label: const Text('Build a resume with AI'),
    ),
    const SizedBox(height: 24),
    Wrap(
      spacing: 16,
      runSpacing: 12,
      children: [
        stat(
          'Saved resumes',
          '${store.resumes.length}',
          Icons.description_outlined,
        ),
        stat(
          'Draft completeness',
          '${store.selected?.completeness ?? 0}%',
          Icons.task_alt,
        ),
        stat(
          'Workspace',
          store.cloudReady && FirebaseAuth.instance.currentUser != null
              ? 'Cloud + device'
              : 'On this device',
          Icons.cloud_outlined,
        ),
      ],
    ),
    const SizedBox(height: 24),
    Row(
      children: [
        Expanded(
          child: Text(
            'My resumes',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        TextButton.icon(
          onPressed: importBackup,
          icon: const Icon(Icons.file_upload_outlined),
          label: const Text('Import backup'),
        ),
      ],
    ),
    const SizedBox(height: 12),
    if (store.resumes.isEmpty)
      panel(
        Column(
          children: [
            const Icon(Icons.description_outlined, size: 52, color: blue),
            const SizedBox(height: 16),
            const Text(
              'A fresh start, a stronger story.',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('Create your first resume or import a JSON backup.'),
            const SizedBox(height: 18),
            OutlinedButton(
              onPressed: () {
                store.add();
                edit();
              },
              child: const Text('Start building'),
            ),
          ],
        ),
      ),
    for (final r in store.resumes)
      panel(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Color(r.accent).withValues(alpha: .1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.description_outlined,
                    color: Color(r.accent),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        r.title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        r.data['role']!.isEmpty
                            ? 'Add a target role'
                            : r.data['role']!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (v) async {
                    if (v == 'copy') {
                      store.add(r.duplicate());
                    }
                    if (v == 'delete') {
                      final yes = await showDialog<bool>(
                        context: context,
                        builder: (c) => AlertDialog(
                          title: const Text('Delete this resume?'),
                          content: const Text(
                            'This removes the draft from this workspace. Export a backup first if needed.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(c, false),
                              child: const Text('Cancel'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(c, true),
                              child: const Text('Delete'),
                            ),
                          ],
                        ),
                      );
                      if (yes == true) {
                        await work('Deleting resume', () => store.remove(r));
                      }
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'copy',
                      child: Text('Duplicate'),
                    ),
                    const PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: r.completeness / 100,
              borderRadius: BorderRadius.circular(8),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text('${r.completeness}% complete · ${r.template}'),
                Text(
                  'Updated ${r.updated.toLocal().toString().substring(0, 16)}',
                  style: const TextStyle(fontSize: 12),
                ),
                OutlinedButton(
                  onPressed: () => edit(r),
                  child: const Text('Continue editing'),
                ),
              ],
            ),
          ],
        ),
      ),
  ]);
  Widget stat(String label, String value, IconData icon) => SizedBox(
    width: MediaQuery.sizeOf(context).width < 500 ? double.infinity : 260,
    child: panel(
      Row(
        children: [
          Icon(icon, color: blue),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(label),
              ],
            ),
          ),
        ],
      ),
    ),
  );
  Widget editor() {
    final r = store.selected;
    if (r == null) {
      return body([
        heading('Make it yours.', 'Create a resume to open the editor.'),
        FilledButton(
          onPressed: () {
            store.add();
            setState(() {});
          },
          child: const Text('Create resume'),
        ),
      ]);
    }
    final form = Column(
      children: [
        panel(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Your workspace',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: ValueKey('${r.id}_title'),
                initialValue: r.title,
                decoration: const InputDecoration(labelText: 'Resume title'),
                maxLength: 80,
                onChanged: (v) {
                  r.title = v;
                  store.changed(r);
                },
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                key: ValueKey('switch_${r.id}'),
                initialValue: r.id,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Switch resume'),
                items: store.resumes
                    .map(
                      (x) => DropdownMenuItem(
                        value: x.id,
                        child: Text(x.title, overflow: TextOverflow.ellipsis),
                      ),
                    )
                    .toList(),
                onChanged: (id) {
                  if (id != null) {
                    store.select(store.resumes.firstWhere((x) => x.id == id));
                  }
                },
              ),
            ],
          ),
        ),
        section(r, '01  Personal details', [
          'name',
          'role',
          'email',
          'phone',
          'location',
          'linkedin',
          'website',
        ]),
        section(r, '02  Tell your story', ['summary', 'skills']),
        section(r, '03  Experience & education', ['experience', 'education']),
        section(r, '04  Make your strengths visible', [
          'projects',
          'certifications',
          'languages',
        ]),
        panel(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Readiness checklist',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                '${r.completeness}% of essential sections filled. This is a completeness check, not an ATS score.',
              ),
              const SizedBox(height: 12),
              for (final check in r.checks)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, size: 16, color: blue),
                      const SizedBox(width: 8),
                      Expanded(child: Text(check)),
                    ],
                  ),
                ),
              if (r.checks.isEmpty)
                const Text(
                  'Essential sections are complete. Review facts and spelling before sending.',
                ),
            ],
          ),
        ),
      ],
    );
    return body([
      heading(
        'Resume editor',
        'Drafts save on this device as you type. Cloud save is available when signed in.',
      ),
      Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          FilledButton.icon(
            onPressed: export,
            icon: const Icon(Icons.file_download_outlined),
            label: const Text('Export PDF'),
          ),
          OutlinedButton.icon(
            onPressed: preview,
            icon: const Icon(Icons.visibility_outlined),
            label: const Text('PDF preview'),
          ),
          OutlinedButton.icon(
            onPressed: backup,
            icon: const Icon(Icons.backup_outlined),
            label: const Text('JSON backup'),
          ),
          OutlinedButton.icon(
            onPressed: importProfile,
            icon: const Icon(Icons.person_add_alt),
            label: const Text('Import LinkedIn'),
          ),
        ],
      ),
      const SizedBox(height: 22),
      LayoutBuilder(
        builder: (context, c) => c.maxWidth > 950
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: form),
                  const SizedBox(width: 24),
                  Expanded(flex: 2, child: resumePreview(r)),
                ],
              )
            : form,
      ),
    ]);
  }

  Widget section(Resume r, String title, List<String> fields) => panel(
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 18),
        for (final k in fields)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: TextFormField(
              key: ValueKey('${r.id}_${k}_$_revision'),
              initialValue: r.data[k],
              // Revision changes only after an external AI update; typing keeps field state.
              decoration: InputDecoration(
                labelText: resumeFields[k],
                helperText: ['experience', 'education', 'projects'].contains(k)
                    ? 'Use a heading and concise bullet lines for each entry.'
                    : null,
              ),
              minLines:
                  ['summary', 'experience', 'education', 'projects'].contains(k)
                  ? 3
                  : 1,
              maxLines:
                  [
                    'summary',
                    'experience',
                    'education',
                    'projects',
                    'certifications',
                  ].contains(k)
                  ? 10
                  : 2,
              keyboardType: k == 'email'
                  ? TextInputType.emailAddress
                  : TextInputType.multiline,
              maxLength:
                  [
                    'summary',
                    'experience',
                    'education',
                    'projects',
                    'certifications',
                  ].contains(k)
                  ? 12000
                  : const {
                          'name': 120,
                          'role': 160,
                          'email': 254,
                          'phone': 60,
                          'location': 160,
                          'linkedin': 500,
                          'website': 500,
                        }[k] ??
                        2000,
              onChanged: (v) {
                r.data[k] = v;
                store.changed(r);
              },
            ),
          ),
      ],
    ),
  );
  Widget resumePreview(Resume r) => panel(
    Column(
      crossAxisAlignment: r.template == 'classic'
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        Text(
          'LIVE OUTLINE',
          style: TextStyle(
            fontSize: 10,
            letterSpacing: 2,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 22),
        Text(
          r.data['name']!.isEmpty ? 'Your name' : r.data['name']!,
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: Color(r.accent),
          ),
        ),
        const SizedBox(height: 6),
        Text(r.data['role']!),
        const SizedBox(height: 12),
        Text(
          [
            'email',
            'phone',
            'location',
          ].map((k) => r.data[k]!).where((s) => s.isNotEmpty).join(' · '),
          style: const TextStyle(fontSize: 11),
        ),
        const Divider(height: 30),
        for (final k in [
          'summary',
          'skills',
          'experience',
          'education',
          'projects',
          'certifications',
          'languages',
        ])
          if (r.data[k]!.isNotEmpty) ...[
            Text(
              resumeFields[k]!.split(' (').first.toUpperCase(),
              style: TextStyle(
                color: Color(r.accent),
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 8),
            Text(r.data[k]!, style: const TextStyle(fontSize: 12, height: 1.5)),
            const SizedBox(height: 20),
          ],
        const Text(
          'Use PDF preview to check the final page layout.',
          style: TextStyle(fontSize: 11),
        ),
      ],
    ),
  );
  Widget templates() => body([
    heading(
      'A polished first impression.',
      'Three readable layouts, with an accent that feels like you.',
    ),
    if (store.selected == null)
      const Text('Create a resume first to apply a template.'),
    const SizedBox(height: 12),
    Wrap(
      spacing: 18,
      runSpacing: 18,
      children: [
        for (final entry in [
          (
            'modern',
            'Modern',
            'A confident accent and a crisp left aligned header.',
          ),
          (
            'classic',
            'Classic',
            'A centered header and understated section styling.',
          ),
          ('minimal', 'Minimal', 'Black headings and a quiet, clean document.'),
        ])
          SizedBox(
            width: 300,
            child: panel(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    constraints: const BoxConstraints(minHeight: 190),
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xfff0f4fc),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: entry.$1 == 'classic'
                          ? CrossAxisAlignment.center
                          : CrossAxisAlignment.start,
                      children: [
                        Text(
                          'YOUR NAME',
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                            color: entry.$1 == 'minimal' ? Colors.black : blue,
                          ),
                        ),
                        const Text(
                          'Your next role',
                          style: TextStyle(fontSize: 10, color: Colors.black54),
                        ),
                        const Divider(height: 22),
                        for (int i = 0; i < 5; i++)
                          Container(
                            height: i == 0 ? 6 : 4,
                            width: i == 0 ? 90 : double.infinity,
                            margin: const EdgeInsets.only(bottom: 13),
                            color: i == 0 ? teal : Colors.blueGrey.shade200,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(entry.$2, style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text(entry.$3),
                  const SizedBox(height: 18),
                  FilledButton.tonal(
                    onPressed: store.selected == null
                        ? null
                        : () {
                            store.selected!.template = entry.$1;
                            store.changed(store.selected!);
                            message('${entry.$2} template applied.');
                          },
                    child: Text(
                      store.selected?.template == entry.$1
                          ? 'Selected'
                          : 'Use template',
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    ),
    const SizedBox(height: 18),
    panel(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Accent color',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            children: [
              for (final color in [
                0xff245bdb,
                0xff087f8c,
                0xff6049c9,
                0xff334155,
                0xffa44525,
              ])
                Semantics(
                  label: 'Select accent ${color.toRadixString(16)}',
                  button: true,
                  child: IconButton(
                    onPressed: store.selected == null
                        ? null
                        : () {
                            store.selected!.accent = color;
                            store.changed(store.selected!);
                          },
                    icon: Icon(
                      store.selected?.accent == color
                          ? Icons.check_circle
                          : Icons.circle,
                      color: Color(color),
                      size: 38,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    ),
  ]);
  Widget aiStudio() => body([
    panel(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Start with your real experience',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          const Text(
            'Create a new resume with AI, or choose a saved draft to improve.',
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: createWithAi,
            icon: const Icon(Icons.auto_awesome),
            label: const Text('Create a resume with AI'),
          ),
          if (store.resumes.isNotEmpty) ...[
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              key: ValueKey('ai_${store.selected?.id}'),
              initialValue: store.selected?.id,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Resume to improve'),
              items: store.resumes
                  .map(
                    (r) => DropdownMenuItem(
                      value: r.id,
                      child: Text(r.title, overflow: TextOverflow.ellipsis),
                    ),
                  )
                  .toList(),
              onChanged: (id) {
                if (id != null) {
                  store.select(store.resumes.firstWhere((r) => r.id == id));
                }
              },
            ),
          ],
        ],
      ),
    ),
    heading(
      'Better words. Still your story.',
      'Gemini helps shape your existing facts. Review every suggestion before applying it.',
    ),
    panel(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.auto_awesome, color: blue, size: 32),
          const SizedBox(height: 16),
          Text(
            store.selected == null
                ? 'Choose or create a resume first.'
                : 'Working on: ${store.selected!.title}',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: job,
            minLines: 5,
            maxLines: 12,
            maxLength: 16000,
            decoration: const InputDecoration(
              labelText: 'Target job description / career goal',
              hintText: 'Paste the role requirements to get tailored advice.',
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton.icon(
                onPressed: store.selected == null
                    ? null
                    : () => assist('rewrite'),
                icon: const Icon(Icons.auto_awesome),
                label: const Text('Improve content'),
              ),
              OutlinedButton.icon(
                onPressed: store.selected == null
                    ? null
                    : () => assist('review'),
                icon: const Icon(Icons.fact_check_outlined),
                label: const Text('Review for this job'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Only the selected resume and job description are sent to the configured AI service. AI does not invent qualifications or automatically overwrite your draft.',
            style: TextStyle(fontSize: 12, height: 1.5),
          ),
        ],
      ),
    ),
    panel(
      const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'What makes a strong resume?',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 12),
          Text(
            '• Match real skills to the role.\n• Describe what you did and the outcome.\n• Use numbers only when you can verify them.\n• Keep dates, job titles and contact details accurate.',
            style: TextStyle(height: 1.8),
          ),
        ],
      ),
    ),
  ]);
  Future<void> assist(String mode) async {
    final r = store.selected;
    if (r == null) {
      message('Create or select a resume first.');
      return;
    }
    final workspace = store.workspaceKey;
    if (r.data.values.every((s) => s.trim().isEmpty)) {
      message('Add your background first so AI has facts to work with.');
      return;
    }
    if (mode == 'review' && job.text.trim().isEmpty) {
      message('Paste a target job description first.');
      return;
    }
    await work('Gemini is reviewing your draft', () async {
      final result = await AiService(
        store.cloudReady,
      ).generate(r, job.text, mode);
      if (!mounted || workspace != store.workspaceKey) {
        return;
      }
      await reviewResult(r, result, mode == 'rewrite');
    });
  }

  Future<void> reviewResult(
    Resume r,
    Map<String, dynamic> result,
    bool canApply, {
    bool isNew = false,
  }) async {
    final workspace = store.workspaceKey;
    final raw = result['resume'];
    final data = raw is Map
        ? {for (final k in resumeFields.keys) k: '${raw[k] ?? ''}'}
        : <String, String>{};
    final advice = (result['suggestions'] as List? ?? [])
        .map((s) => '$s')
        .toList();
    final apply = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Review AI suggestions'),
        content: SizedBox(
          width: 650,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final a in advice)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text('• $a'),
                  ),
                if (canApply) ...[
                  const Divider(),
                  const Text(
                    'Proposed resume content',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  for (final k in resumeFields.keys)
                    if ((data[k] ?? '').isNotEmpty) ...[
                      Text(
                        resumeFields[k]!,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(data[k]!),
                      const SizedBox(height: 12),
                    ],
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Keep my draft'),
          ),
          if (canApply && data.isNotEmpty)
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Apply reviewed content'),
            ),
        ],
      ),
    );
    if (!mounted || workspace != store.workspaceKey) {
      return;
    }
    if (apply == true) {
      for (final k in data.keys) {
        if (data[k]!.trim().isNotEmpty) {
          r.data[k] = data[k]!;
        }
      }
      if (isNew) {
        store.add(r);
      } else {
        store.changed(r);
      }
      _revision++;
      if (mounted) {
        setState(() => page = 1);
      }
      message('Reviewed content applied. Please verify all facts.');
    }
  }

  int _revision = 0;
  Future<void> preview() async {
    final r = store.selected;
    if (r == null) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Resume preview')),
          body: PdfPreview(
            build: (format) => ResumePdf.build(r, format),
            initialPageFormat: PdfPageFormat.a4,
            canChangeOrientation: false,
            canChangePageFormat: false,
            pdfFileName: 'resume.pdf',
          ),
        ),
      ),
    );
  }

  Future<void> backup() async {
    final r = store.selected;
    if (r == null) {
      return;
    }
    await work('Exporting backup', () async {
      await FilePicker.platform.saveFile(
        dialogTitle: 'Save resume backup',
        fileName: 'resume-backup.json',
        type: FileType.custom,
        allowedExtensions: ['json'],
        bytes: Uint8List.fromList(
          utf8.encode(const JsonEncoder.withIndent('  ').convert(r.toJson())),
        ),
      );
    });
  }

  Future<void> importBackup() async {
    await work('Importing backup', () async {
      final file = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        withData: true,
      );
      if (file == null) {
        return;
      }
      final bytes = file.files.single.bytes;
      if (bytes == null || bytes.length > 1000000) {
        throw Exception('Choose a JSON backup smaller than 1 MB.');
      }
      final json = jsonDecode(utf8.decode(bytes));
      if (json is! Map || json['data'] is! Map || json['id'] is! String) {
        throw Exception('This is not a ResumeCraft backup.');
      }
      final imported = Resume.fromJson(Map<String, dynamic>.from(json));
      store.add(imported.duplicate()..title = imported.title);
      message('Backup imported as a new draft.');
    });
  }

  Future<void> importProfile() async {
    final input = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => const FactsDialog(profileImport: true),
    );
    if (input == null || !mounted) {
      return;
    }
    final workspace = store.workspaceKey;
    await work('Extracting profile content', () async {
      final service = AiService(store.cloudReady);
      Map<String, dynamic> result;
      if (input['kind'] == 'pdf') {
        final file = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['pdf'],
          withData: true,
        );
        if (file == null) {
          return;
        }
        final bytes = file.files.single.bytes;
        if (bytes == null || bytes.length > 5000000) {
          throw const AiFailure('Choose a readable PDF under 5 MB.');
        }
        result = await service.importPdf(bytes);
      } else {
        result = await service.importProfile(input['facts']!);
      }
      if (!mounted || workspace != store.workspaceKey) {
        return;
      }
      final candidate = store.selected ?? Resume.empty();
      await reviewResult(
        candidate,
        result,
        true,
        isNew: store.selected == null,
      );
    });
  }

  Future<void> createWithAi() async {
    final user = store.cloudReady ? FirebaseAuth.instance.currentUser : null;
    if (store.cloudReady && user == null) {
      await authDialog(false);
      if (!mounted || FirebaseAuth.instance.currentUser == null) {
        return;
      }
    }
    if (!mounted) {
      return;
    }
    final current = store.cloudReady ? FirebaseAuth.instance.currentUser : null;
    final input = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => FactsDialog(
        name: current?.displayName ?? '',
        email: current?.email ?? '',
      ),
    );
    if (input == null || !mounted) {
      return;
    }
    final candidate = Resume.empty();
    candidate.data['name'] = input['name']!;
    candidate.data['email'] = input['email']!;
    candidate.data['role'] = input['role']!;
    final title = '${input['name']} - ${input['role']}';
    candidate.title = title.length > 80 ? title.substring(0, 80) : title;
    final workspace = store.workspaceKey;
    await work('Building your AI resume', () async {
      final result = await AiService(
        store.cloudReady,
      ).create(candidate, input['facts']!, input['job']!);
      if (!mounted || workspace != store.workspaceKey) {
        return;
      }
      await reviewResult(candidate, result, true, isNew: true);
    });
  }

  Widget account() => AccountScreen(store: store, onSignIn: authDialog);
  Future<void> authDialog(bool signup) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => SignInDialog(signup: signup),
    );
    if (mounted) {
      setState(() {});
    }
  }
}
