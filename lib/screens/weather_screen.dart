import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../utils/constants.dart';

class WeatherScreen extends StatefulWidget {
  static const routeName = '/weather';
  const WeatherScreen({super.key});

  @override
  State<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen> with TickerProviderStateMixin {
  bool _isLoading = false;
  bool _isDaytime = true;
  String _city = 'NEXO-TECH_STATE';
  String _condition = 'Sunny';
  int _temperature = 24;
  int _humidity = 52;
  double _wind = 8.26;
  String _visibility = '10 km';
  String _uv = '6 (High)';
  int _aqi = 42;
  
  bool _searchExpanded = false;
  final TextEditingController _cityController = TextEditingController();

  late AnimationController _refreshController;
  late AnimationController _skyController;
  late AnimationController _particlesController;
  
  final List<Map<String, dynamic>> _hourlyForecast = [];
  final List<Map<String, dynamic>> _weeklyForecast = [];

  @override
  void initState() {
    super.initState();
    _refreshController = AnimationController(vsync: this, duration: const Duration(seconds: 1));
    _skyController = AnimationController(vsync: this, duration: const Duration(seconds: 20))..repeat();
    _particlesController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
    
    _loadCurrentWeather();
  }

  @override
  void dispose() {
    _refreshController.dispose();
    _skyController.dispose();
    _particlesController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    _refreshController.repeat();
    await _generateData(_city);
    _refreshController.stop();
    _refreshController.reset();
  }

  Future<void> _loadCurrentWeather() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw Exception('Location services are disabled');
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception('Location permission was not granted');
      }
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );
      await _generateData(
        'Current location',
        latitude: position.latitude,
        longitude: position.longitude,
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Using city search: $error')),
      );
      await _generateData(_city);
    }
  }

  Future<void> _generateData(
    String city, {
    double? latitude,
    double? longitude,
  }) async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final requestedCity = city.trim().isEmpty ? 'NEX City' : city.trim();
      Map<String, dynamic> location;
      var resolvedLatitude = latitude;
      var resolvedLongitude = longitude;
      if (resolvedLatitude == null || resolvedLongitude == null) {
        final locationResponse = await http.get(Uri.https(
          'geocoding-api.open-meteo.com',
          '/v1/search',
          {'name': requestedCity, 'count': '1', 'language': 'en', 'format': 'json'},
        )).timeout(const Duration(seconds: 12));
        final locations = (jsonDecode(locationResponse.body)['results'] as List<dynamic>?) ?? [];
        if (locationResponse.statusCode != 200 || locations.isEmpty) {
          throw Exception('City not found');
        }
        location = Map<String, dynamic>.from(locations.first as Map);
        resolvedLatitude = (location['latitude'] as num).toDouble();
        resolvedLongitude = (location['longitude'] as num).toDouble();
      } else {
        location = {'name': requestedCity};
      }

      final forecastResponse = await http.get(Uri.https(
        'api.open-meteo.com',
        '/v1/forecast',
        {
          'latitude': '$resolvedLatitude',
          'longitude': '$resolvedLongitude',
          'current': 'temperature_2m,relative_humidity_2m,wind_speed_10m,weather_code,visibility,uv_index',
          'hourly': 'temperature_2m,weather_code',
          'daily': 'weather_code,temperature_2m_min,temperature_2m_max,sunrise,sunset',
          'forecast_days': '7',
          'timezone': 'auto',
        },
      )).timeout(const Duration(seconds: 12));
      final forecast = jsonDecode(forecastResponse.body) as Map<String, dynamic>;
      if (forecastResponse.statusCode != 200) throw Exception('Weather service unavailable');

      final current = Map<String, dynamic>.from(forecast['current'] as Map);
      final hourly = Map<String, dynamic>.from(forecast['hourly'] as Map);
      final daily = Map<String, dynamic>.from(forecast['daily'] as Map);
      final currentTime = DateTime.tryParse(current['time']?.toString() ?? '') ?? DateTime.now();
      final sunrise = DateTime.tryParse((daily['sunrise'] as List).first.toString());
      final sunset = DateTime.tryParse((daily['sunset'] as List).first.toString());
      final isDaytime = sunrise != null && sunset != null
          ? currentTime.isAfter(sunrise) && currentTime.isBefore(sunset)
          : currentTime.hour >= 6 && currentTime.hour < 19;

      final hourlyTimes = (hourly['time'] as List<dynamic>);
      final hourlyTemps = (hourly['temperature_2m'] as List<dynamic>);
      final hourlyCodes = (hourly['weather_code'] as List<dynamic>);
      final hourlyStart = hourlyTimes.indexWhere((value) => value.toString() == current['time']?.toString());
      final startIndex = hourlyStart < 0 ? 0 : hourlyStart;
      final nextHours = <Map<String, dynamic>>[];
      for (var i = startIndex; i < (startIndex + 8).clamp(0, hourlyTimes.length); i++) {
        final time = DateTime.tryParse(hourlyTimes[i].toString());
        nextHours.add({
          'time': time == null ? '--:--' : '${time.hour.toString().padLeft(2, '0')}:00',
          'temp': (hourlyTemps[i] as num).round(),
          'icon': _getIconForWeatherCode((hourlyCodes[i] as num).toInt()),
        });
      }

      final airResponse = await http.get(Uri.https(
        'air-quality-api.open-meteo.com',
        '/v1/air-quality',
        {'latitude': '$resolvedLatitude', 'longitude': '$resolvedLongitude', 'current': 'us_aqi'},
      )).timeout(const Duration(seconds: 12));
      var aqi = 0;
      if (airResponse.statusCode == 200) {
        final air = jsonDecode(airResponse.body) as Map<String, dynamic>;
        aqi = ((air['current'] as Map<String, dynamic>?)?['us_aqi'] as num?)?.round() ?? 0;
      }

      final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      final dailyCodes = daily['weather_code'] as List<dynamic>;
      final dailyMin = daily['temperature_2m_min'] as List<dynamic>;
      final dailyMax = daily['temperature_2m_max'] as List<dynamic>;
      final nextDays = <Map<String, dynamic>>[];
      for (var i = 0; i < dailyCodes.length; i++) {
        final day = DateTime.tryParse((daily['time'] as List<dynamic>)[i].toString());
        nextDays.add({
          'day': i == 0 ? 'Today' : (day == null ? '--' : days[day.weekday - 1]),
          'min': (dailyMin[i] as num).round(),
          'max': (dailyMax[i] as num).round(),
          'icon': _getIconForWeatherCode((dailyCodes[i] as num).toInt()),
        });
      }

      if (!mounted) return;
      setState(() {
        _city = location['name']?.toString() ?? requestedCity;
        _isDaytime = isDaytime;
        _condition = _conditionForWeatherCode((current['weather_code'] as num).toInt());
        _temperature = (current['temperature_2m'] as num).round();
        _humidity = (current['relative_humidity_2m'] as num).round();
        _wind = (current['wind_speed_10m'] as num).toDouble();
        _visibility = '${((current['visibility'] as num?)?.toDouble() ?? 0) / 1000} km';
        final uv = (current['uv_index'] as num?)?.toDouble() ?? 0;
        _uv = '${uv.toStringAsFixed(1)} (${uv < 3 ? 'Low' : uv < 6 ? 'Moderate' : 'High'})';
        _aqi = aqi;
        _hourlyForecast
          ..clear()
          ..addAll(nextHours);
        _weeklyForecast
          ..clear()
          ..addAll(nextDays);
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Weather could not be loaded: $error')),
      );
    }
  }

  String _conditionForWeatherCode(int code) {
    if (code == 0) return 'Sunny';
    if (code <= 3) return 'Cloudy';
    if (code <= 67 || (code >= 80 && code <= 82)) return 'Rainy';
    if (code >= 71 && code <= 77) return 'Snowy';
    if (code >= 95) return 'Stormy';
    return 'Cloudy';
  }

  IconData _getIconForWeatherCode(int code) {
    switch (_conditionForWeatherCode(code)) {
      case 'Sunny': return Icons.wb_sunny;
      case 'Rainy': return Icons.water_drop;
      case 'Snowy': return Icons.ac_unit;
      case 'Stormy': return Icons.flash_on;
      default: return Icons.cloud;
    }
  }
  
  IconData _getIconForCondition(String condition) {
    switch (condition) {
      case 'Sunny': return Icons.wb_sunny;
      case 'Clear': return Icons.nightlight_round;
      case 'Cloudy': return Icons.cloud;
      case 'Rainy': return Icons.water_drop;
      case 'Stormy': return Icons.flash_on;
      case 'Snowy': return Icons.ac_unit;
      default: return Icons.wb_cloudy;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Animated Background
          AnimatedBuilder(
            animation: _skyController,
            builder: (context, child) {
              return CustomPaint(
                painter: SkyPainter(
                  isDaytime: _isDaytime,
                  animationValue: _skyController.value,
                  condition: _condition,
                ),
                size: Size.infinite,
              );
            },
          ),
          
          if (_condition == 'Rainy' || _condition == 'Snowy' || _condition == 'Stormy')
            AnimatedBuilder(
              animation: _particlesController,
              builder: (context, child) {
                return CustomPaint(
                  painter: ParticlePainter(
                    isSnow: _condition == 'Snowy',
                    animationValue: _particlesController.value,
                  ),
                  size: Size.infinite,
                );
              },
            ),

          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _refresh,
                    color: kNeonBlue,
                    backgroundColor: kDarkBackground,
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      children: [
                        _buildMainCard(),
                        const SizedBox(height: 24),
                        _buildHourlyForecast(),
                        const SizedBox(height: 24),
                        _buildInfoGrid(),
                        const SizedBox(height: 24),
                        _buildAQIBar(),
                        const SizedBox(height: 24),
                        _buildWeeklyForecast(),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: _searchExpanded ? 0.2 : 0.0),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Colors.white.withValues(alpha: _searchExpanded ? 0.3 : 0.0),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _searchExpanded
                        ? TextField(
                            controller: _cityController,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(
                              hintText: 'Search city...',
                              hintStyle: TextStyle(color: Colors.white60),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                            onSubmitted: (val) {
                              _generateData(val);
                              setState(() => _searchExpanded = false);
                            },
                          )
                        : const SizedBox(),
                  ),
                  IconButton(
                    icon: Icon(_searchExpanded ? Icons.close : Icons.search, color: Colors.white),
                    onPressed: () {
                      setState(() {
                        if (_searchExpanded) {
                          _searchExpanded = false;
                          _cityController.clear();
                        } else {
                          _searchExpanded = true;
                        }
                      });
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          RotationTransition(
            turns: _refreshController,
            child: IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: _isLoading ? null : _refresh,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            children: [
              Text(
                _city,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Updated just now',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    _getIconForCondition(_condition),
                    color: _isDaytime ? Colors.yellow : Colors.blue.shade200,
                    size: 64,
                  ),
                  const SizedBox(width: 16),
                  Text(
                    '$_temperature°',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 72,
                      fontWeight: FontWeight.w900,
                      height: 1.0,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                _condition,
                style: const TextStyle(
                  color: kNeonBlue,
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Feels like ${_temperature + 2}°',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHourlyForecast() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Today',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _hourlyForecast.length,
            itemBuilder: (context, index) {
              final data = _hourlyForecast[index];
              return Container(
                width: 70,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      data['time'],
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    Icon(data['icon'], color: Colors.white, size: 28),
                    const SizedBox(height: 8),
                    Text(
                      '${data['temp']}°',
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildInfoGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 1.5,
      children: [
        _buildInfoCard('Wind', '${_wind.toStringAsFixed(1)} km/h', Icons.air),
        _buildInfoCard('Humidity', '$_humidity%', Icons.water_drop_outlined),
        _buildInfoCard('UV Index', _uv, Icons.wb_sunny_outlined),
        _buildInfoCard('Visibility', _visibility, Icons.visibility_outlined),
      ],
    );
  }

  Widget _buildInfoCard(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.white54, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(color: Colors.white54, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildAQIBar() {
    Color aqiColor = _aqi < 50 ? kNeonGreen : _aqi < 100 ? Colors.yellow : Colors.orange;
    String aqiText = _aqi < 50 ? 'Good' : _aqi < 100 ? 'Moderate' : 'Unhealthy';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Air Quality', style: TextStyle(color: Colors.white70, fontSize: 16)),
              Text(
                '$_aqi AQI - $aqiText',
                style: TextStyle(color: aqiColor, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: _aqi / 200,
              backgroundColor: Colors.white.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation<Color>(aqiColor),
              minHeight: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyForecast() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '7-Day Forecast',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          ..._weeklyForecast.map((data) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SizedBox(
                    width: 50,
                    child: Text(
                      data['day'],
                      style: const TextStyle(color: Colors.white70, fontSize: 16),
                    ),
                  ),
                  Icon(data['icon'], color: Colors.white, size: 24),
                  Row(
                    children: [
                      Text(
                        '${data['min']}°',
                        style: const TextStyle(color: Colors.white54, fontSize: 16),
                      ),
                      const SizedBox(width: 16),
                      SizedBox(
                        width: 30,
                        child: Text(
                          '${data['max']}°',
                          textAlign: TextAlign.right,
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class SkyPainter extends CustomPainter {
  final bool isDaytime;
  final double animationValue;
  final String condition;

  SkyPainter({required this.isDaytime, required this.animationValue, required this.condition});

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;

    Color topColor = isDaytime ? const Color(0xFF0A2E65) : const Color(0xFF040B16);
    Color bottomColor = isDaytime ? const Color(0xFFD47C39) : const Color(0xFF1B0B3B);

    if (condition == 'Rainy' || condition == 'Stormy') {
      topColor = const Color(0xFF1E2836);
      bottomColor = const Color(0xFF0E141E);
    }

    final Gradient gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [topColor, bottomColor],
      stops: const [0.2, 1.0],
    );

    canvas.drawRect(
      rect,
      Paint()..shader = gradient.createShader(rect),
    );

    // Draw Sun or Moon
    final Paint glowPaint = Paint()
      ..color = isDaytime ? Colors.orange.withValues(alpha: 0.3) : Colors.blue.withValues(alpha: 0.2)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 60);

    final Paint bodyPaint = Paint()
      ..color = isDaytime ? Colors.yellow : Colors.white;

    final Offset center = Offset(size.width * 0.8, size.height * 0.2 + sin(animationValue * pi * 2) * 20);

    canvas.drawCircle(center, 60, glowPaint);
    canvas.drawCircle(center, 30, bodyPaint);

    // Draw Clouds
    if (condition != 'Clear') {
      final Paint cloudPaint = Paint()
        ..color = Colors.white.withValues(alpha: condition == 'Cloudy' ? 0.3 : 0.1)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20);
      
      double cloudX1 = size.width * (animationValue);
      double cloudX2 = size.width * (1 - animationValue);

      canvas.drawCircle(Offset(cloudX1, size.height * 0.15), 50, cloudPaint);
      canvas.drawCircle(Offset(cloudX1 + 40, size.height * 0.15), 70, cloudPaint);
      
      canvas.drawCircle(Offset(cloudX2, size.height * 0.25), 60, cloudPaint);
      canvas.drawCircle(Offset(cloudX2 - 50, size.height * 0.28), 40, cloudPaint);
    }
  }

  @override
  bool shouldRepaint(covariant SkyPainter oldDelegate) => true;
}

class ParticlePainter extends CustomPainter {
  final bool isSnow;
  final double animationValue;

  ParticlePainter({required this.isSnow, required this.animationValue});

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = isSnow ? Colors.white : Colors.blue.withValues(alpha: 0.5)
      ..strokeWidth = isSnow ? 3 : 2
      ..strokeCap = StrokeCap.round;

    final random = Random(42); 

    for (int i = 0; i < 100; i++) {
      double x = random.nextDouble() * size.width;
      double yOffset = random.nextDouble() * size.height;
      
      double y = (yOffset + (animationValue * size.height)) % size.height;
      
      if (isSnow) {
        canvas.drawCircle(Offset(x, y), random.nextDouble() * 2 + 1, paint);
      } else {
        canvas.drawLine(Offset(x, y), Offset(x - 2, y + 10), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant ParticlePainter oldDelegate) => true;
}
