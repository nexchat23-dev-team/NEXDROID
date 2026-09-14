import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';

class ThemeProvider extends ChangeNotifier {
  /// themeModePref: 'system' | 'light' | 'dark'
  String _themeModePref = 'system';
  String _chatListWallpaper = 'cyber_void'; // 'cyber_void', 'amoled_black', 'deep_space', 'neon_cyber', 'midnight_slate', 'emerald_matrix'
  String _chatWallpaper = 'cyber_void';
  late SharedPreferences _prefs;

  String get themeModePref => _themeModePref;
  String get chatListWallpaper => _chatListWallpaper;
  String get chatWallpaper => _chatWallpaper;

  ThemeProvider() {
    _initPreferences();
  }

  Future<void> _initPreferences() async {
    _prefs = await SharedPreferences.getInstance();
    _themeModePref = _prefs.getString('themeMode') ?? 'system';
    _chatListWallpaper = _prefs.getString('chatListWallpaper') ?? 'cyber_void';
    _chatWallpaper = _prefs.getString('chatWallpaper') ?? 'cyber_void';
    notifyListeners();
  }

  Future<void> setThemeModePref(String value) async {
    _themeModePref = value;
    await _prefs.setString('themeMode', value);
    notifyListeners();
  }

  Future<void> setChatListWallpaper(String value) async {
    _chatListWallpaper = value;
    await _prefs.setString('chatListWallpaper', value);
    notifyListeners();
  }

  Future<void> setChatWallpaper(String value) async {
    _chatWallpaper = value;
    await _prefs.setString('chatWallpaper', value);
    notifyListeners();
  }

  bool get isDarkMode => _themeModePref == 'dark';

  Future<void> toggleTheme() async {
    if (_themeModePref == 'dark') {
      await setThemeModePref('light');
    } else {
      await setThemeModePref('dark');
    }
  }

  ThemeData getDarkThemeData() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: kPrimaryGreen,
      scaffoldBackgroundColor: kDarkBackground,
      canvasColor: kDarkBackground,
      cardColor: kSurfaceColor,
      fontFamily: 'Roboto',
      colorScheme: const ColorScheme.dark(
        primary: kNeonGreen,
        secondary: kNeonPurple,
        tertiary: kNeonPurple,
        surface: kSurfaceColor,
        onSurface: Colors.white,
        onPrimary: Colors.black,
        onSecondary: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: kPrimaryBlue,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: Colors.white),
        titleTextStyle: TextStyle(
            color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: kDarkBackground,
        selectedItemColor: kNeonPurple,
        unselectedItemColor: Colors.white70,
        showUnselectedLabels: true,
        elevation: 0,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: kNeonPurple,
        foregroundColor: Colors.white,
      ),
      progressIndicatorTheme:
          const ProgressIndicatorThemeData(color: kNeonPurple),
      tabBarTheme: const TabBarThemeData(
        labelColor: kNeonPurple,
        unselectedLabelColor: Colors.white70,
        indicator: UnderlineTabIndicator(
          borderSide: BorderSide(color: kNeonPurple, width: 2),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: kNeonPurple),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: kNeonPurple,
        thumbColor: kNeonPurple,
        overlayColor: kNeonPurple.withValues(alpha: 0.2),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.all(kNeonPurple),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? kNeonPurple.withValues(alpha: 0.6)
              : Colors.white24,
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.all(kNeonPurple),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.all(kNeonPurple),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: kNeonGreen,
          foregroundColor: Colors.black,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
          shadowColor: kNeonPurple.withValues(alpha: 0.32),
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white70,
          side: const BorderSide(color: kNeonPurple),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF0D2F49),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        labelStyle: const TextStyle(color: Colors.white70),
        hintStyle: const TextStyle(color: Colors.white54),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: kNeonPurple,
        contentTextStyle: TextStyle(color: Colors.white),
      ),
      dividerColor: kNeonPurple.withValues(alpha: 0.28),
      listTileTheme: const ListTileThemeData(
        iconColor: kNeonPurple,
        textColor: Colors.white,
        selectedColor: kNeonPurple,
      ),
      splashColor: kNeonPurple.withValues(alpha: 0.1),
      highlightColor: kNeonPurple.withValues(alpha: 0.1),
    );
  }

  ThemeData getLightThemeData() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: kPrimaryGreen,
      scaffoldBackgroundColor: const Color(0xFFF5F5F5),
      canvasColor: const Color(0xFFF5F5F5),
      cardColor: Colors.white,
      fontFamily: 'Roboto',
      colorScheme: const ColorScheme.light(
        primary: kNeonGreen,
        secondary: kNeonPurple,
        tertiary: kNeonPurple,
        surface: Colors.white,
        onSurface: Colors.black87,
        onPrimary: Colors.white,
        onSecondary: Colors.black87,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: kPrimaryBlue,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: Colors.white),
        titleTextStyle: TextStyle(
            color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Color(0xFFF5F5F5),
        selectedItemColor: kNeonPurple,
        unselectedItemColor: Colors.black54,
        showUnselectedLabels: true,
        elevation: 0,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: kNeonPurple,
        foregroundColor: Colors.white,
      ),
      progressIndicatorTheme:
          const ProgressIndicatorThemeData(color: kNeonPurple),
      tabBarTheme: const TabBarThemeData(
        labelColor: kNeonPurple,
        unselectedLabelColor: Colors.black54,
        indicator: UnderlineTabIndicator(
          borderSide: BorderSide(color: kNeonPurple, width: 2),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: kNeonPurple),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: kNeonPurple,
        thumbColor: kNeonPurple,
        overlayColor: kNeonPurple.withValues(alpha: 0.2),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.all(kNeonPurple),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? kNeonPurple.withValues(alpha: 0.6)
              : Colors.black26,
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.all(kNeonPurple),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.all(kNeonPurple),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: kNeonGreen,
          foregroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
          shadowColor: kNeonPurple.withValues(alpha: 0.2),
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.black87,
          side: const BorderSide(color: kNeonPurple),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        labelStyle: const TextStyle(color: Colors.black87),
        hintStyle: const TextStyle(color: Colors.black54),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: kNeonPurple,
        contentTextStyle: TextStyle(color: Colors.white),
      ),
      dividerColor: kNeonPurple.withValues(alpha: 0.25),
      listTileTheme: const ListTileThemeData(
        iconColor: kNeonPurple,
        textColor: Colors.black87,
        selectedColor: kNeonPurple,
      ),
      splashColor: kNeonPurple.withValues(alpha: 0.1),
      highlightColor: kNeonPurple.withValues(alpha: 0.1),
    );
  }
}
