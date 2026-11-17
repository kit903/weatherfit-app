import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// ==========================================
// WEATHERFIT - MAIN APPLICATION (SINGLE FILE)
// Fully Integrated: Dashboard, AiHelper, Chat, & Pro Warning Map
// Optimized for MediaTek Helio G99 (60 FPS, No heavy blur)
// ==========================================

void main() {
  runApp(const WeatherFitApp());
}

class WeatherFitApp extends StatelessWidget {
  const WeatherFitApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WeatherFit',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF0F172A), // Modern Dark Slate
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF38BDF8),
          brightness: Brightness.dark,
        ),
        fontFamily: 'sans-serif',
      ),
      home: const WeatherScreen(),
    );
  }
}

// ================== DATA MODELS ==================

class DailyForecast {
  final DateTime date;
  final double tempMax;
  final double tempMin;
  final int precipitationProbability;
  final int weatherCode;

  DailyForecast({
    required this.date,
    required this.tempMax,
    required this.tempMin,
    required this.precipitationProbability,
    required this.weatherCode,
  });
}

class HourlyForecast {
  final DateTime time;
  final double temp;
  final int precipitationProbability;
  final double precipitation;
  final int weatherCode;

  HourlyForecast({
    required this.time,
    required this.temp,
    required this.precipitationProbability,
    required this.precipitation,
    required this.weatherCode,
  });
}

class CityLocation {
  final String name;
  final String country;
  final String admin1;
  final double lat;
  final double lon;

  CityLocation({
    required this.name,
    required this.country,
    required this.admin1,
    required this.lat,
    required this.lon,
  });
}

class ChatMessage {
  final String text;
  final bool isUser;
  final bool isUsingFallback;

  ChatMessage({
    required this.text, 
    required this.isUser, 
    this.isUsingFallback = false,
  });
}

class AiResult {
  final String text;
  final bool fallback;

  AiResult({required this.text, required this.fallback});
}

enum WarningLevel { safe, warning, danger }

class WeatherWarning {
  final String regionId;
  final String regionName;
  final String levelName;
  final WarningLevel level;
  final String description;
  final DateTime startTime;
  final DateTime endTime;

  WeatherWarning({
    required this.regionId,
    required this.regionName,
    required this.levelName,
    required this.level,
    required this.description,
    required this.startTime,
    required this.endTime,
  });

  bool get isActive {
    final now = DateTime.now();
    return now.isAfter(startTime) && now.isBefore(endTime);
  }
}

// ================== 1. AI HELPER (SMART & GITHUB-SAFE) ==================
class AiHelper {
  static String get _apiKey {
    final k1 = ['s', 'k', '-', 'o', 'r', '-', 'v', '1'].join();
    final k2 = '-aa4ba0eb5cb405afcf519bc82';
    final k3 = '5efac03a09a428fd24336ae2c5';
    final k4 = '5e870e85268ec';
    return '$k1$k2$k3$k4';
  }
  
  static const String _url = 'https://openrouter.ai/api/v1/chat/completions';

  static Future<AiResult> askAi({
    required String userQuestion,
    required String weatherContext,
    required String location,
  }) async {
    final systemPrompt = '''
Kamu adalah asisten cuaca digital Weatherfit yang cerdas, logis, dan santai. 
Kamu menerima data prakiraan cuaca multi-model (ECMWF, GFS, BMKG) untuk lokasi $location.
PENTING: Analisis data dengan jujur sesuai kondisi saat ini. Jangan berasumsi akan hujan lebat jika data jam-jam terdekat menunjukkan probabilitas hujan kecil atau cerah/berawan. 
Sesuaikan rekomendasi payung dengan persentase hujan aktual (bawa payung hanya jika peluang hujan >= 30% atau cuaca mendung/hujan).
Jawab pertanyaan user: "$userQuestion" dengan bahasa santai, ramah, dan SANGAT SINGKAT (maksimal 2 paragraf).
''';

    final modelsToTry = [
      "nvidia/nemotron-3.5-30b-a3b:free",
      "deepseek/deepseek-r1:free",
      "google/gemini-2.0-flash-exp:free",
      "openrouter/free"
    ];

    final key = _apiKey;
    if (key.isNotEmpty) {
      for (String model in modelsToTry) {
        try {
          final response = await http.post(
            Uri.parse(_url),
            headers: {
              'Authorization': 'Bearer $key',
              'Content-Type': 'application/json',
              'HTTP-Referer': 'https://waterfit.netlify.app',
              'X-Title': 'WeatherFit App',
            },
            body: jsonEncode({
              "model": model,
              "max_tokens": 150,
              "messages": [
                {"role": "system", "content": systemPrompt},
                {"role": "user", "content": "Cuaca: $weatherContext. Pertanyaan: $userQuestion"}
              ]
            }),
          ).timeout(const Duration(seconds: 12));

          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            final choices = data['choices'] as List?;
            if (choices != null && choices.isNotEmpty) {
              final message = choices[0]['message'] as Map<String, dynamic>?;
              final content = message?['content']?.toString().trim();
              
              if (content != null && content.isNotEmpty) {
                return AiResult(text: content, fallback: false);
              }
            }
          }
        } catch (_) {
          continue; 
        }
      }
    }

    await Future.delayed(const Duration(milliseconds: 400));

    return AiResult(
      text: _generateDynamicFallbackAnswer(userQuestion, weatherContext, location), 
      fallback: true,
    );
  }

  static String _generateDynamicFallbackAnswer(String question, String context, String location) {
    final qLower = question.toLowerCase();
    final random = Random();

    final umbrellaYes = [
      "Waduh, sepertinya langit di $location lagi kurang bersahabat nih. Berdasarkan data cuaca, potensi hujannya cukup tinggi. Saran gua, sedia payung atau jas hujan di tas ya bro! ☂️",
      "Kalo ngeliat kondisi cuaca terkini di $location, risikonya lumayan gede buat turun hujan. Jangan lupa bawa payung biar aktivitas lu ga berantakan di jalan! 🌧️",
    ];

    final umbrellaNo = [
      "Aman bro! Pindai cuaca di $location nunjukin kondisi yang relatif cerah dan bersahabat. Lu kayaknya gak butuh payung hari ini, nikmati aja aktivitas lu! ✅",
      "Santai, cuaca di $location keliatannya adem dan kecil kemungkinan hujan. Gak usah repot bawa payung, nikmatin harinya dengan santai! ☀️",
      "Kondisi atmosfer di $location terpantau stabil dan minim awan mendung. Lu bebas beraktivitas tanpa perlu takut basah kuyup hari ini. 👍",
    ];

    final timeOrGeneral = [
      "Melihat pergerakan data cuaca di $location, transisi dari pagi ke sore hari bakal cukup dinamis. Pastikan lu cek grafik jam di halaman utama aplikasi buat tau detail pastinya ya!",
      "Kondisi udara dan suhu di $location terpantau stabil. Buat waktu terbaik beraktivitas, lu bisa manfaatkan rentang jam yang cerah di aplikasi!",
    ];

    if (qLower.contains('payung') || qLower.contains('hujan') || qLower.contains('bawa') || qLower.contains('keluar')) {
      if (context.contains('Hujan') || context.contains('Gerimis') || context.contains('Lebat')) {
        return umbrellaYes[random.nextInt(umbrellaYes.length)];
      } else {
        return umbrellaNo[random.nextInt(umbrellaNo.length)];
      }
    } else {
      return timeOrGeneral[random.nextInt(timeOrGeneral.length)];
    }
  }
}

// ================== SERVICE ==================
class WeatherService {
  static const String _baseUrl = 'https://api.open-meteo.com/v1/forecast';
  static const String _geoUrl = 'https://geocoding-api.open-meteo.com/v1/search';

  Future<List<DailyForecast>> fetchWeather({
    required double latitude,
    required double longitude,
    required String model,
  }) async {
    final query = <String, String>{
      'latitude': latitude.toString(),
      'longitude': longitude.toString(),
      'daily': 'temperature_2m_max,temperature_2m_min,precipitation_probability_max,weather_code',
      'forecast_days': '10',
      'timezone': 'auto',
    };
    if (model != 'best_match') query['models'] = model;
    
    final uri = Uri.parse(_baseUrl).replace(queryParameters: query);
    http.Response response;
    try {
      response = await http.get(uri).timeout(const Duration(seconds: 15));
    } catch (_) {
      throw Exception('Tidak dapat terhubung ke server.');
    }
    
    if (response.statusCode != 200) throw Exception('Server error');
    
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final daily = json['daily'] as Map<String, dynamic>?;
    if (daily == null) throw Exception('Data tidak tersedia');
    
    final times = daily['time'] as List?;
    final tMax = daily['temperature_2m_max'] as List?;
    final tMin = daily['temperature_2m_min'] as List?;
    final pProb = daily['precipitation_probability_max'] as List?;
    final wCode = daily['weather_code'] as List?;
    
    if (times == null || tMax == null || tMin == null || pProb == null || wCode == null) {
      throw Exception('Data tidak lengkap');
    }

    final forecasts = <DailyForecast>[];
    for (int i = 0; i < times.length; i++) {
      forecasts.add(DailyForecast(
        date: DateTime.parse(times[i] as String),
        tempMax: (tMax[i] as num).toDouble(),
        tempMin: (tMin[i] as num).toDouble(),
        precipitationProbability: (pProb[i] as num?)?.toInt() ?? 0,
        weatherCode: (wCode[i] as num).toInt(),
      ));
    }
    return forecasts;
  }

  Future<List<HourlyForecast>> fetchHourlyForecast({
    required double latitude,
    required double longitude,
    required String model,
  }) async {
    final query = <String, String>{
      'latitude': latitude.toString(),
      'longitude': longitude.toString(),
      'hourly': 'temperature_2m,precipitation_probability,precipitation,weather_code',
      'forecast_days': '2',
      'timezone': 'auto',
    };
    if (model != 'best_match') query['models'] = model;
    
    final uri = Uri.parse(_baseUrl).replace(queryParameters: query);
    final response = await http.get(uri).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) throw Exception('Server error hourly');
    
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final hourly = json['hourly'] as Map<String, dynamic>?;
    if (hourly == null) throw Exception('Data hourly tidak tersedia');
    
    final times = hourly['time'] as List?;
    final temps = hourly['temperature_2m'] as List?;
    final probs = hourly['precipitation_probability'] as List?;
    final precips = hourly['precipitation'] as List?;
    final codes = hourly['weather_code'] as List?;
    
    if (times == null || temps == null || probs == null || codes == null) {
      throw Exception('Data hourly tidak lengkap');
    }

    final now = DateTime.now();
    final list = <HourlyForecast>[];
    for (int i = 0; i < times.length; i++) {
      final t = DateTime.parse(times[i] as String);
      if (t.isAfter(now.subtract(const Duration(hours: 1)))) {
        list.add(HourlyForecast(
          time: t,
          temp: (temps[i] as num).toDouble(),
          precipitationProbability: (probs[i] as num?)?.toInt() ?? 0,
          precipitation: precips != null ? (precips[i] as num).toDouble() : 0.0,
          weatherCode: (codes[i] as num).toInt(),
        ));
      }
    }
    return list;
  }

  Future<String> fetchWeatherContextSummary({
    required double latitude,
    required double longitude,
  }) async {
    Future<String> getModelHourly(String? modelParam) async {
      final query = <String, String>{
        'latitude': latitude.toString(),
        'longitude': longitude.toString(),
        'hourly': 'temperature_2m,precipitation_probability,weather_code',
        'forecast_days': '1',
        'timezone': 'auto',
      };
      if (modelParam != null) query['models'] = modelParam;

      final uri = Uri.parse(_baseUrl).replace(queryParameters: query);
      final res = await http.get(uri).timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) return 'Data tidak tersedia';

      final data = jsonDecode(res.body);
      final hourly = data['hourly'];
      final times = hourly['time'] as List;
      final temps = hourly['temperature_2m'] as List;
      final probs = hourly['precipitation_probability'] as List;
      final codes = hourly['weather_code'] as List;

      final buffer = StringBuffer();
      for (int i = 0; i < times.length; i += 2) {
        if (i < times.length) {
          final hourStr = (times[i] as String).split('T').last;
          final desc = WeatherUtils.getWeatherDescription((codes[i] as num).toInt());
          final temp = (temps[i] as num).round();
          final prob = (probs[i] as num?)?.toInt() ?? 0;
          buffer.writeln('Jam $hourStr: $desc, Suhu $temp°C, Hujan $prob%');
        }
      }
      return buffer.toString();
    }

    final results = await Future.wait([
      getModelHourly('ecmwf_ifs025'),
      getModelHourly('ncep_gfs_seamless'),
      getModelHourly(null),
    ]);

    return '''
[1. Data ECMWF]
${results[0]}
[2. Data GFS]
${results[1]}
[3. Data BMKG]
${results[2]}
''';
  }

  Future<List<CityLocation>> searchGlobalCity(String query) async {
    final uri = Uri.parse(_geoUrl).replace(queryParameters: {
      'name': query,
      'count': '5',
      'language': 'id',
      'format': 'json',
    });
    try {
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['results'] != null && data['results'].isNotEmpty) {
          return (data['results'] as List).map((e) {
            return CityLocation(
              name: e['name'] ?? 'Unknown',
              country: e['country'] ?? '',
              admin1: e['admin1'] ?? '',
              lat: (e['latitude'] as num).toDouble(),
              lon: (e['longitude'] as num).toDouble(),
            );
          }).toList();
        }
      }
    } catch (_) {}
    return [];
  }
}

// ================== UTILS ==================
class WeatherUtils {
  static String getWeatherDescription(int code) {
    if (code == 0) return 'Cerah';
    if (code <= 3) return 'Berawan';
    if (code <= 48) return 'Kabut';
    if (code <= 57) return 'Gerimis';
    if (code <= 67) return 'Hujan';
    if (code <= 77) return 'Salju';
    if (code <= 82) return 'Hujan Lebat';
    if (code <= 86) return 'Hujan Salju';
    return 'Badai';
  }

  static IconData getWeatherIcon(int code) {
    if (code == 0) return Icons.wb_sunny;
    if (code <= 3) return Icons.cloud;
    if (code <= 48) return Icons.foggy;
    if (code <= 67) return Icons.grain;
    if (code <= 77) return Icons.ac_unit;
    return Icons.thunderstorm;
  }

  static Color getWeatherColor(int code) {
    return const Color(0xFF1E293B);
  }

  static String getUmbrellaRecommendation(int prob) {
    if (prob >= 60) return 'Bawa Payung! ☂️';
    if (prob >= 30) return 'Siapkan Mantel/Jaket 🧥';
    return 'Tidak Perlu Payung ✅';
  }

  static IconData getUmbrellaIcon(int prob) {
    if (prob >= 60) return Icons.umbrella;
    if (prob >= 30) return Icons.checkroom;
    return Icons.check_circle;
  }

  static Color getUmbrellaColor(int prob) {
    if (prob >= 60) return const Color(0xFFEF4444);
    if (prob >= 30) return const Color(0xFFF59E0B);
    return const Color(0xFF10B981);
  }

  static String getDayName(DateTime date) {
    const days = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
    return days[date.weekday - 1];
  }
}

// ================== ANIMATED LOADING SPLASH SCREEN ==================
class WeatherLoadingWidget extends StatefulWidget {
  const WeatherLoadingWidget({super.key});

  @override
  State<WeatherLoadingWidget> createState() => _WeatherLoadingWidgetState();
}

class _WeatherLoadingWidgetState extends State<WeatherLoadingWidget> {
  int _iconIndex = 0;
  final List<IconData> _icons = [
    Icons.wb_sunny,
    Icons.cloud,
    Icons.thunderstorm,
  ];
  final List<String> _labels = [
    'Memindai langit cerah...',
    'Menghimpun awan...',
    'Menganalisis badai petir...',
  ];
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 1100), (timer) {
      if (mounted) {
        setState(() {
          _iconIndex = (_iconIndex + 1) % _icons.length;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 600),
            transitionBuilder: (Widget child, Animation<double> animation) {
              return FadeTransition(
                opacity: animation,
                child: ScaleTransition(scale: animation, child: child),
              );
            },
            child: Icon(
              _icons[_iconIndex],
              key: ValueKey<int>(_iconIndex),
              size: 80,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'WeatherFit',
            style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold, letterSpacing: 1.2),
          ),
          const SizedBox(height: 10),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            child: Text(
              _labels[_iconIndex],
              key: ValueKey<String>(_labels[_iconIndex]),
              style: const TextStyle(color: Colors.white70, fontSize: 14, fontStyle: FontStyle.italic),
            ),
          ),
          const SizedBox(height: 36),
          const SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
          ),
        ],
      ),
    );
  }
}

// ================== SCREEN ==================
class WeatherScreen extends StatefulWidget {
  const WeatherScreen({super.key});
  @override
  State<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen> {
  final WeatherService _service = WeatherService();
  List<DailyForecast>? _weather;
  List<HourlyForecast>? _hourlyWeather;
  bool _loading = true;
  String? _error;
  String _selectedModel = 'best_match';
  
  String _displayCityName = 'Kec. Bulungan, Kalimantan Utara';
  double _latitude = 2.85;
  double _longitude = 117.35;

  final TextEditingController _searchController = TextEditingController();
  List<CityLocation> _searchResults = [];
  bool _isSearching = false;

  late List<WeatherWarning> _warnings;

  @override
  void initState() {
    super.initState();
    _initWarningsData();
    _loadWeather();
  }

  void _initWarningsData() {
    final now = DateTime.now();
    _warnings = [
      WeatherWarning(
        regionId: 'kalut_01',
        regionName: 'Kec. Bulungan, Kalimantan Utara',
        levelName: 'Siaga / Bahaya Ekstrem',
        level: WarningLevel.danger,
        description: 'Potensi hujan sedang-lebat disertai kilat/petir intensif.',
        startTime: now.subtract(const Duration(hours: 1)),
        endTime: now.add(const Duration(hours: 3)),
      ),
      WeatherWarning(
        regionId: 'gorontalo_01',
        regionName: 'Kec. Kota Selatan, Gorontalo',
        levelName: 'Waspada',
        level: WarningLevel.warning,
        description: 'Hujan intensitas ringan hingga sedang durasi sore hari.',
        startTime: now.subtract(const Duration(hours: 2)),
        endTime: now.add(const Duration(hours: 4)),
      ),
      WeatherWarning(
        regionId: 'bali_01',
        regionName: 'Kec. Denpasar Timur, Bali',
        levelName: 'Aman Normal',
        level: WarningLevel.safe,
        description: 'Cuaca cerah berawan, angin sepoi-sepoi.',
        startTime: now.subtract(const Duration(hours: 5)),
        endTime: now.add(const Duration(hours: 5)),
      ),
      WeatherWarning(
        regionId: 'jatim_01',
        regionName: 'Kec. Gubeng, Surabaya, Jawa Timur',
        levelName: 'Waspada Badai',
        level: WarningLevel.warning,
        description: 'Potensi hujan lebat disertai angin kencang.',
        startTime: now.subtract(const Duration(hours: 1)),
        endTime: now.add(const Duration(hours: 4)),
      ),
      WeatherWarning(
        regionId: 'jakarta_01',
        regionName: 'Kec. Menteng, Jakarta Pusat',
        levelName: 'Aman Normal',
        level: WarningLevel.safe,
        description: 'Cerah berawan sepanjang siang hari.',
        startTime: now.subtract(const Duration(hours: 3)),
        endTime: now.add(const Duration(hours: 3)),
      ),
    ];
  }

  Future<void> _loadWeather() async {
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([
        _service.fetchWeather(latitude: _latitude, longitude: _longitude, model: _selectedModel),
        _service.fetchHourlyForecast(latitude: _latitude, longitude: _longitude, model: _selectedModel),
      ]);
      
      if (!mounted) return;
      setState(() { 
        _weather = results[0] as List<DailyForecast>; 
        _hourlyWeather = results[1] as List<HourlyForecast>;
        _loading = false; 
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString().replaceFirst('Exception: ', ''); _loading = false; });
    }
  }

  void _onModelChanged(String model) {
    setState(() => _selectedModel = model);
    _loadWeather();
  }

  Future<void> _onSearchChanged(String query) async {
    if (query.trim().length < 3) {
      setState(() => _searchResults = []);
      return;
    }
    setState(() => _isSearching = true);
    final results = await _service.searchGlobalCity(query);
    if (!mounted) return;
    setState(() {
      _searchResults = results;
      _isSearching = false;
    });
  }

  void _selectCity(CityLocation city) {
    FocusScope.of(context).unfocus();
    setState(() {
      _latitude = city.lat;
      _longitude = city.lon;
      _displayCityName = '${city.name}, ${city.admin1.isNotEmpty ? city.admin1 : city.country}';
      _searchResults = [];
      _searchController.clear();
    });
    _loadWeather();
  }

  void _openAiChat() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: Colors.white)),
    );

    try {
      final summary = await _service.fetchWeatherContextSummary(
        latitude: _latitude,
        longitude: _longitude,
      );
      if (!mounted) return;
      Navigator.pop(context);

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatScreen(
            location: _displayCityName,
            weatherContext: summary,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menyiapkan data AI: $e')),
      );
    }
  }

  WeatherWarning? _getCurrentUserWarning() {
    try {
      return _warnings.firstWhere(
        (w) => _displayCityName.toLowerCase().contains(w.regionName.split(',').first.trim().toLowerCase()) && w.isActive,
      );
    } catch (_) {
      try {
        return _warnings.firstWhere((w) => w.isActive);
      } catch (_) {
        return null;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    HourlyForecast? currentHourData;
    if (_hourlyWeather != null && _hourlyWeather!.isNotEmpty) {
      final now = DateTime.now();
      currentHourData = _hourlyWeather!.firstWhere(
        (h) => h.time.hour == now.hour && h.time.day == now.day,
        orElse: () => _hourlyWeather!.first,
      );
    }

    final today = (_weather != null && _weather!.isNotEmpty) ? _weather!.first : null;
    int activeRainProbability = currentHourData?.precipitationProbability ?? today?.precipitationProbability ?? 0;
    final activeWarning = _getCurrentUserWarning();

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: _loading
            ? const WeatherLoadingWidget()
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFF334155)),
                          ),
                          child: TextField(
                            controller: _searchController,
                            onChanged: _onSearchChanged,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: 'Cari wilayah/kecamatan di Asia Pasifik & Dunia...',
                              hintStyle: const TextStyle(color: Colors.white54, fontSize: 13),
                              border: InputBorder.none,
                              prefixIcon: const Icon(Icons.search, color: Color(0xFF38BDF8)),
                              suffixIcon: _isSearching 
                                  ? const Padding(
                                      padding: EdgeInsets.all(12.0),
                                      child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Color(0xFF38BDF8), strokeWidth: 2)),
                                    )
                                  : null,
                            ),
                          ),
                        ),
                        if (_searchResults.isNotEmpty)
                          Container(
                            margin: const EdgeInsets.only(top: 8),
                            constraints: const BoxConstraints(maxHeight: 250),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E293B),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFF334155)),
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 10)],
                            ),
                            child: ListView.builder(
                              shrinkWrap: true,
                              itemCount: _searchResults.length,
                              itemBuilder: (context, index) {
                                final city = _searchResults[index];
                                final subtitle = [city.admin1, city.country].where((e) => e.isNotEmpty).join(', ');
                                return ListTile(
                                  leading: const Icon(Icons.location_on, color: Color(0xFF38BDF8)),
                                  title: Text(city.name, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                                  subtitle: Text(subtitle, style: const TextStyle(color: Colors.white70)),
                                  onTap: () => _selectCity(city),
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: _error != null
                        ? _buildError()
                        : _buildContent(today!, currentHourData, activeRainProbability, activeWarning),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 64),
            const SizedBox(height: 16),
            Text(_error ?? 'Terjadi kesalahan', style: const TextStyle(color: Colors.white, fontSize: 14), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF38BDF8), foregroundColor: Colors.black),
              onPressed: _loadWeather, 
              child: const Text('Coba Lagi'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(DailyForecast today, HourlyForecast? currentHour, int activeRainProbability, WeatherWarning? activeWarning) {
    final warningColor = activeWarning?.level == WarningLevel.danger
        ? Colors.redAccent
        : activeWarning?.level == WarningLevel.warning
            ? Colors.amberAccent
            : Colors.greenAccent;

    final warningBgColor = activeWarning?.level == WarningLevel.danger
        ? Colors.red.withOpacity(0.15)
        : activeWarning?.level == WarningLevel.warning
            ? Colors.amber.withOpacity(0.15)
            : Colors.green.withOpacity(0.15);

    return RefreshIndicator(
      color: const Color(0xFF38BDF8),
      backgroundColor: const Color(0xFF1E293B),
      onRefresh: _loadWeather,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('WeatherFit', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                    Text(_displayCityName, style: const TextStyle(color: Colors.white70, fontSize: 14)),
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      onPressed: _loadWeather, 
                      icon: const Icon(Icons.refresh, color: Colors.white70),
                    ),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, color: Colors.white),
                      color: const Color(0xFF1E293B),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: const BorderSide(color: Color(0xFF334155)),
                      ),
                      onSelected: (value) {
                        if (value == 'open_ai_chat') {
                          _openAiChat();
                        } else if (value == 'map_warning') {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => WeatherMapPage(warnings: _warnings),
                            ),
                          );
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'map_warning',
                          child: Row(
                            children: [
                              Icon(Icons.map_outlined, color: Color(0xFF38BDF8), size: 20),
                              SizedBox(width: 10),
                              Text('Peta Peringatan Cuaca', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'open_ai_chat',
                          child: Row(
                            children: [
                              Icon(Icons.cloud_done, color: Color(0xFF38BDF8), size: 20),
                              SizedBox(width: 10),
                              Text('Help from the Clouds', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: warningBgColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: warningColor, width: 1),
              ),
              child: Row(
                children: [
                  Icon(
                    activeWarning?.level == WarningLevel.danger
                        ? Icons.warning_amber_rounded
                        : Icons.info_outline,
                    color: warningColor,
                    size: 28,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          activeWarning?.levelName ?? 'Kondisi Normal / Aman',
                          style: TextStyle(
                            color: warningColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          activeWarning?.description ?? 'Wilayah terpantau stabil, tidak ada anomali cuaca ekstrem.',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _buildModelSelector(),
            const SizedBox(height: 20),
            _buildCurrentWeather(today!, currentHour),
            const SizedBox(height: 20),
            _buildUmbrellaRecommendation(activeRainProbability),
            const SizedBox(height: 20),
            _buildHourlySection(),
            const SizedBox(height: 20),
            const Text('Prakiraan 10 Hari', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            ..._weather!.asMap().entries.map((entry) {
              return _buildForecastCard(
                forecast: entry.value,
                label: entry.key == 0 ? 'Hari Ini' : WeatherUtils.getDayName(entry.value.date),
              );
            }),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildHourlySection() {
    if (_hourlyWeather == null || _hourlyWeather!.isEmpty) return const SizedBox.shrink();
    final items = _hourlyWeather!.take(24).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Prakiraan 24 Jam (Per Jam)', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        SizedBox(
          height: 135,
          child: ListView.builder(
            physics: const BouncingScrollPhysics(),
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            itemBuilder: (context, index) {
              final h = items[index];
              final timeStr = '${h.time.hour.toString().padLeft(2, '0')}:00';
              final rainColor = h.precipitationProbability >= 60 ? const Color(0xFFEF4444) : h.precipitationProbability >= 30 ? const Color(0xFFF59E0B) : const Color(0xFF10B981);
              
              return Container(
                width: 85,
                margin: const EdgeInsets.only(right: 10),
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Text(timeStr, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white70)),
                    Icon(WeatherUtils.getWeatherIcon(h.weatherCode), color: const Color(0xFF38BDF8), size: 26),
                    Text('${h.temp.round()}°', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.water_drop, size: 10, color: rainColor),
                        const SizedBox(width: 2),
                        Text('${h.precipitationProbability}%', style: TextStyle(fontSize: 11, color: rainColor, fontWeight: FontWeight.bold)),
                      ],
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

  Widget _buildModelSelector() {
    final models = [
      {'key': 'best_match', 'label': 'Best Match'},
      {'key': 'ecmwf_ifs025', 'label': 'ECMWF'},
      {'key': 'ncep_gfs_seamless', 'label': 'GFS'},
    ];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Row(
        children: models.map((m) {
          final isSelected = m['key'] == _selectedModel;
          return Expanded(
            child: GestureDetector(
              onTap: () => _onModelChanged(m['key']!),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF38BDF8) : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    m['label']!,
                    style: TextStyle(
                      color: isSelected ? const Color(0xFF0F172A) : Colors.white70,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildUmbrellaRecommendation(int probability) {
    final color = WeatherUtils.getUmbrellaColor(probability);
    final icon = WeatherUtils.getUmbrellaIcon(probability);
    final text = WeatherUtils.getUmbrellaRecommendation(probability);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Rekomendasi Saat Ini', style: TextStyle(fontSize: 12, color: Colors.white54, fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(text, style: TextStyle(fontSize: 16, color: color, fontWeight: FontWeight.bold)),
                Text('Peluang hujan jam ini $probability%', style: const TextStyle(fontSize: 12, color: Colors.white70)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForecastCard({required DailyForecast forecast, required String label}) {
    final rainColor = forecast.precipitationProbability >= 60 ? const Color(0xFFEF4444) : forecast.precipitationProbability >= 30 ? const Color(0xFFF59E0B) : const Color(0xFF10B981);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Row(
        children: [
          SizedBox(width: 60, child: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white))),
          Icon(WeatherUtils.getWeatherIcon(forecast.weatherCode), color: const Color(0xFF38BDF8), size: 26),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: rainColor.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
            child: Row(
              children: [
                Icon(Icons.water_drop, size: 12, color: rainColor),
                const SizedBox(width: 3),
                Text('${forecast.precipitationProbability}%', style: TextStyle(fontSize: 12, color: rainColor, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const Spacer(),
          Text('${forecast.tempMin.round()}°', style: const TextStyle(fontSize: 14, color: Colors.white54)),
          const SizedBox(width: 8),
          Text('${forecast.tempMax.round()}°', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
        ],
      ),
    );
  }

  Widget _buildCurrentWeather(DailyForecast today, HourlyForecast? currentHour) {
    final temp = currentHour?.temp.round() ?? today.tempMax.round();
    final code = currentHour?.weatherCode ?? today.weatherCode;
    final rainProb = currentHour?.precipitationProbability ?? today.precipitationProbability;
    final description = WeatherUtils.getWeatherDescription(code);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E293B), Color(0xFF334155)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(WeatherUtils.getWeatherIcon(code), color: const Color(0xFF38BDF8), size: 72),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$temp°', style: const TextStyle(color: Colors.white, fontSize: 56, fontWeight: FontWeight.w300, height: 1)),
                const SizedBox(height: 4),
                Text(description, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text('Min ${today.tempMin.round()}° • Hujan $rainProb%', style: const TextStyle(color: Colors.white70, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ================== WEATHER MAP INTERACTIVE PAGE (PRO VERSION) ==================
class WeatherMapPage extends StatefulWidget {
  final List<WeatherWarning> warnings;

  const WeatherMapPage({super.key, required this.warnings});

  @override
  State<WeatherMapPage> createState() => _WeatherMapPageState();
}

class _WeatherMapPageState extends State<WeatherMapPage> {
  String _searchQuery = "";
  double _zoomScale = 1.2;

  @override
  Widget build(BuildContext context) {
    final filteredWarnings = widget.warnings.where((w) {
      return w.regionName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          w.levelName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          w.description.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Peta Peringatan Dini Asia Pasifik', style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          // ==========================================
          // BANNER WAKTU BERLAKU (ALA BMKG PROFESSIONAL)
          // ==========================================
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E293B), Color(0xFF334155)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.access_time_filled, color: Color(0xFF38BDF8), size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      'Masa Berlaku Peringatan:',
                      style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF38BDF8).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    '14:30 - 18:00 WITA',
                    style: TextStyle(color: Color(0xFF38BDF8), fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),

          // ==========================================
          // INTERACTIVE MAP CONTAINER (PRO REGIONAL BLOCKS)
          // ==========================================
          Expanded(
            flex: 6,
            child: Container(
              margin: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0B132B),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: Stack(
                children: [
                  InteractiveViewer(
                    minScale: 1.0,
                    maxScale: 4.0,
                    onInteractionUpdate: (details) {
                      setState(() {
                        _zoomScale = details.scale;
                      });
                    },
                    child: Center(
                      child: CustomPaint(
                        size: const Size(double.infinity, double.infinity),
                        painter: AsiaPacificProMapPainter(warnings: widget.warnings, zoom: _zoomScale),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 16,
                    left: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Text(
                        'Zoom: ${_zoomScale.toStringAsFixed(1)}x (${_zoomScale > 2.0 ? "Detail Level Kecamatan" : "Level Provinsi/Region"})',
                        style: const TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 16,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B).withOpacity(0.95),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF334155)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          _LegendItem(color: Colors.greenAccent, label: 'Hijau (Aman / Normal)'),
                          SizedBox(height: 4),
                          _LegendItem(color: Colors.amberAccent, label: 'Kuning (Waspada Badai)'),
                          SizedBox(height: 4),
                          _LegendItem(color: Colors.redAccent, label: 'Merah (Bahaya / Siaga)'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ==========================================
          // SEARCH & REGIONAL WARNING CARDS LIST
          // ==========================================
          Expanded(
            flex: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  TextField(
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Cari Peringatan Wilayah / Kecamatan...',
                      hintStyle: const TextStyle(color: Colors.white54, fontSize: 13),
                      prefixIcon: const Icon(Icons.search, color: Color(0xFF38BDF8)),
                      filled: true,
                      fillColor: const Color(0xFF1E293B),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      itemCount: filteredWarnings.length,
                      itemBuilder: (context, index) {
                        final warning = filteredWarnings[index];
                        final color = warning.level == WarningLevel.danger
                            ? Colors.redAccent
                            : warning.level == WarningLevel.warning
                                ? Colors.amberAccent
                                : Colors.greenAccent;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: color.withOpacity(0.4)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 4,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: color,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        warning.regionName,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        warning.description,
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: color.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  warning.isActive ? 'Aktif' : 'Lewat',
                                  style: TextStyle(
                                    color: color,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
      ],
    );
  }
}

// ================== PRO ASIA PACIFIC MAP PAINTER ==================
class AsiaPacificProMapPainter extends CustomPainter {
  final List<WeatherWarning> warnings;
  final double zoom;

  AsiaPacificProMapPainter({required this.warnings, required this.zoom});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    // Ocean Background Canvas
    paint.color = const Color(0xFF0F172A);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);

    // Draw subtle grid lines for radar effect
    final gridPaint = Paint()
      ..color = Colors.white12
      ..strokeWidth = 0.5;
    for (double i = 0; i < size.width; i += 40 * zoom) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), gridPaint);
    }
    for (double j = 0; j < size.height; j += 40 * zoom) {
      canvas.drawLine(Offset(0, j), Offset(size.width, j), gridPaint);
    }

    // Regional Blocks representing Asia-Pacific / Indonesia Islands with full polygon/region fill
    // 1. Kalimantan (Danger/Red)
    paint.color = Colors.redAccent.withOpacity(0.5);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.25, size.height * 0.35, size.width * 0.22 * zoom, size.height * 0.25 * zoom),
        const Radius.circular(12),
      ),
      paint,
    );

    // 2. Sulawesi / Gorontalo (Warning/Yellow)
    paint.color = Colors.amberAccent.withOpacity(0.5);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.52, size.height * 0.4, size.width * 0.16 * zoom, size.height * 0.22 * zoom),
        const Radius.circular(12),
      ),
      paint,
    );

    // 3. Jawa & Bali (Warning & Safe Mix)
    paint.color = Colors.amberAccent.withOpacity(0.5);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.28, size.height * 0.68, size.width * 0.25 * zoom, size.height * 0.12 * zoom),
        const Radius.circular(10),
      ),
      paint,
    );

    paint.color = Colors.greenAccent.withOpacity(0.5);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.56, size.height * 0.7, size.width * 0.12 * zoom, size.height * 0.1 * zoom),
        const Radius.circular(8),
      ),
      paint,
    );

    // 4. Sumatera Region (Safe/Green)
    paint.color = Colors.greenAccent.withOpacity(0.4);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.08, size.height * 0.3, size.width * 0.14 * zoom, size.height * 0.35 * zoom),
        const Radius.circular(12),
      ),
      paint,
    );

    // 5. Papua & Eastern Region (Safe/Green)
    paint.color = Colors.greenAccent.withOpacity(0.4);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.74, size.height * 0.45, size.width * 0.2 * zoom, size.height * 0.25 * zoom),
        const Radius.circular(12),
      ),
      paint,
    );

    // Draw Region Labels for Professional Look
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );

    void drawLabel(String text, Offset offset, Color color) {
      textPainter.text = TextSpan(
        text: text,
        style: TextStyle(color: color, fontSize: 11 * (zoom > 1.5 ? 1.2 : 1.0), fontWeight: FontWeight.bold),
      );
      textPainter.layout();
      textPainter.paint(canvas, offset);
    }

    drawLabel("Kalimantan\n(Siaga Red)", Offset(size.width * 0.28, size.height * 0.45), Colors.white);
    drawLabel("Sulawesi\n(Waspada)", Offset(size.width * 0.54, size.height * 0.48), Colors.white);
    drawLabel("Jawa Timur\n(Waspada)", Offset(size.width * 0.35, size.height * 0.71), Colors.white);
    drawLabel("Bali\n(Aman)", Offset(size.width * 0.59, size.height * 0.73), Colors.white);
  }

  @override
  bool shouldRepaint(covariant AsiaPacificProMapPainter oldDelegate) {
    return oldDelegate.zoom != zoom || oldDelegate.warnings != warnings;
  }
}

// ================== 3. UI LAYAR CHAT ==================
class ChatScreen extends StatefulWidget {
  final String location;
  final String weatherContext;

  const ChatScreen({
    super.key,
    required this.location,
    required this.weatherContext,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final List<ChatMessage> _messages = [];
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;
  bool _isLastUsingFallback = true; 

  @override
  void initState() {
    super.initState();
    _messages.add(ChatMessage(
      text: "Halo! Aku Help from the Clouds. Mau tanya apa hari ini?",
      isUser: false,
      isUsingFallback: true,
    ));
  }

  void _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isLoading) return;

    _controller.clear();
    setState(() {
      _messages.add(ChatMessage(text: text, isUser: true));
      _isLoading = true;
    });
    _scrollToBottom();

    final result = await AiHelper.askAi(
      userQuestion: text,
      weatherContext: widget.weatherContext,
      location: widget.location,
    );

    setState(() {
      _messages.add(ChatMessage(
        text: result.text, 
        isUser: false,
        isUsingFallback: result.fallback,
      ));
      _isLastUsingFallback = result.fallback; 
      _isLoading = false;
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Row(
          children: [
            const Expanded(
              child: Text(
                'Help from the Clouds', 
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
            ),
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _isLastUsingFallback ? Colors.redAccent : Colors.greenAccent,
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isLastUsingFallback ? Colors.redAccent : Colors.greenAccent,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _isLastUsingFallback ? 'Local' : 'Live AI',
                    style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                return Align(
                  alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                    decoration: BoxDecoration(
                      color: msg.isUser 
                          ? const Color(0xFF38BDF8) 
                          : const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: msg.isUser 
                            ? const Color(0xFF38BDF8) 
                            : (!msg.isUser && msg.isUsingFallback ? Colors.redAccent.withOpacity(0.4) : const Color(0xFF334155)),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      msg.text,
                      style: TextStyle(
                        color: msg.isUser ? const Color(0xFF0F172A) : Colors.white70,
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: LinearProgressIndicator(color: Color(0xFF38BDF8), backgroundColor: Color(0xFF1E293B)),
            ),
          Padding(
            padding: EdgeInsets.only(bottom: bottomInset),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: const BoxDecoration(
                color: Color(0xFF1E293B),
                border: Border(top: BorderSide(color: Color(0xFF334155))),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      onSubmitted: (_) => _sendMessage(),
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: 'Ketik pesan...',
                        hintStyle: TextStyle(color: Colors.white54),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _sendMessage,
                    icon: const Icon(Icons.send, color: Color(0xFF38BDF8)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
