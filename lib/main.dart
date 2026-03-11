import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Mobile Ads only for Android/iOS
  if (!kIsWeb) {
    await MobileAds.instance.initialize();
  }
  
  runApp(const ProConverterApp());
}

class ProConverterApp extends StatefulWidget {
  const ProConverterApp({super.key});

  @override
  State<ProConverterApp> createState() => _ProConverterAppState();
}

class _ProConverterAppState extends State<ProConverterApp> {
  ThemeMode _themeMode = ThemeMode.dark;

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      final isDark = prefs.getBool('isDarkMode') ?? true;
      _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    });
  }

  Future<void> _toggleTheme(bool isDark) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', isDark);
    setState(() {
      _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: ThemeData.light().copyWith(
        primaryColor: const Color(0xFF007AFF),
        scaffoldBackgroundColor: Colors.white,
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
            selectedItemColor: Color(0xFF007AFF), unselectedItemColor: Colors.grey),
      ),
      darkTheme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
        colorScheme: const ColorScheme.dark(primary: Color(0xFF007AFF)),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
            selectedItemColor: Color(0xFF007AFF), unselectedItemColor: Colors.white24),
      ),
      home: MainDashboard(onThemeChanged: _toggleTheme, currentMode: _themeMode),
    );
  }
}

// --- GOOGLE ADS COMPONENT (Using your Real ID) ---
class BannerAdWidget extends StatefulWidget {
  const BannerAdWidget({super.key});

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _loadAd();
    }
  }

  void _loadAd() {
    _bannerAd = BannerAd(
      // YOUR REAL AD UNIT ID 
      adUnitId: 'ca-app-pub-1091684680167184/3603141261', 
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (ad) => setState(() => _isLoaded = true),
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          debugPrint('AdMob Error: $error');
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb || !_isLoaded || _bannerAd == null) {
      return const SizedBox.shrink();
    }

    return Container(
      alignment: Alignment.center,
      width: _bannerAd!.size.width.toDouble(),
      height: _bannerAd!.size.height.toDouble(),
      child: AdWidget(ad: _bannerAd!),
    );
  }
}

class MainDashboard extends StatefulWidget {
  final Function(bool) onThemeChanged;
  final ThemeMode currentMode;
  const MainDashboard({super.key, required this.onThemeChanged, required this.currentMode});

  @override
  State<MainDashboard> createState() => _MainDashboardState();
}

class _MainDashboardState extends State<MainDashboard> {
  int _navIdx = 0;
  int topicIdx = 0;
  int sectionIdx = 0;
  double inputValue = 1.0;
  String? fromUnit;
  Map<String, double> currencyRates = {};
  bool isLoadingCurrency = false;
  bool isOffline = false;
  final TextEditingController _controller = TextEditingController(text: "1.0");

  List<String> favorites = [];
  List<Map<String, String>> history = [];

  // Data maps
  final List<String> topics = ["Geometry", "Motion", "Thermo", "Electronics", "Digital"];
  final Map<String, IconData> topicIcons = {
    "Geometry": Icons.architecture, "Motion": Icons.directions_run, "Thermo": Icons.whatshot, "Electronics": Icons.memory, "Digital": Icons.data_usage,
  };
  final List<Color> topicColors = [
    const Color(0xFF007AFF), const Color(0xFF34C759), const Color(0xFFFF9500), const Color(0xFFAF52DE), const Color(0xFFFF2D55),
  ];

  final Map<String, List<String>> sections = {
    "Geometry": ["Length", "Area", "Volume", "Mass"],
    "Motion": ["Time", "Speed", "Acceleration", "Angle"],
    "Thermo": ["Temperature", "Pressure", "Energy", "Power"],
    "Electronics": ["Voltage", "Current", "Resistance", "Capacitance"],
    "Digital": ["Frequency", "Data Size", "Data Rate", "Currency"]
  };

  final Map<String, IconData> sectionIcons = {
    "Length": Icons.straighten, "Area": Icons.layers, "Volume": Icons.view_in_ar, "Mass": Icons.fitness_center,
    "Time": Icons.schedule, "Speed": Icons.speed, "Acceleration": Icons.trending_up, "Angle": Icons.text_rotation_angleup,
    "Temperature": Icons.thermostat, "Pressure": Icons.compress, "Energy": Icons.bolt, "Power": Icons.ev_station,
    "Voltage": Icons.electric_bolt, "Current": Icons.waves, "Resistance": Icons.mediation, "Capacitance": Icons.battery_full,
    "Frequency": Icons.rss_feed, "Data Size": Icons.storage, "Data Rate": Icons.wifi_tethering, "Currency": Icons.payments
  };

  final Map<String, String> siDefaults = {
    "Length": "m", "Area": "m²", "Volume": "m³", "Mass": "kg", "Time": "sec",
    "Speed": "m/s", "Acceleration": "m/s²", "Angle": "degree", "Temperature": "°C",
    "Pressure": "Pa", "Energy": "J", "Power": "W", "Voltage": "V", "Current": "A",
    "Resistance": "Ω", "Capacitance": "F", "Frequency": "Hz", "Data Size": "byte",
    "Data Rate": "bps", "Currency": "USD"
  };

  final Map<String, Map<String, double>> unitData = {
    "Length": {"m": 1.0, "km": 1000.0, "cm": 0.01, "mm": 0.001, "dm": 0.1, "dam": 10.0, "hm": 100.0, "nm": 1e-9, "µm": 1e-6, "pm": 1e-12, "Å": 1e-10, "mile": 1609.34, "ft": 0.3048, "in": 0.0254, "yd": 0.9144, "nmi": 1852.0, "fathom": 1.8288, "rod": 5.029, "chain": 20.116, "furlong": 201.16, "league": 4828.03},
    "Area": {"m²": 1.0, "km²": 1e6, "cm²": 1e-4, "mm²": 1e-6, "dm²": 0.01, "hectare": 10000.0, "acre": 4046.86, "mi²": 2.59e6, "ft²": 0.0929, "in²": 0.000645, "yd²": 0.836},
    "Volume": {"m³": 1.0, "L": 0.001, "ml": 1e-6, "cl": 1e-5, "dl": 1e-4, "hL": 0.1, "cm³": 1e-6, "mm³": 1e-9, "dm³": 0.001, "ft³": 0.0283, "in³": 1.638e-5, "yd³": 0.764, "gal": 0.00378, "gal_uk": 0.00454, "qt": 0.000946, "pt": 0.000473, "cup": 0.00024, "fl oz": 2.957e-5, "barrel": 0.1589},
    "Mass": {"kg": 1.0, "g": 0.001, "mg": 1e-6, "µg": 1e-9, "tonne": 1000.0, "lb": 0.4535, "oz": 0.0283, "stone": 6.35, "grain": 6.479e-5, "carat": 0.0002, "slug": 14.59},
    "Time": {"sec": 1.0, "min": 60.0, "hr": 3600.0, "day": 86400.0, "week": 604800.0, "month": 2.628e6, "year": 3.154e7, "ms": 0.001, "µs": 1e-6, "ns": 1e-9, "decade": 3.154e8, "century": 3.154e9},
    "Speed": {"m/s": 1.0, "km/h": 0.2777, "mph": 0.447, "knot": 0.514, "mach": 343.0, "ft/s": 0.3048},
    "Acceleration": {"m/s²": 1.0, "g": 9.806, "ft/s²": 0.3048, "gal": 0.01},
    "Angle": {"degree": 1.0, "radian": 57.295, "grad": 0.9, "arcmin": 0.0166, "arcsec": 0.00027, "turn": 360.0},
    "Temperature": {"°C": 1.0, "°F": 1.0, "K": 1.0, "°R": 1.0, "°Re": 1.0},
    "Pressure": {"Pa": 1.0, "kPa": 1000.0, "MPa": 1e6, "bar": 1e5, "mbar": 100.0, "atm": 101325.0, "psi": 6894.7, "torr": 133.32, "mmHg": 133.32, "inHg": 3386.38},
    "Energy": {"J": 1.0, "kJ": 1000.0, "MJ": 1e6, "GJ": 1e9, "cal": 4.184, "kcal": 4184.0, "kWh": 3.6e6, "BTU": 1055.0},
    "Power": {"W": 1.0, "kW": 1000.0, "MW": 1e6, "hp": 745.7, "TR": 3516.8, "dBm": 1.0},
    "Voltage": {"V": 1.0, "mV": 0.001, "kV": 1000.0, "µV": 1e-6, "MV": 1e6},
    "Current": {"A": 1.0, "mA": 0.001, "µA": 1e-6, "kA": 1000.0, "MA": 1e6},
    "Resistance": {"Ω": 1.0, "mΩ": 0.001, "kΩ": 1000.0, "MΩ": 1e6, "GΩ": 1e9},
    "Capacitance": {"F": 1.0, "mF": 0.001, "µF": 1e-6, "nF": 1e-9, "pF": 1e-12},
    "Frequency": {"Hz": 1.0, "kHz": 1000.0, "MHz": 1e6, "GHz": 1e9, "rpm": 0.0166},
    "Data Size": {"byte": 1.0, "bit": 0.125, "KB": 1024.0, "MB": 1.048e6, "GB": 1.073e9, "TB": 1.099e12, "PB": 1.125e15},
    "Data Rate": {"bps": 1.0, "kbps": 1000.0, "Mbps": 1e6, "Gbps": 1e9, "B/s": 8.0, "MB/s": 8e6},
  };

  final Map<String, String> fullNames = {
    "USD": "US Dollar", "EUR": "Euro", "INR": "Indian Rupee", "GBP": "British Pound", "JPY": "Japanese Yen",
    "CNY": "Chinese Yuan", "AUD": "Australian Dollar", "CAD": "Canadian Dollar", "CHF": "Swiss Franc",
    "SGD": "Singapore Dollar", "AED": "UAE Dirham", "SAR": "Saudi Riyal", "HKD": "Hong Kong Dollar",
    "KRW": "S. Korean Won", "BRL": "Brazilian Real", "m": "Meter", "kg": "Kilogram", "Pa": "Pascal", "V": "Volt"
  };

  @override
  void initState() {
    super.initState();
    _loadFavorites();
    _loadHistory();
    fetchCurrency();
  }

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => favorites = prefs.getStringList('my_favs') ?? []);
  }

  Future<void> _saveFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('my_favs', favorites);
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final String? historyString = prefs.getString('my_history_json');
    if (historyString != null) {
      setState(() {
        List<dynamic> decoded = json.decode(historyString);
        history = decoded.map((item) => Map<String, String>.from(item)).toList();
      });
    }
  }

  Future<void> _saveHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('my_history_json', json.encode(history));
  }

  Future<void> fetchCurrency() async {
    setState(() { isLoadingCurrency = true; isOffline = false; });
    try {
      final response = await http.get(Uri.parse("https://open.er-api.com/v6/latest/USD")).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final rates = Map<String, dynamic>.from(data["rates"]);
        List<String> top15 = ["USD","EUR","INR","GBP","JPY","CNY","AUD","CAD","CHF","SGD","AED","SAR","HKD","KRW","BRL"];
        Map<String, double> filtered = {};
        for (var code in top15) { if (rates.containsKey(code)) filtered[code] = rates[code].toDouble(); }
        setState(() { currencyRates = filtered; isLoadingCurrency = false; });
      } else {
        setState(() { isLoadingCurrency = false; isOffline = true; });
      }
    } catch (e) {
      setState(() { isLoadingCurrency = false; isOffline = true; });
    }
  }

  void addToHistory(String from, String to, String val, String res, String section) {
    setState(() {
      history.insert(0, {'from': from, 'to': to, 'val': val, 'res': res, 'sec': section});
      if (history.length > 10) history.removeLast();
    });
    _saveHistory();
  }

  void toggleFavorite(String section, String from, String to) {
    String combo = "$section|$from|$to";
    setState(() {
      if (favorites.contains(combo)) favorites.remove(combo);
      else favorites.add(combo);
    });
    _saveFavorites();
  }

  void restoreCalculation(String section, String from, String to, String val) {
    int foundTopic = -1; int foundSection = -1;
    sections.forEach((topic, secList) {
      if (secList.contains(section)) {
        foundTopic = topics.indexOf(topic);
        foundSection = secList.indexOf(section);
      }
    });
    if (foundTopic != -1 && foundSection != -1) {
      setState(() {
        topicIdx = foundTopic; sectionIdx = foundSection; fromUnit = from;
        inputValue = double.tryParse(val) ?? 1.0; _controller.text = val; _navIdx = 0;
      });
    }
  }

  double calculateResult(String currentSec, String symbol, Map<String, double> units) {
    if (currentSec == "Temperature") return convertTemp(inputValue, fromUnit!, symbol);
    if (currentSec == "Currency") {
      if (units.isEmpty) return 0.0;
      double baseValue = (units[fromUnit] ?? 1.0) == 0 ? 0 : inputValue / units[fromUnit]!;
      return baseValue * (units[symbol] ?? 1.0);
    }
    return (inputValue * (units[fromUnit] ?? 1.0)) / (units[symbol] ?? 1.0);
  }

  double convertTemp(double val, String from, String to) {
    double c;
    if (from == "°C") c = val;
    else if (from == "°F") c = (val - 32) * 5 / 9;
    else if (from == "K") c = val - 273.15;
    else if (from == "°R") c = (val - 491.67) * 5 / 9;
    else c = (val / 0.8);
    if (to == "°C") return c;
    if (to == "°F") return (c * 9 / 5) + 32;
    if (to == "K") return c + 273.15;
    if (to == "°R") return (c + 273.15) * 9 / 5;
    return c * 0.8;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(child: _buildBody()),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Banner Ad at the very bottom
          const BannerAdWidget(),
          
          BottomNavigationBar(
            currentIndex: _navIdx,
            type: BottomNavigationBarType.fixed,
            onTap: (i) => setState(() => _navIdx = i),
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: "Home"),
              BottomNavigationBarItem(icon: Icon(Icons.star_outline), activeIcon: Icon(Icons.star), label: "Favorites"),
              BottomNavigationBarItem(icon: Icon(Icons.history), label: "History"),
              BottomNavigationBarItem(icon: Icon(Icons.settings_outlined), activeIcon: Icon(Icons.settings), label: "Settings"),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    switch (_navIdx) {
      case 1: return _buildFavorites();
      case 2: return _buildHistory();
      case 3: return _buildSettings();
      default: return _buildConverter();
    }
  }

  Widget _buildConverter() {
    String currentSec = sections[topics[topicIdx]]![sectionIdx];
    var unitsMap = currentSec == "Currency" ? currencyRates : (unitData[currentSec] ?? {"Unit": 1.0});
    fromUnit ??= siDefaults[currentSec] ?? (unitsMap.isNotEmpty ? unitsMap.keys.first : null);
    Color activeColor = topicColors[topicIdx];
    bool isDark = widget.currentMode == ThemeMode.dark;

    List<String> sortedKeys = unitsMap.keys.toList();
    sortedKeys.sort((a, b) {
      bool aFav = favorites.contains("$currentSec|$fromUnit|$a");
      bool bFav = favorites.contains("$currentSec|$fromUnit|$b");
      if (aFav && !bFav) return -1;
      if (!aFav && bFav) return 1;
      return 0;
    });

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 15, bottom: 5),
          child: Text("SMART UNIT CONVERTER", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 4, color: activeColor)),
        ),
        _buildTopicBar(activeColor),
        _buildSectionBar(activeColor),
        Expanded(
          flex: 4,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            color: activeColor.withOpacity(0.04),
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 20),
                  if (currentSec == "Currency" && isLoadingCurrency)
                    const Padding(padding: EdgeInsets.only(bottom: 20), child: SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(width: 48),
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          onChanged: (v) => setState(() => inputValue = double.tryParse(v) ?? 0),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 70, fontWeight: FontWeight.w300, color: isDark ? Colors.white : Colors.black, letterSpacing: -2),
                          decoration: InputDecoration(border: InputBorder.none, hintText: "1.0", hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.black26)),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.content_paste, color: activeColor.withOpacity(0.5)),
                        onPressed: () async {
                          ClipboardData? data = await Clipboard.getData('text/plain');
                          if (data?.text != null) {
                            String filtered = data!.text!.replaceAll(RegExp(r'[^0-9.]'), '');
                            if (filtered.isNotEmpty) {
                              setState(() { _controller.text = filtered; inputValue = double.tryParse(filtered) ?? 0; });
                            }
                          }
                        },
                      ),
                    ],
                  ),
                  if (currentSec == "Currency" && isOffline)
                    const Text("Connect to Internet", style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                  if (fromUnit != null) _buildUnitDropdown(unitsMap, activeColor),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          flex: 6,
          child: (currentSec == "Currency" && isOffline)
          ? Center(child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.cloud_off, size: 40, color: Colors.grey),
                const SizedBox(height: 10),
                const Text("Offline: Cannot load rates", style: TextStyle(color: Colors.grey)),
                TextButton(onPressed: fetchCurrency, child: const Text("Retry"))
              ],
            ))
          : ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: sortedKeys.length,
              itemBuilder: (context, i) {
                String symbol = sortedKeys[i];
                double result = calculateResult(currentSec, symbol, unitsMap);
                return _buildResultRow(symbol, result, activeColor, currentSec);
              },
            ),
        ),
      ],
    );
  }

  Widget _buildTopicBar(Color activeColor) {
    bool isDark = widget.currentMode == ThemeMode.dark;
    return Container(
      height: 85,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      child: Row(
        children: List.generate(topics.length, (i) {
          bool isActive = topicIdx == i;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() { topicIdx = i; sectionIdx = 0; fromUnit = null; }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(color: isActive ? topicColors[i] : (isDark ? Colors.white10 : Colors.black.withOpacity(0.05)), borderRadius: BorderRadius.circular(15)),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(topicIcons[topics[i]], size: 22, color: isActive ? Colors.black : (isDark ? Colors.white38 : Colors.black38)),
                  const SizedBox(height: 6),
                  Text(topics[i], style: TextStyle(fontSize: 10, fontWeight: isActive ? FontWeight.bold : FontWeight.normal, color: isActive ? Colors.black : (isDark ? Colors.white70 : Colors.black87))),
                ]),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildSectionBar(Color activeColor) {
    List<String> secList = sections[topics[topicIdx]]!;
    bool isDark = widget.currentMode == ThemeMode.dark;
    return Container(
      height: 75,
      decoration: BoxDecoration(color: activeColor.withOpacity(0.08), border: Border.symmetric(horizontal: BorderSide(color: activeColor.withOpacity(0.1), width: 0.5))),
      child: Row(children: List.generate(secList.length, (i) {
        bool isActive = sectionIdx == i;
        return Expanded(
          child: InkWell(
            onTap: () => setState(() { sectionIdx = i; fromUnit = null; }),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(sectionIcons[secList[i]], size: 20, color: isActive ? activeColor : (isDark ? Colors.white24 : Colors.black26)),
              const SizedBox(height: 6),
              Text(secList[i].toUpperCase(), style: TextStyle(fontSize: 8, letterSpacing: 0.8, fontWeight: isActive ? FontWeight.w900 : FontWeight.w500, color: isActive ? activeColor : (isDark ? Colors.white24 : Colors.black26))),
            ]),
          ),
        );
      })),
    );
  }

  Widget _buildResultRow(String symbol, double val, Color activeColor, String section) {
    bool isDark = widget.currentMode == ThemeMode.dark;
    String formattedVal = val.toStringAsFixed(val < 0.001 ? 6 : 3).replaceAll(RegExp(r"([.]*0+)(?!.*\d)"), "");
    String comboKey = "$section|$fromUnit|$symbol";
    bool isFav = favorites.contains(comboKey);

    return ListTile(
      onLongPress: () {
        Clipboard.setData(ClipboardData(text: formattedVal));
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Copied $formattedVal"), duration: const Duration(seconds: 1)));
      },
      onTap: () {
        addToHistory(fromUnit!, symbol, inputValue.toString(), formattedVal, section);
        HapticFeedback.lightImpact();
      },
      title: Text(fullNames[symbol] ?? symbol, style: TextStyle(color: isDark ? Colors.white.withOpacity(0.4) : Colors.black.withOpacity(0.5), fontSize: 13)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(formattedVal, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w300, color: isDark ? Colors.white : Colors.black)),
          const SizedBox(width: 12),
          Text(symbol, style: TextStyle(fontSize: 11, color: activeColor, fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(isFav ? Icons.star : Icons.star_border, color: isFav ? Colors.amber : (isDark ? Colors.white10 : Colors.black12)),
            onPressed: () => toggleFavorite(section, fromUnit!, symbol),
          )
        ],
      ),
    );
  }

  Widget _buildFavorites() {
    bool isDark = widget.currentMode == ThemeMode.dark;
    return Column(
      children: [
        Padding(padding: const EdgeInsets.all(20), child: Text("Favorites", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black))),
        Expanded(
          child: favorites.isEmpty
            ? const Center(child: Text("No favorites yet", style: TextStyle(color: Colors.grey)))
            : ListView.builder(
                itemCount: favorites.length,
                itemBuilder: (c, i) {
                   var parts = favorites[i].split('|');
                   return ListTile(
                    onTap: () => restoreCalculation(parts[0], parts[1], parts[2], "1.0"),
                    leading: const Icon(Icons.star, color: Colors.amber),
                    title: Text("${parts[0]}: ${parts[1]} ➔ ${parts[2]}", style: TextStyle(color: isDark ? Colors.white : Colors.black)),
                    trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => toggleFavorite(parts[0], parts[1], parts[2])),
                  );
                },
              ),
        ),
      ],
    );
  }

  Widget _buildHistory() {
    bool isDark = widget.currentMode == ThemeMode.dark;
    return Column(
      children: [
        Padding(padding: const EdgeInsets.all(20), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text("History (Last 10)", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
          if (history.isNotEmpty) IconButton(icon: const Icon(Icons.delete_sweep, color: Colors.redAccent), onPressed: () { setState(() => history.clear()); _saveHistory(); })
        ])),
        Expanded(
          child: history.isEmpty
            ? const Center(child: Text("No history found", style: TextStyle(color: Colors.grey)))
            : ListView.builder(
                itemCount: history.length,
                itemBuilder: (c, i) => ListTile(
                  onTap: () => restoreCalculation(history[i]['sec']!, history[i]['from']!, history[i]['to']!, history[i]['val']!),
                  leading: const Icon(Icons.history_toggle_off),
                  title: Text("${history[i]['val']} ${history[i]['from']} = ${history[i]['res']} ${history[i]['to']}", style: TextStyle(color: isDark ? Colors.white : Colors.black)),
                  subtitle: Text(history[i]['sec'] ?? "", style: const TextStyle(fontSize: 10, color: Colors.grey)),
                ),
              ),
        ),
      ],
    );
  }

  Widget _buildSettings() {
    bool isDark = widget.currentMode == ThemeMode.dark;
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Settings", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
          const SizedBox(height: 30),
          ListTile(
            title: Text(isDark ? "Dark Mode 🌙" : "Light Mode ☀️", style: TextStyle(color: isDark ? Colors.white : Colors.black)),
            trailing: Switch(value: isDark, onChanged: (v) => widget.onThemeChanged(v)),
          ),
          const Divider(height: 40),
          const Text("Important Information", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue)),
          const SizedBox(height: 10),
          Card(
            color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
            child: Padding(
              padding: const EdgeInsets.all(15.0),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.info_outline, color: Colors.blue),
                    title: Text("Precision Note", style: TextStyle(color: isDark ? Colors.white : Colors.black)),
                    subtitle: Text("Scientific calculations use 6 decimal places for high precision.", style: TextStyle(color: isDark ? Colors.white70 : Colors.black54)),
                  ),
                  ListTile(
                    leading: const Icon(Icons.verified_user_outlined, color: Colors.green),
                    title: Text("Version", style: TextStyle(color: isDark ? Colors.white : Colors.black)),
                    subtitle: Text("v1.0.5 - Pro Edition", style: TextStyle(color: isDark ? Colors.white70 : Colors.black54)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnitDropdown(Map<String, double> units, Color activeColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(border: Border.all(color: activeColor.withOpacity(0.2)), borderRadius: BorderRadius.circular(12)),
      child: DropdownButton<String>(
        value: fromUnit,
        underline: const SizedBox(),
        dropdownColor: widget.currentMode == ThemeMode.dark ? Colors.black : Colors.white,
        items: units.keys.map((u) => DropdownMenuItem(value: u, child: Text(fullNames[u] ?? u, style: TextStyle(fontSize: 14, color: activeColor)))).toList(),
        onChanged: (v) => setState(() { fromUnit = v; }),
      ),
    );
  }
}