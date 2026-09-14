import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:workmanager/workmanager.dart';
import 'package:provider/provider.dart';
import 'providers/token_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/ai_chat_screen.dart';
import 'screens/bet_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/conversations_list_screen.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/marketplace_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/group_chat_screen.dart';
import 'screens/contact_info_screen.dart';
import 'screens/group_info_screen.dart';
import 'screens/calls_screen.dart';
import 'screens/announcements_screen.dart';
import 'screens/terminal_screen.dart';
import 'screens/video_feed_screen.dart';
import 'screens/video_post_screen.dart';
import 'screens/weather_screen.dart';
import 'screens/compass_screen.dart';
import './screens/gaming_hub_screen.dart';
import 'screens/advertisement_screen.dart';
import 'screens/battery_saver_screen.dart';
import 'screens/permission_screen.dart';
import 'screens/register_screen.dart';
import 'screens/reset_password_screen.dart';
import 'screens/mode_selection_screen.dart';
import 'screens/my_statuses_screen.dart';
import 'screens/status_viewer_screen.dart';
import 'screens/join_group_screen.dart';
import 'screens/offline_chat_screen.dart';
import 'screens/user_search_screen.dart';
import 'screens/file_manager_screen.dart';
import 'screens/cosmic_animation_screen.dart';
import 'screens/music_player_screen.dart';
import 'screens/auto_tracker_screen.dart';
import 'screens/qr_scanner_screen.dart';
import 'screens/app_cloner_hub_screen.dart';
import 'screens/rust_security_hub_screen.dart';
import 'screens/admin_dashboard_screen.dart';
import 'screens/media_downloader_screen.dart';
import 'services/auth_service.dart';
import 'services/offline_service.dart';
import 'services/firebase_service.dart';
import 'widgets/global_incoming_call_overlay.dart';
import 'providers/locale_provider.dart';
import 'l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'providers/animation_provider.dart';
import 'screens/animation_store_screen.dart';
import 'screens/scifi_animations/terminator_screen.dart';
import 'screens/scifi_animations/iron_man_screen.dart';
import 'screens/scifi_animations/matrix_screen.dart';
import 'screens/scifi_animations/lightsaber_screen.dart';
import 'screens/scifi_animations/xenomorph_screen.dart';
import 'screens/scifi_animations/predator_screen.dart';
import 'screens/scifi_animations/optimus_screen.dart';
import 'screens/scifi_animations/tron_screen.dart';
import 'screens/scifi_animations/sandworm_screen.dart';
import 'screens/scifi_animations/wormhole_screen.dart';
import 'screens/scifi_animations/avatar_screen.dart';
import 'screens/scifi_animations/robocop_screen.dart';
import 'screens/scifi_animations/mandalorian_screen.dart';
import 'screens/scifi_animations/groot_screen.dart';
import 'screens/scifi_animations/exosuit_screen.dart';
import 'screens/scifi_animations/mad_max_screen.dart';
import 'screens/scifi_animations/multipass_screen.dart';
import 'screens/scifi_animations/blade_runner_screen.dart';
import 'screens/scifi_animations/district9_screen.dart';
import 'screens/scifi_animations/tesseract_screen.dart';
import 'screens/scifi_animations/warship_beam_screen.dart';
import 'screens/scifi_animations/shooting_stars_screen.dart';
import 'screens/scifi_animations/alien_invasion_screen.dart';
import 'screens/scifi_animations/cosmic_zoom_screen.dart';
import 'screens/scifi_animations/space_battle_screen.dart';
import 'screens/about_developers_screen.dart';
import 'screens/cyber_starfighter_3d_game.dart';
import 'services/user_leveling_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (FlutterErrorDetails details) {
    debugPrint('Flutter Error: ${details.exception}');
    debugPrintStack(stackTrace: details.stack);
  };

  await _initializeApp();
  runApp(const NexApp());
}

Future<void> _initializeApp() async {
  // Disable background sync scheduling for now because the current Workmanager
  // callback setup is crashing the app during startup on this device.
  // The app can still run normally without it while debugging the screens.
  try {
    debugPrint('Background sync scheduling disabled for debugging.');
  } catch (e) {
    debugPrint('Background sync disabled error: $e');
  }

  // Initialize Hive for offline storage
  try {
    final appDocDir = await getApplicationDocumentsDirectory();
    await Hive.initFlutter(appDocDir.path);
    await Hive.openBox('messages');
    try {
      await OfflineService().init();
    } catch (e) {
      debugPrint('OfflineService init error: $e');
    }
  } catch (e) {
    debugPrint('Hive initialization error: $e');
  }

  try {
    await FirebaseService.initialize();
  } catch (e) {
    debugPrint('Firebase initialization error: $e');
  }
}

// Top-level callback for Workmanager. Must be a top-level function.
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      // Ensure Hive is initialized in background isolate
      final appDocDir = await getApplicationDocumentsDirectory();
      await Hive.initFlutter(appDocDir.path);
      await Hive.openBox('messages');
      await OfflineService().init();
      await OfflineService().retryFailed();
    } catch (e) {
      debugPrint('Background sync failed: $e');
    }
    return Future.value(true);
  });
}

class NexApp extends StatelessWidget {
  const NexApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => TokenProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => LocaleProvider()),
        ChangeNotifierProvider(create: (_) => AnimationProvider()),
        ChangeNotifierProvider.value(value: UserLevelingService.instance),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          // Use system theme by default; provider can override to 'light' or 'dark'
          ThemeMode mode = ThemeMode.system;
          if (themeProvider.themeModePref == 'light') mode = ThemeMode.light;
          if (themeProvider.themeModePref == 'dark') mode = ThemeMode.dark;

          return MaterialApp(
            title: 'NEXDROID',
            debugShowCheckedModeBanner: false,
            theme: themeProvider.getLightThemeData(),
            darkTheme: themeProvider.getDarkThemeData(),
            themeMode: mode,
            locale: Provider.of<LocaleProvider>(context).locale,
            supportedLocales: LocaleProvider.supportedLocales,
            localizationsDelegates: const [
              AppLocalizationsDelegate(),
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            localeResolutionCallback: (locale, supportedLocales) {
              if (locale == null) return supportedLocales.first;
              for (var supportedLocale in supportedLocales) {
                if (supportedLocale.languageCode == locale.languageCode) {
                  return supportedLocale;
                }
              }
              return supportedLocales.first;
            },
            builder: (context, child) => GlobalIncomingCallOverlay(child: child ?? const SizedBox.shrink()),
            home: const SplashScreen(),
            routes: {
              LoginScreen.routeName: (_) => const LoginScreen(),
              HomeScreen.routeName: (_) => const HomeScreen(),
              ConversationsListScreen.routeName: (_) => const ConversationsListScreen(),
              AIChatScreen.routeName: (_) => const AIChatScreen(),
              ChatScreen.routeName: (_) => const ChatScreen(),
              BettingScreen.routeName: (_) => const BettingScreen(),
              MarketplaceScreen.routeName: (_) => const MarketplaceScreen(),
              ProfileScreen.routeName: (_) => const ProfileScreen(),
              ContactInfoScreen.routeName: (_) => const ContactInfoScreen(name: 'Contact Info'),
              GroupInfoScreen.routeName: (_) => const GroupInfoScreen(conversationId: 'default', groupName: 'Group Info'),
              SettingsScreen.routeName: (_) => const SettingsScreen(),
              GroupChatScreen.routeName: (_) => const GroupChatScreen(),
              CallsScreen.routeName: (_) => const CallsScreen(),
              AnnouncementsScreen.routeName: (_) => const AnnouncementsScreen(),
              TerminalScreen.routeName: (_) => const TerminalScreen(),
              VideoFeedScreen.routeName: (_) => const VideoFeedScreen(),
              WeatherScreen.routeName: (_) => const WeatherScreen(),
              CompassScreen.routeName: (_) => const CompassScreen(),
              VideoPostScreen.routeName: (_) => const VideoPostScreen(),
              GamingHubScreen.routeName: (_) => const GamingHubScreen(),
              AdvertisementScreen.routeName: (_) => const AdvertisementScreen(),
              BatterySaverScreen.routeName: (_) => const BatterySaverScreen(),
              PermissionScreen.routeName: (_) => const PermissionScreen(),
              RegisterScreen.routeName: (_) => const RegisterScreen(),
              ModeSelectionScreen.routeName: (_) => const ModeSelectionScreen(),
              ResetPasswordScreen.routeName: (_) => const ResetPasswordScreen(),
              MyStatusesScreen.routeName: (_) => const MyStatusesScreen(),
              StatusViewerScreen.routeName: (_) => const StatusViewerScreen(),
              JoinGroupScreen.routeName: (_) => const JoinGroupScreen(),
              OfflineChatScreen.routeName: (_) => const OfflineChatScreen(),
              UserSearchScreen.routeName: (_) => const UserSearchScreen(),
              FileManagerScreen.routeName: (_) => const FileManagerScreen(),
              CosmicLoginAnimationScreen.routeName: (_) => const CosmicLoginAnimationScreen(),
              MusicPlayerScreen.routeName: (_) => const MusicPlayerScreen(),
              QrScannerScreen.routeName: (_) => const QrScannerScreen(),
              AppClonerHubScreen.routeName: (_) => const AppClonerHubScreen(),
              RustSecurityHubScreen.routeName: (_) => const RustSecurityHubScreen(),
              AdminDashboardScreen.routeName: (_) => const AdminDashboardScreen(),
              MediaDownloaderScreen.routeName: (_) => const MediaDownloaderScreen(),
              AnimationStoreScreen.routeName: (_) => const AnimationStoreScreen(),
              AutoTrackerScreen.routeName: (_) => const AutoTrackerScreen(),
              TerminatorScreen.routeName: (_) => const TerminatorScreen(),
              IronManScreen.routeName: (_) => const IronManScreen(),
              MatrixScreen.routeName: (_) => const MatrixScreen(),
              LightsaberScreen.routeName: (_) => const LightsaberScreen(),
              XenomorphScreen.routeName: (_) => const XenomorphScreen(),
              PredatorScreen.routeName: (_) => const PredatorScreen(),
              OptimusScreen.routeName: (_) => const OptimusScreen(),
              TronScreen.routeName: (_) => const TronScreen(),
              SandwormScreen.routeName: (_) => const SandwormScreen(),
              WormholeScreen.routeName: (_) => const WormholeScreen(),
              AvatarBansheeScreen.routeName: (_) => const AvatarBansheeScreen(),
              RobocopScreen.routeName: (_) => const RobocopScreen(),
              MandalorianScreen.routeName: (_) => const MandalorianScreen(),
              GrootScreen.routeName: (_) => const GrootScreen(),
              ExosuitScreen.routeName: (_) => const ExosuitScreen(),
              MadMaxScreen.routeName: (_) => const MadMaxScreen(),
              MultipassScreen.routeName: (_) => const MultipassScreen(),
              BladeRunnerScreen.routeName: (_) => const BladeRunnerScreen(),
              District9Screen.routeName: (_) => const District9Screen(),
              TesseractScreen.routeName: (_) => const TesseractScreen(),
              WarshipBeamScreen.routeName: (_) => const WarshipBeamScreen(),
              ShootingStarsScreen.routeName: (_) => const ShootingStarsScreen(),
              AlienInvasionScreen.routeName: (_) => const AlienInvasionScreen(),
              CosmicZoomScreen.routeName: (_) => const CosmicZoomScreen(),
              SpaceBattleScreen.routeName: (_) => const SpaceBattleScreen(),
              AboutDevelopersScreen.routeName: (_) => const AboutDevelopersScreen(),
              CyberStarfighter3DGame.routeName: (_) => const CyberStarfighter3DGame(),
            },
          );
        },
      ),
    );
  }
}
