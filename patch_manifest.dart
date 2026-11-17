// Ejecutar desde la carpeta del proyecto: dart run tool/patch_manifest.dart
// Agrega permiso INTERNET y tráfico HTTP (cleartext) para llamar a la API local.
import 'dart:io';

void main() {
  final f = File('android/app/src/main/AndroidManifest.xml');
  var s = f.readAsStringSync();
  if (!s.contains('usesCleartextTraffic')) {
    s = s.replaceFirst('<application', '<application android:usesCleartextTraffic="true"');
  }
  if (!s.contains('android.permission.INTERNET')) {
    s = s.replaceFirst('<application',
        '<uses-permission android:name="android.permission.INTERNET"/>\n    <application');
  }
  f.writeAsStringSync(s);
  print('AndroidManifest.xml actualizado');
}
