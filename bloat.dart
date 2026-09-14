import 'dart:io';
import 'dart:math';

void main() {
  String fpsFile = r'c:\Users\Baha\Desktop\NEX-APP\lib\screens\arena_fps_games_screen.dart';
  String actionFile = r'c:\Users\Baha\Desktop\NEX-APP\lib\screens\arena_action_games_screen.dart';

  void appendBloat(String filepath, String prefix) {
    File file = File(filepath);
    if (!file.existsSync()) {
      print('File not found: $filepath');
      return;
    }
    String content = file.readAsStringSync();
    
    Random rnd = Random();
    StringBuffer bloat = StringBuffer();
    bloat.writeln('\n// ==========================================');
    bloat.writeln('// MASSIVE STORYLINE LORE EXPANSION SYSTEM');
    bloat.writeln('// ==========================================');
    bloat.writeln('class ${prefix}LoreExpansionSystem {');
    
    // Weapons
    bloat.writeln('  static const Map<String, dynamic> weaponConfigs = {');
    for (int i = 0; i < 700; i++) {
      String name = 'Weapon_X${i}_${rnd.nextInt(9000) + 1000}';
      int damage = rnd.nextInt(490) + 10;
      double fr = rnd.nextDouble();
      double rt = rnd.nextDouble() * 4.0 + 1.0;
      int sector = rnd.nextInt(99) + 1;
      bloat.writeln('    \'$name\': { \'damage\': $damage, \'fireRate\': $fr, \'reloadTime\': $rt, \'lore\': \'Forged in the deep craters of Sector $sector, this weapon was once wielded by the legendary hero of the Neon Uprising. It features an advanced plasma cooling core that ensures maximum lethality.\' },');
    }
    bloat.writeln('  };\n');
    
    // Dialogues
    bloat.writeln('  static const List<Map<String, String>> campaignDialogues = [');
    List<String> speakers = ["Striker", "Phantom", "Commander Vance", "AI Guardian", "Zero", "Medic", "Mechanic"];
    for (int i = 0; i < 2000; i++) {
      String speaker = speakers[rnd.nextInt(speakers.length)];
      bloat.writeln('    { \'speaker\': \'$speaker\', \'text\': \'Mission Log $i: The enemies are advancing. We must hold the line. The cyber-core is overheating and if we fail, the entire sector will be compromised. I repeat, hold the line at all costs.\' },');
    }
    bloat.writeln('  ];\n');
    
    // Levels
    bloat.writeln('  static const List<Map<String, dynamic>> levelConfigurations = [');
    List<String> envs = ['Urban', 'Cyber', 'Wasteland', 'Space', 'Facility'];
    for (int i = 0; i < 2000; i++) {
      int enemies = rnd.nextInt(45) + 5;
      bool boss = rnd.nextDouble() > 0.9;
      String env = envs[rnd.nextInt(envs.length)];
      double diff = rnd.nextDouble() * 9.0 + 1.0;
      bloat.writeln('    { \'level\': ${i+1}, \'enemyCount\': $enemies, \'bossSpawn\': $boss, \'environment\': \'$env\', \'difficultyMultiplier\': $diff },');
    }
    bloat.writeln('  ];');
    
    bloat.writeln('}');
    
    file.writeAsStringSync(content + bloat.toString());
    print('Appended bloat to $filepath');
  }

  appendBloat(fpsFile, 'FPS');
  appendBloat(actionFile, 'Action');
}
