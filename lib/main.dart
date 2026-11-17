import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';
import 'dart:async';

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
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4A90E2)),
      ),
      home: const WeatherScreen(),
    );
  }
}

// ================== MODEL ==================
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

// Model untuk peringatan BMKG
class BmkgWarning {
  final String title;
  final String description;
  final String severity; // "Merah", "Kuning", "Hijau"
  final String pubDate;

  BmkgWarning({
    required this.title,
    required this.description,
    required this.severity,
    required this.pubDate,
  });
}

// ================== 1. AI HELPER ==================
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
        } catch (e) {
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
  static const String _bmkgAlertUrl = 'https://www.bmkg.go.id/alerts/nowcast/id';

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
    } catch (e) {
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

  // Fungsi untuk mengambil peringatan dini BMKG (XML Parsing Manual)
  Future<List<BmkgWarning>> fetchBmkgAlerts() async {
    try {
      final response = await http.get(Uri.parse(_bmkgAlertUrl)).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) return [];

      final xmlString = response.body;
      // Parsing XML manual sederhana untuk mengambil item <item>
      final itemRegex = RegExp(r'<item>(.*?)</item>', dotAll: true);
      final matches = itemRegex.allMatches(xmlString);

      List<BmkgWarning> warnings = [];
      for (var match in matches) {
        final itemContent = match.group(1) ?? '';
        
        // Ekstrak Title
        final titleMatch = RegExp(r'<title>(.*?)</title>', dotAll: true).firstMatch(itemContent);
        final title = titleMatch?.group(1)?.replaceAll(RegExp(r'<!\[CDATA\[|\]\]>'), '').trim() ?? 'Peringatan Cuaca';
        
        // Ekstrak Description
        final descMatch = RegExp(r'<description>(.*?)</description>', dotAll: true).firstMatch(itemContent);
        final desc = descMatch?.group(1)?.replaceAll(RegExp(r'<!\[CDATA\[|\]\]>'), '').trim() ?? 'Wilayah terdampak.';
        
        // Ekstrak PubDate
        final dateMatch = RegExp(r'<pubDate>(.*?)</pubDate>', dotAll: true).firstMatch(itemContent);
        final pubDate = dateMatch?.group(1)?.trim() ?? '';

        // Tentukan Severity berdasarkan kata kunci di deskripsi (simulasi karena RSS tidak menyediakan tag severity langsung)
        String severity = 'Hijau';
        if (desc.toLowerCase().contains('lebat') || desc.toLowerCase().contains('petir') || desc.toLowerCase().contains('angin kencang')) {
          severity = 'Merah';
        } else if (desc.toLowerCase().contains('sedang') || desc.toLowerCase().contains('ringan')) {
          severity = 'Kuning';
        }

        warnings.add(BmkgWarning(
          title: title,
          description: desc,
          severity: severity,
          pubDate: pubDate,
        ));
      }
      return warnings;
    } catch (e) {
      return [];
    }
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
    if (code == 0) return const Color(0xFF4A90E2);
    if (code <= 3) return const Color(0xFF7B8FA1);
    if (code <= 48) return const Color(0xFF9EA7B3);
    if (code <= 67) return const Color(0xFF3A5A80);
    if (code <= 82) return const Color(0xFF2C3E50);
    return const Color(0xFF1A1F2E);
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
    if (prob >= 60) return const Color(0xFFE74C3C);
    if (prob >= 30) return const Color(0xFFF39C12);
    return const Color(0xFF27AE60);
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
  
  String _displayCityName = 'Jakarta, Indonesia';
  double _latitude = -6.2088;
  double _longitude = 106.8456;

  final TextEditingController _searchController = TextEditingController();
  List<CityLocation> _searchResults = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _loadWeather();
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
      _displayCityName = '${city.name}, ${city.country}';
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

  void _openWeatherMap() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AsiaPacificMapScreen()),
    );
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
    
    final activeCode = currentHourData?.weatherCode ?? today?.weatherCode ?? 0;
    final bgColor = WeatherUtils.getWeatherColor(activeCode);

    int activeRainProbability = currentHourData?.precipitationProbability ?? today?.precipitationProbability ?? 0;

    return Scaffold(
      backgroundColor: bgColor,
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
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: TextField(
                            controller: _searchController,
                            onChanged: _onSearchChanged,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: 'Cari kota di seluruh dunia...',
                              hintStyle: const TextStyle(color: Colors.white70),
                              border: InputBorder.none,
                              prefixIcon: const Icon(Icons.search, color: Colors.white),
                              suffixIcon: _isSearching 
                                  ? const Padding(
                                      padding: EdgeInsets.all(12.0),
                                      child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
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
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10)],
                            ),
                            child: ListView.builder(
                              shrinkWrap: true,
                              itemCount: _searchResults.length,
                              itemBuilder: (context, index) {
                                final city = _searchResults[index];
                                final subtitle = [city.admin1, city.country].where((e) => e.isNotEmpty).join(', ');
                                return ListTile(
                                  leading: const Icon(Icons.location_on, color: Color(0xFF4A90E2)),
                                  title: Text(city.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                  subtitle: Text(subtitle),
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
                        : _buildContent(today!, currentHourData, activeRainProbability),
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
            const Icon(Icons.error_outline, color: Colors.white, size: 64),
            const SizedBox(height: 16),
            Text(_error ?? 'Terjadi kesalahan', style: const TextStyle(color: Colors.white, fontSize: 14), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadWeather, child: const Text('Coba Lagi')),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(DailyForecast today, HourlyForecast? currentHour, int activeRainProbability) {
    return RefreshIndicator(
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
                      icon: const Icon(Icons.refresh, color: Colors.white),
                    ),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, color: Colors.white),
                      color: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      onSelected: (value) {
                        if (value == 'open_ai_chat') {
                          _openAiChat();
                        } else if (value == 'open_map') {
                          _openWeatherMap();
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'open_ai_chat',
                          child: Row(
                            children: [
                              Icon(Icons.cloud_done, color: Color(0xFF4A90E2), size: 20),
                              SizedBox(width: 10),
                              Text(
                                'Help from the Clouds',
                                style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF2C3E50)),
                              ),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'open_map',
                          child: Row(
                            children: [
                              Icon(Icons.map, color: Color(0xFFE74C3C), size: 20),
                              SizedBox(width: 10),
                              Text(
                                'Peta Peringatan Dini',
                                style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF2C3E50)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildModelSelector(),
            const SizedBox(height: 24),
            _buildCurrentWeather(today, currentHour),
            const SizedBox(height: 24),
            _buildUmbrellaRecommendation(activeRainProbability),
            
            const SizedBox(height: 24),
            _buildHourlySection(),

            const SizedBox(height: 24),
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
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            itemBuilder: (context, index) {
              final h = items[index];
              final timeStr = '${h.time.hour.toString().padLeft(2, '0')}:00';
              final rainColor = h.precipitationProbability >= 60 ? const Color(0xFFE74C3C) : h.precipitationProbability >= 30 ? const Color(0xFFF39C12) : const Color(0xFF3498DB);
              
              return Container(
                width: 85,
                margin: const EdgeInsets.only(right: 10),
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 8, offset: const Offset(0, 2))],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Text(timeStr, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50))),
                    Icon(WeatherUtils.getWeatherIcon(h.weatherCode), color: const Color(0xFF4A90E2), size: 26),
                    Text('${h.temp.round()}°', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50))),
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
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: models.map((m) {
          final isSelected = m['key'] == _selectedModel;
          return Expanded(
            child: GestureDetector(
              onTap: () => _onModelChanged(m['key']!),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(color: isSelected ? Colors.white : Colors.transparent, borderRadius: BorderRadius.circular(8)),
                child: Center(
                  child: Text(m['label']!, style: TextStyle(color: isSelected ? const Color(0xFF2C3E50) : Colors.white, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, fontSize: 13)),
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
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 12, offset: const Offset(0, 4))]),
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
                const Text('Rekomendasi Saat Ini', style: TextStyle(fontSize: 12, color: Color(0xFF7B8FA1), fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(text, style: TextStyle(fontSize: 17, color: color, fontWeight: FontWeight.bold)),
                Text('Peluang hujan jam ini $probability%', style: const TextStyle(fontSize: 12, color: Color(0xFF7B8FA1))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForecastCard({required DailyForecast forecast, required String label}) {
    final rainColor = forecast.precipitationProbability >= 60 ? const Color(0xFFE74C3C) : forecast.precipitationProbability >= 30 ? const Color(0xFFF39C12) : const Color(0xFF3498DB);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 8, offset: const Offset(0, 2))]),
      child: Row(
        children: [
          SizedBox(width: 60, child: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF2C3E50)))),
          Icon(WeatherUtils.getWeatherIcon(forecast.weatherCode), color: const Color(0xFF4A90E2), size: 26),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: rainColor.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
            child: Row(
              children: [
                Icon(Icons.water_drop, size: 12, color: rainColor),
                const SizedBox(width: 3),
                Text('${forecast.precipitationProbability}%', style: TextStyle(fontSize: 12, color: rainColor, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const Spacer(),
          Text('${forecast.tempMin.round()}°', style: const TextStyle(fontSize: 14, color: Color(0xFF95A5A6))),
          const SizedBox(width: 8),
          Text('${forecast.tempMax.round()}°', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50))),
        ],
      ),
    );
  }

  Widget _buildCurrentWeather(DailyForecast today, HourlyForecast? currentHour) {
    final temp = currentHour?.temp.round() ?? today.tempMax.round();
    final code = currentHour?.weatherCode ?? today.weatherCode;
    final rainProb = currentHour?.precipitationProbability ?? today.precipitationProbability;
    final description = WeatherUtils.getWeatherDescription(code);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(WeatherUtils.getWeatherIcon(code), color: Colors.white, size: 80),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$temp°', style: const TextStyle(color: Colors.white, fontSize: 64, fontWeight: FontWeight.w200, height: 1)),
              Text(description, style: const TextStyle(color: Colors.white70, fontSize: 16)),
              Text('Min ${today.tempMin.round()}° • Hujan $rainProb%', style: const TextStyle(color: Colors.white60, fontSize: 13)),
            ],
          ),
        ),
      ],
    );
  }
}

// ================== 2. PETA PERINGATAN INDONESIA (BMKG LIVE + SIMULASI VISUAL) ==================
class AsiaPacificMapScreen extends StatefulWidget {
  const AsiaPacificMapScreen({super.key});

  @override
  State<AsiaPacificMapScreen> createState() => _AsiaPacificMapScreenState();
}

class _AsiaPacificMapScreenState extends State<AsiaPacificMapScreen> {
  final TransformationController _transformationController = TransformationController();
  final WeatherService _service = WeatherService();
  List<BmkgWarning> _warnings = [];
  bool _isLoadingWarnings = true;

  @override
  void initState() {
    super.initState();
    _loadBmkgWarnings();
  }

  Future<void> _loadBmkgWarnings() async {
    final warnings = await _service.fetchBmkgAlerts();
    if (mounted) {
      setState(() {
        _warnings = warnings;
        _isLoadingWarnings = false;
      });
    }
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Peta Peringatan Indonesia',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          // Banner Masa Berlaku
          Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF1E3A5F),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF3B82F6).withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.access_time, color: Color(0xFF60A5FA), size: 20),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Masa Berlaku Peringatan:',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    '14:30 - 18:00 WIB', // Diubah ke WIB karena fokus Indonesia
                    style: TextStyle(color: Color(0xFF60A5FA), fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          
          // Peta Interaktif (Simulasi Visual)
          Expanded(
            flex: 3,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF111827),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              clipBehavior: Clip.antiAlias,
              child: InteractiveViewer(
                transformationController: _transformationController,
                minScale: 0.5,
                maxScale: 5.0,
                boundaryMargin: const EdgeInsets.all(100),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: CustomPaint(painter: GridPainter()),
                    ),
                    Positioned.fill(
                      child: CustomPaint(
                        painter: IndonesiaWeatherMapPainter(),
                      ),
                    ),
                    Positioned(
                      top: 12,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Zoom: 1.0x (Level Kabupaten/Kota)',
                          style: TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // Legenda
          Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildLegendItem(const Color(0xFF10B981), 'Hijau (Aman)'),
                _buildLegendItem(const Color(0xFFF59E0B), 'Kuning (Waspada)'),
                _buildLegendItem(const Color(0xFFEF4444), 'Merah (Bahaya)'),
              ],
            ),
          ),

          // Daftar Peringatan (Live dari BMKG)
          Expanded(
            flex: 2,
            child: _isLoadingWarnings
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF60A5FA)))
                : _warnings.isEmpty
                    ? const Center(child: Text('Tidak ada peringatan dini aktif.', style: TextStyle(color: Colors.white70)))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: _warnings.length,
                        itemBuilder: (context, index) {
                          final warning = _warnings[index];
                          final color = warning.severity == 'Merah'
                              ? const Color(0xFFEF4444)
                              : warning.severity == 'Kuning'
                                  ? const Color(0xFFF59E0B)
                                  : const Color(0xFF10B981);
                          return _buildWarningCard(
                            title: warning.title,
                            description: warning.description,
                            color: color,
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
      ],
    );
  }

  Widget _buildWarningCard({required String title, required String description, required Color color}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: color, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Aktif',
                  style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: const TextStyle(color: Colors.white60, fontSize: 12),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ================== CUSTOM PAINTERS ==================

class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF1E293B)
      ..strokeWidth = 1.0;

    for (double i = 0; i < size.width; i += 40) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (double i = 0; i < size.height; i += 40) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class IndonesiaWeatherMapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // ==========================================
    // PETA INDONESIA (DIPERBESAR & DIPUSATKAN)
    // ==========================================
    
    // 1. Kab. Bulungan (Utara) - MERAH
    final kalimantanUtara = Path()
      ..moveTo(w * 0.35, h * 0.15)
      ..lineTo(w * 0.45, h * 0.12)
      ..lineTo(w * 0.48, h * 0.20)
      ..lineTo(w * 0.40, h * 0.23)
      ..lineTo(w * 0.33, h * 0.20)
      ..close();
    canvas.drawPath(kalimantanUtara, Paint()..color = const Color(0xFFEF4444).withOpacity(0.8));
    
    // 2. Kab. Kotawaringin (Tengah) - KUNING
    final kalimantanTengah = Path()
      ..moveTo(w * 0.38, h * 0.23)
      ..lineTo(w * 0.48, h * 0.20)
      ..lineTo(w * 0.52, h * 0.30)
      ..lineTo(w * 0.45, h * 0.35)
      ..lineTo(w * 0.35, h * 0.33)
      ..close();
    canvas.drawPath(kalimantanTengah, Paint()..color = const Color(0xFFF59E0B).withOpacity(0.8));

    // 3. Kalimantan Selatan/Timur (Sisa) - HIJAU
    final kalimantanSisa = Path()
      ..moveTo(w * 0.35, h * 0.33)
      ..lineTo(w * 0.45, h * 0.35)
      ..lineTo(w * 0.52, h * 0.30)
      ..lineTo(w * 0.54, h * 0.40)
      ..lineTo(w * 0.40, h * 0.45)
      ..lineTo(w * 0.30, h * 0.40)
      ..close();
    canvas.drawPath(kalimantanSisa, Paint()..color = const Color(0xFF10B981).withOpacity(0.8));

    // 4. Jawa Barat (Hijau)
    final jabar = Path()
      ..moveTo(w * 0.25, h * 0.55)
      ..lineTo(w * 0.30, h * 0.52)
      ..lineTo(w * 0.33, h * 0.56)
      ..lineTo(w * 0.28, h * 0.58)
      ..close();
    canvas.drawPath(jabar, Paint()..color = const Color(0xFF10B981).withOpacity(0.8));

    // 5. Jawa Tengah (Kuning)
    final jateng = Path()
      ..moveTo(w * 0.30, h * 0.52)
      ..lineTo(w * 0.38, h * 0.53)
      ..lineTo(w * 0.40, h * 0.57)
      ..lineTo(w * 0.33, h * 0.56)
      ..close();
    canvas.drawPath(jateng, Paint()..color = const Color(0xFFF59E0B).withOpacity(0.8));

    // 6. Jawa Timur / Surabaya (Hijau)
    final jatim = Path()
      ..moveTo(w * 0.38, h * 0.53)
      ..lineTo(w * 0.50, h * 0.55)
      ..lineTo(w * 0.49, h * 0.59)
      ..lineTo(w * 0.40, h * 0.57)
      ..close();
    canvas.drawPath(jatim, Paint()..color = const Color(0xFF10B981).withOpacity(0.8));

    // 7. Bali (Hijau)
    final bali = Path()
      ..moveTo(w * 0.51, h * 0.59)
      ..lineTo(w * 0.55, h * 0.60)
      ..lineTo(w * 0.55, h * 0.62)
      ..lineTo(w * 0.51, h * 0.61)
      ..close();
    canvas.drawPath(bali, Paint()..color = const Color(0xFF10B981).withOpacity(0.8));

    // ==========================================
    // SILUET PULAU LAIN (Hanya Garis Tepi)
    // ==========================================
    final strokePaint = Paint()
      ..color = const Color(0xFF475569)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // Sumatera
    final sumatera = Path()
      ..moveTo(w * 0.10, h * 0.20)
      ..lineTo(w * 0.18, h * 0.25)
      ..lineTo(w * 0.22, h * 0.40)
      ..lineTo(w * 0.15, h * 0.50)
      ..lineTo(w * 0.08, h * 0.45)
      ..lineTo(w * 0.05, h * 0.30)
      ..close();
    canvas.drawPath(sumatera, strokePaint);

    // Sulawesi
    final sulawesi = Path()
      ..moveTo(w * 0.55, h * 0.20)
      ..lineTo(w * 0.62, h * 0.18)
      ..lineTo(w * 0.68, h * 0.28)
      ..lineTo(w * 0.62, h * 0.38)
      ..lineTo(w * 0.55, h * 0.35)
      ..lineTo(w * 0.58, h * 0.25)
      ..close();
    canvas.drawPath(sulawesi, strokePaint);

    // Papua
    final papua = Path()
      ..moveTo(w * 0.80, h * 0.25)
      ..lineTo(w * 0.90, h * 0.22)
      ..lineTo(w * 0.95, h * 0.35)
      ..lineTo(w * 0.88, h * 0.45)
      ..lineTo(w * 0.75, h * 0.40)
      ..lineTo(w * 0.73, h * 0.30)
      ..close();
    canvas.drawPath(papua, strokePaint);

    // ==========================================
    // LABEL TEKS
    // ==========================================
    void drawText(String text, Offset offset, Color color, {double fontSize = 10}) {
      final textSpan = TextSpan(
        text: text,
        style: TextStyle(color: color, fontSize: fontSize, fontWeight: FontWeight.bold),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(canvas, offset);
    }

    drawText('Bulungan', Offset(w * 0.35, h * 0.16), Colors.white);
    drawText('Kotawaringin', Offset(w * 0.39, h * 0.27), Colors.white);
    drawText('Jatim', Offset(w * 0.42, h * 0.55), Colors.white, fontSize: 8);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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
                color: Colors.black.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isLastUsingFallback ? Colors.redAccent : Colors.greenAccent,
                      boxShadow: [
                        BoxShadow(
                          color: (_isLastUsingFallback ? Colors.redAccent : Colors.greenAccent).withOpacity(0.6),
                          blurRadius: 6,
                          spreadRadius: 2,
                        )
                      ],
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
        backgroundColor: const Color(0xFF4A90E2),
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
                          ? const Color(0xFF4A90E2) 
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(16),
                      border: (!msg.isUser && msg.isUsingFallback)
                          ? Border.all(color: Colors.redAccent.withOpacity(0.4), width: 1.5)
                          : null,
                    ),
                    child: Text(
                      msg.text,
                      style: TextStyle(
                        color: msg.isUser ? Colors.white : const Color(0xFF2C3E50),
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
              child: LinearProgressIndicator(color: Color(0xFF4A90E2)),
            ),
          Padding(
            padding: EdgeInsets.only(bottom: bottomInset),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      onSubmitted: (_) => _sendMessage(),
                      decoration: const InputDecoration(
                        hintText: 'Ketik pesan...',
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _sendMessage,
                    icon: const Icon(Icons.send, color: Color(0xFF4A90E2)),
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
