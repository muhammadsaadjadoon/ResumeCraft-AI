import 'dart:io';

void main() {
  final generatedTest = File('test/widget_test.dart');
  if (generatedTest.existsSync() &&
      generatedTest.readAsStringSync().contains('MyApp')) {
    generatedTest.deleteSync();
  }

  final manifest = File('android/app/src/main/AndroidManifest.xml');
  if (manifest.existsSync()) {
    var text = manifest.readAsStringSync().replaceAll(
      'android:label="resumecraft_ai"',
      'android:label="ResumeCraft AI"',
    );
    if (!text.contains('android.permission.INTERNET')) {
      text = text.replaceFirst(
        '<application',
        '<uses-permission android:name="android.permission.INTERNET"/>\n    <application',
      );
    }
    manifest.writeAsStringSync(text);
  }
  final debug = File('android/app/src/debug/AndroidManifest.xml');
  if (debug.existsSync()) {
    var text = debug.readAsStringSync();
    if (!text.contains('usesCleartextTraffic')) {
      text = text.replaceFirst(
        '</manifest>',
        '<application android:usesCleartextTraffic="true"/>\n</manifest>',
      );
    }
    debug.writeAsStringSync(text);
  }
  final plist = File('ios/Runner/Info.plist');
  if (plist.existsSync()) {
    var text = plist
        .readAsStringSync()
        .replaceAll(
          '<string>Resumecraft Ai</string>',
          '<string>ResumeCraft AI</string>',
        )
        .replaceAll(
          '<string>resumecraft_ai</string>',
          '<string>ResumeCraft AI</string>',
        );
    plist.writeAsStringSync(text);
  }
  stdout.writeln('Display names and network permissions configured.');
}
