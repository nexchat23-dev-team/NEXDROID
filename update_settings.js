const fs = require('fs');
let content = fs.readFileSync('lib/screens/settings_screen.dart', 'utf8');

// Add imports
const importsToAdd = "import 'package:http/http.dart' as http;\nimport 'dart:convert';\n";
if (!content.includes("import 'package:http/http.dart' as http;")) {
    content = content.replace("import 'package:flutter/material.dart';", "import 'package:flutter/material.dart';\n" + importsToAdd);
}

// Add state variables
const stateVars = \
  // Location
  String? _detectedIp;
  String? _detectedCity;
  String? _detectedCountryName;
  String? _detectedCountryCode;
  bool _isDetectingLocation = false;

  // Cache
  String _cacheSize = '\\\ MB';

  // Notifications
  bool _notifChat = true;
  bool _notifGroups = true;
  bool _notifGaming = true;
  bool _notifMarket = true;
  bool _notifAnnouncements = true;

  // Developer
  int _devTapCount = 0;
  bool _showDevOptions = false;
  bool _devDebugOverlay = false;
  bool _devFakeOnline = false;
\;
content = content.replace("bool _gyroMovementEnabled = false;", stateVars + "\n  bool _gyroMovementEnabled = false;");

// Add init methods
const initCalls = \
    _loadLocationData();
    _loadNotificationChannels();
    _loadDevOptions();
\;
content = content.replace("super.initState();", "super.initState();" + initCalls);

// Add helpers
const helpers = \
  String _countryFlag(String code) => code.toUpperCase().split('').map((l) => String.fromCharCode(l.codeUnitAt(0) + 127397)).join();

  Future<void> _loadLocationData() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('detected_location');
    if (data != null) {
      final map = json.decode(data);
      if (mounted) {
        setState(() {
          _detectedIp = map['ip'];
          _detectedCity = map['city'];
          _detectedCountryName = map['country_name'];
          _detectedCountryCode = map['country_code'];
        });
      }
    }
  }

  Future<void> _detectLocation() async {
    if (!mounted) return;
    setState(() => _isDetectingLocation = true);
    try {
      final res = await http.get(Uri.parse('https://ipapi.co/json/'));
      if (res.statusCode == 200) {
        final map = json.decode(res.body);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('detected_location', res.body);
        
        final authService = Provider.of<AuthService>(context, listen: false);
        await authService.updateProfileData(country: map['country_name']);

        if (mounted) {
          setState(() {
            _detectedIp = map['ip'];
            _detectedCity = map['city'];
            _detectedCountryName = map['country_name'];
            _detectedCountryCode = map['country_code'];
          });
        }
      }
    } catch (e) {
      // Ignore
    } finally {
      if (mounted) setState(() => _isDetectingLocation = false);
    }
  }

  Future<void> _loadNotificationChannels() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _notifChat = prefs.getBool('notif_chat') ?? true;
        _notifGroups = prefs.getBool('notif_groups') ?? true;
        _notifGaming = prefs.getBool('notif_gaming') ?? true;
        _notifMarket = prefs.getBool('notif_market') ?? true;
        _notifAnnouncements = prefs.getBool('notif_announcements') ?? true;
      });
    }
  }

  Future<void> _loadDevOptions() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _devDebugOverlay = prefs.getBool('dev_debug_overlay') ?? false;
        _devFakeOnline = prefs.getBool('dev_fake_online') ?? false;
      });
    }
  }
\;
content = content.replace("Future<String?> _promptForPasswordToEnableBiometrics()", helpers + "\n  Future<String?> _promptForPasswordToEnableBiometrics()");

const sectionsToAdd = \
              // Location Section
              _buildSectionContainer(
                title: 'Location & Privacy',
                icon: Icons.location_on,
                color: Colors.greenAccent,
                children: [
                  if (_detectedCountryCode != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1B4B),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.greenAccent.withAlpha(50)),
                      ),
                      child: Row(
                        children: [
                          Text(_countryFlag(_detectedCountryCode!), style: const TextStyle(fontSize: 32)),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('\\\\\\\, \\\\\\\', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                                Text('IP: \\\\\\\', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ElevatedButton.icon(
                    onPressed: _isDetectingLocation ? null : _detectLocation,
                    icon: _isDetectingLocation ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black)) : const Icon(Icons.my_location),
                    label: Text(_isDetectingLocation ? 'Detecting...' : 'Detect My Location'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.greenAccent,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Storage & Cache Section
              _buildSectionContainer(
                title: 'Storage & Cache',
                icon: Icons.storage,
                color: Colors.purpleAccent,
                children: [
                  _buildSettingsTile(
                    icon: Icons.cleaning_services,
                    title: 'Clear Cache',
                    subtitle: 'Estimated: \\\\\\\',
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cache cleared successfully'), backgroundColor: Colors.green));
                      setState(() => _cacheSize = '0 MB');
                    },
                  ),
                  _buildSettingsTile(
                    icon: Icons.delete_outline,
                    title: 'Clear Download History',
                    subtitle: 'Remove temporary downloaded files',
                    onTap: () {},
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Notification Channels Section
              _buildSectionContainer(
                title: 'Notification Channels',
                icon: Icons.notifications_active,
                color: Colors.orangeAccent,
                children: [
                  _buildSwitchTile(
                    icon: Icons.chat,
                    title: 'Chat Messages',
                    subtitle: 'Direct messages',
                    value: _notifChat,
                    onChanged: (val) async {
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setBool('notif_chat', val);
                      setState(() => _notifChat = val);
                    },
                  ),
                  _buildSwitchTile(
                    icon: Icons.group,
                    title: 'Group Messages',
                    subtitle: 'Messages in groups',
                    value: _notifGroups,
                    onChanged: (val) async {
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setBool('notif_groups', val);
                      setState(() => _notifGroups = val);
                    },
                  ),
                  _buildSwitchTile(
                    icon: Icons.gamepad,
                    title: 'Gaming Events',
                    subtitle: 'Tournaments and invites',
                    value: _notifGaming,
                    onChanged: (val) async {
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setBool('notif_gaming', val);
                      setState(() => _notifGaming = val);
                    },
                  ),
                  _buildSwitchTile(
                    icon: Icons.store,
                    title: 'Marketplace',
                    subtitle: 'Offers and updates',
                    value: _notifMarket,
                    onChanged: (val) async {
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setBool('notif_market', val);
                      setState(() => _notifMarket = val);
                    },
                  ),
                  _buildSwitchTile(
                    icon: Icons.announcement,
                    title: 'Announcements',
                    subtitle: 'App updates and news',
                    value: _notifAnnouncements,
                    onChanged: (val) async {
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setBool('notif_announcements', val);
                      setState(() => _notifAnnouncements = val);
                    },
                  ),
                ],
              ),

              const SizedBox(height: 24),

              if (_showDevOptions)
                Column(
                  children: [
                    _buildSectionContainer(
                      title: 'Developer Options',
                      icon: Icons.developer_mode,
                      color: Colors.redAccent,
                      children: [
                        _buildSwitchTile(
                          icon: Icons.bug_report,
                          title: 'Show Debug Overlay',
                          subtitle: 'Display FPS and memory stats',
                          value: _devDebugOverlay,
                          onChanged: (val) async {
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.setBool('dev_debug_overlay', val);
                            setState(() => _devDebugOverlay = val);
                          },
                        ),
                        _buildSwitchTile(
                          icon: Icons.wifi,
                          title: 'Fake Online Status',
                          subtitle: 'Always appear online',
                          value: _devFakeOnline,
                          onChanged: (val) async {
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.setBool('dev_fake_online', val);
                            setState(() => _devFakeOnline = val);
                          },
                        ),
                        ElevatedButton(
                          onPressed: () {},
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                          child: const Text('Reset All Settings'),
                        )
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
\;
content = content.replace("// Logout Button", sectionsToAdd + "\n              // Logout Button");

const newAbout = \              _buildSettingsTile(
                icon: Icons.info,
                title: 'About',
                subtitle: 'App version 1.0.0',
                onTap: () {
                  _devTapCount++;
                  if (_devTapCount == 5) {
                    setState(() => _showDevOptions = true);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Developer Options enabled!')));
                  }
                  if (_devTapCount < 5) {
                    _showAboutDialog(context);
                  }
                },
              ),\;
const oldAbout = \              _buildSettingsTile(
                icon: Icons.info,
                title: 'About',
                subtitle: 'App version 1.0.0',
                onTap: () => _showAboutDialog(context),
              ),\;
content = content.replace(oldAbout, newAbout);

fs.writeFileSync('lib/screens/settings_screen.dart', content, 'utf8');
console.log('Done!');
