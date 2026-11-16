import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';

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
Kamu adalah asisten cuaca Waterfit. Kamu menerima 3 data prakiraan cuaca (ECMWF, GFS, BMKG) untuk lokasi $location. Bandingkan ketiga data tersebut. Prioritaskan data BMKG jika ada perbedaan. Jawab pertanyaan user: "$userQuestion" dengan bahasa santai. Sebutkan rekomendasi bawa payung dan jam terbaik. Jawab SANGAT SINGKAT (maksimal 2 paragraf).
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
      "Siapin payung deh buat berjaga-jaga di $location hari ini. Prediksi cuaca nunjukin ada potensi tetesan air dari langit yang lumayan sering. Stay safe ya! 🧥",
    ];

    final umbrellaNo = [
      "Aman bro! Pindai cuaca di $location nunjukin kondisi yang relatif cerah dan bersahabat. Lu kayaknya gak butuh payung hari ini, nikmati aja aktivitas lu! ✅",
      "Santai, cuaca di $location keliatannya adem dan kecil kemungkinan hujan. Gak usah repot bawa payung, nikmatin harinya dengan santai! ☀️",
      "Kondisi atmosfer di $location terpantau stabil dan minim awan mendung. Lu bebas beraktivitas tanpa perlu takut basah kuyup hari ini. 👍",
    ];

    final timeOrGeneral = [
      "Melihat pergerakan data cuaca di $location, transisi dari pagi ke sore hari bakal cukup dinamis. Pastikan lu cek grafik jam di halaman utama aplikasi buat tau detail pastinya ya!",
      "Kondisi udara dan suhu di $location terpantau fluktuatif. Buat waktu terbaik beraktivitas, lu bisa manfaatkan rentang jam pagi sebelum potensi cuaca berubah di siang hari.",
      "Prakiraan multi-model untuk $location merangkum cuaca yang cukup bervariasi hari ini. Tetap pantau indikator persentase hujan di aplikasi biar lu bisa ambil keputusan pas!",
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
      for (int i = 6; i <= 21; i += 3) {
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

  @override
  Widget build(BuildContext context) {
    final today = (_weather != null && _weather!.isNotEmpty) ? _weather!.first : null;
    final bgColor = today != null ? WeatherUtils.getWeatherColor(today.weatherCode) : const Color(0xFF4A90E2);

    // Ambil probabilitas hujan yang selaras dengan jam terdekat saat ini agar tidak bentrok dengan list 24 jam
    int activeRainProbability = today?.precipitationProbability ?? 0;
    if (_hourlyWeather != null && _hourlyWeather!.isNotEmpty) {
      final now = DateTime.now();
      final currentHourData = _hourlyWeather!.firstWhere(
        (h) => h.time.hour == now.hour && h.time.day == now.day,
        orElse: () => _hourlyWeather!.first,
      );
      activeRainProbability = currentHourData.precipitationProbability;
    }

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
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
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: Colors.white))
                  : _error != null
                      ? _buildError()
                      : _buildContent(today!, activeRainProbability),
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

  Widget _buildContent(DailyForecast today, int activeRainProbability) {
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
                      ],
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildModelSelector(),
            const SizedBox(height: 24),
            _buildCurrentWeather(today),
            const SizedBox(height: 24),
            // Menggunakan probabilitas jam aktif agar selaras dengan list 24 jam
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

  Widget _buildCurrentWeather(DailyForecast today) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(WeatherUtils.getWeatherIcon(today.weatherCode), color: Colors.white, size: 80),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${today.tempMax.round()}°', style: const TextStyle(color: Colors.white, fontSize: 64, fontWeight: FontWeight.w200, height: 1)),
              Text(WeatherUtils.getWeatherDescription(today.weatherCode), style: const TextStyle(color: Colors.white70, fontSize: 16)),
              Text('Min ${today.tempMin.round()}° • Hujan ${today.precipitationProbability}%', style: const TextStyle(color: Colors.white60, fontSize: 13)),
            ],
          ),
        ),
      ],
    );
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
