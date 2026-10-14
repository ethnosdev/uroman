import 'package:uroman/uroman.dart';

void main() {
  // Initialize uroman with embedded data (works on VM, Flutter, and Web)
  final uroman = Uroman();

  // 1. Basic romanization across various writing systems
  print('--- Basic Romanization ---');
  print('Russian:  ${uroman.romanizeString("Игорь Стравинский")}');
  print('Greek:    ${uroman.romanizeString("Καλημέρα κόσμε")}');
  print('Arabic:   ${uroman.romanizeString("مرحبا بالعالم")}');
  print('Chinese:  ${uroman.romanizeString("三千二百五十四")}');
  print('Japanese: ${uroman.romanizeString("ちょっとまってください")}');

  // 2. Language-specific romanization via ISO 639-3 language codes
  print('\n--- Language-Specific Romanization ---');
  print('Default:   ${uroman.romanizeString("Игорь")}'); // Igor
  print('Ukrainian: ${uroman.romanizeString("Игорь", lcode: "ukr")}'); // Yhor

  // 3. Offset tracking (Python code points + native Dart/Flutter UTF-16 offsets)
  print('\n--- Edge Inspection & Offsets ---');
  final edges =
      uroman.romanizeString('ちょっと', format: RomFormat.edges) as List<Edge>;

  for (final edge in edges) {
    print(
      'Span [cp: ${edge.start}..${edge.end}, utf16: ${edge.utf16Start}..${edge.utf16End}]: '
      '${edge.txt} (${edge.type})',
    );
  }
}
