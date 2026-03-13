import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
    _loadSettings();
  }

  Future<void> _loadSettings() async {
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
    if (!kIsWeb) { _loadAd(); }
  }

  void _loadAd() {
    _bannerAd = BannerAd(
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
    if (kIsWeb || !_isLoaded || _bannerAd == null) return const SizedBox.shrink();
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

  // CHANGED: Use Maps to store data for each specific section
  Map<String, String> sectionInputValues = {};
  Map<String, String> sectionFromUnits = {};

  Map<String, double> currencyRates = {};
  bool isLoadingCurrency = false;
  bool isOffline = false;
  final TextEditingController _controller = TextEditingController(text: "1");

  int decimalPlaces = 3;
  bool useScientific = false;
  String selectedLang = "English";
  final List<String> languages = ["English", "Hindi", "Spanish", "French", "Arabic", "Chinese", "Russian", "Portuguese", "German"];

  Map<String, Map<String, String>> localizedText = {
    "English": {
      "home": "Home", "fav": "Favorites", "hist": "History", "set": "Settings", "title": "SMART UNIT CONVERTER",
      "Geometry": "Geometry", "Motion": "Motion", "Thermo": "Thermo", "Electronics": "Electronics", "Digital": "Digital", "Binary Lab": "Binary Lab",
      "Length": "Length", "Area": "Area", "Volume": "Volume", "Mass": "Mass", "Time": "Time", "Speed": "Speed", "Acceleration": "Acceleration", "Angle": "Angle",
      "Temperature": "Temperature", "Pressure": "Pressure", "Energy": "Energy", "Power": "Power", "Voltage": "Voltage", "Current": "Current", "Resistance": "Resistance", "Capacitance": "Capacitance",
      "Frequency": "Frequency", "Data Size": "Data Size", "Data Rate": "Data Rate", "Currency": "Currency",
      "Number Systems": "Number Systems", "Logarithm": "Logarithm", "Decibel": "Decibel", "Binary Tools": "Binary Tools",
      "dark_m": "Dark Mode 🌙", "light_m": "Light Mode ☀️", "lang": "Language", "prec": "Decimal Precision", "info": "Information", "note": "Precision Note", "ver": "Version", "sel": "Selected", "places": "places", "no_fav": "No favorites yet", "no_hist": "No history found", "copy": "Copied", "offline": "Offline: Cannot load rates", "retry": "Retry", "connect": "Connect to Internet",
      "sci": "Scientific Notation", "export": "Export History", "csv_msg": "History copied as CSV", "reset": "Reset App State", "reset_sub": "Clears all saved states for sections"
    },
    "Hindi": {
      "home": "होम", "fav": "पसंदीदा", "hist": "इतिहास", "set": "सेटिंग्स", "title": "स्मार्ट यूनिट कन्वर्टर",
      "Geometry": "ज्यामिति", "Motion": "गति", "Thermo": "ताप", "Electronics": "इलेक्ट्रॉनिक्स", "Digital": "डिजिटल", "Binary Lab": "बाइनरी लैब",
      "Length": "लंबाई", "Area": "क्षेत्रफल", "Volume": "आयतन", "Mass": "द्रव्यमान", "Time": "समय", "Speed": "गति", "Acceleration": "त्वरण", "Angle": "कोण",
      "Temperature": "तापमान", "Pressure": "दबाव", "Energy": "ऊर्जा", "Power": "शक्ति", "Voltage": "वोल्टेज", "Current": "करंट", "Resistance": "प्रतिरोध", "Capacitance": "धारिता",
      "Frequency": "आवृत्ति", "Data Size": "डेटा आकार", "Data Rate": "डेटा दर", "Currency": "मुद्रा",
      "Number Systems": "संख्या प्रणाली", "Logarithm": "लघुगणक", "Decibel": "डेसीबल", "Binary Tools": "बाइनरी टूल्स",
      "dark_m": "डार्क मोड 🌙", "light_m": "लाइट मोड ☀️", "lang": "भाषा", "prec": "दशमलव परिशुद्धता", "info": "सूचना", "note": "परिशुद्धता नोट", "ver": "संस्करण", "sel": "चयनित", "places": "स्थान", "no_fav": "अभी तक कोई पसंदीदा नहीं", "no_hist": "कोई इतिहास नहीं मिला", "copy": "कॉपी किया गया", "offline": "ऑफलाइन: दरें लोड नहीं की जा सकतीं", "retry": "पुनः प्रयास करें", "connect": "इंटरनेट से जुड़ें",
      "sci": "वैज्ञानिक अंकन", "export": "इतिहास निर्यात करें", "csv_msg": "इतिहास CSV के रूप में कॉपी किया गया", "reset": "ऐप स्थिति रीसेट करें", "reset_sub": "सभी सहेजी गई स्थितियों को साफ़ करता है"
    },
    "Spanish": {
      "home": "Inicio", "fav": "Favoritos", "hist": "Historial", "set": "Ajustes", "title": "CONVERSOR DE UNIDADES",
      "Geometry": "Geometría", "Motion": "Movimiento", "Thermo": "Termo", "Electronics": "Electrónica", "Digital": "Digital", "Binary Lab": "Lab Binario",
      "Length": "Longitud", "Area": "Área", "Volume": "Volumen", "Mass": "Masa", "Time": "Tiempo", "Speed": "Velocidad", "Acceleration": "Aceleración", "Angle": "Ángulo",
      "Temperature": "Temperatura", "Pressure": "Presión", "Energy": "Energía", "Power": "Potencia", "Voltage": "Voltaje", "Current": "Corriente", "Resistance": "Resistencia", "Capacitance": "Capacitancia",
      "Frequency": "Frecuencia", "Data Size": "Tamaño de datos", "Data Rate": "Tasa de datos", "Currency": "Moneda",
      "Number Systems": "Sistemas Numéricos", "Logarithm": "Logaritmo", "Decibel": "Decibelio", "Binary Tools": "Herramientas Binarias",
      "dark_m": "Modo Oscuro 🌙", "light_m": "Modo Claro ☀️", "lang": "Idioma", "prec": "Precisión decimal", "info": "Información", "note": "Nota de precisión", "ver": "Versión", "sel": "Seleccionado", "places": "lugares", "no_fav": "Sin favoritos", "no_hist": "Sin historial", "copy": "Copiado", "offline": "Sin conexión", "retry": "Reintentar", "connect": "Conéctate a Internet",
      "sci": "Notación científica", "export": "Exportar historial", "csv_msg": "Historial copiado", "reset": "Restablecer aplicación", "reset_sub": "Borra los estados guardados"
    },
    "French": {
      "home": "Accueil", "fav": "Favoris", "hist": "Historique", "set": "Paramètres", "title": "CONVERTISSEUR INTELLIGENT",
      "Geometry": "Géométrie", "Motion": "Mouvement", "Thermo": "Thermo", "Electronics": "Électronique", "Digital": "Numérique", "Binary Lab": "Lab Binaire",
      "Length": "Longueur", "Area": "Surface", "Volume": "Volume", "Mass": "Masse", "Time": "Temps", "Speed": "Vitesse", "Acceleration": "Accélération", "Angle": "Angle",
      "Temperature": "Température", "Pressure": "Pression", "Energy": "Énergie", "Power": "Puissance", "Voltage": "Tension", "Current": "Courant", "Resistance": "Résistance", "Capacitance": "Capacité",
      "Frequency": "Fréquence", "Data Size": "Taille des données", "Data Rate": "Débit de données", "Currency": "Devise",
      "Number Systems": "Systèmes Numériques", "Logarithm": "Logarithme", "Decibel": "Décibel", "Binary Tools": "Outils Binaires",
      "dark_m": "Mode sombre 🌙", "light_m": "Mode clair ☀️", "lang": "Langue", "prec": "Précision décimale", "info": "Information", "note": "Note de précision", "ver": "Version", "sel": "Sélectionné", "places": "décimales", "no_fav": "Pas de favoris", "no_hist": "Aucun historique", "copy": "Copié", "offline": "Hors ligne", "retry": "Réessayer", "connect": "Connectez-vous à Internet",
      "sci": "Notation scientifique", "export": "Exporter l'historique", "csv_msg": "Historique copié", "reset": "Réinitialiser l'application", "reset_sub": "Efface tous les états enregistrés"
    },
    "Arabic": {
      "home": "الرئيسية", "fav": "المفضلة", "hist": "السجل", "set": "الإعدادات", "title": "محول الوحدات الذكي",
      "Geometry": "الهندسة", "Motion": "الحركة", "Thermo": "الحرارة", "Electronics": "الإلكترونيات", "Digital": "الرقمية", "Binary Lab": "مختبر الثنائي",
      "Length": "الطول", "Area": "المساحة", "Volume": "الحجم", "Mass": "الكتلة", "Time": "الوقت", "Speed": "السرعة", "Acceleration": "التسارع", "Angle": "الزاوية",
      "Temperature": "الحرارة", "Pressure": "الضغط", "Energy": "الطاقة", "Power": "القدرة", "Voltage": "الجهد", "Current": "التيار", "Resistance": "المقاومة", "Capacitance": "المواساة",
      "Frequency": "التردد", "Data Size": "حجم البيانات", "Data Rate": "معدل البيانات", "Currency": "العملة",
      "Number Systems": "أنظمة الأعداد", "Logarithm": "اللوغاريتم", "Decibel": "ديسيبل", "Binary Tools": "أدوات الثنائي",
      "dark_m": "الوضع الداكن 🌙", "light_m": "الوضع الفاتح ☀️", "lang": "اللغة", "prec": "دقة الكسور", "info": "معلومات", "note": "ملاحظة الدقة", "ver": "الإصدار", "sel": "محدد", "places": "مراتب", "no_fav": "لا توجد مفضلات", "no_hist": "لا يوجد سجل", "copy": "تم النسخ", "offline": "غير متصل", "retry": "إعادة المحاولة", "connect": "اتصل بالإنترنت",
      "sci": "الترميز العلمي", "export": "تصدير السجل", "csv_msg": "تم نسخ السجل", "reset": "إعادة ضبط التطبيق", "reset_sub": "مسح جميع الحالات المحفوظة"
    },
    "Chinese": {
      "home": "首页", "fav": "收藏夹", "hist": "历史", "set": "设置", "title": "智能单位转换器",
      "Geometry": "几何", "Motion": "运动", "Thermo": "热学", "Electronics": "电子", "Digital": "数字", "Binary Lab": "二进制实验室",
      "Length": "长度", "Area": "面积", "Volume": "体积", "Mass": "质量", "Time": "时间", "Speed": "速度", "Acceleration": "加速度", "Angle": "角度",
      "Temperature": "温度", "Pressure": "压力", "Energy": "能量", "Power": "功率", "Voltage": "电压", "Current": "电流", "Resistance": "电阻", "Capacitance": "电容",
      "Frequency": "频率", "Data Size": "数据大小", "Data Rate": "数据速率", "Currency": "货币",
      "Number Systems": "数制系统", "Logarithm": "对数", "Decibel": "分贝", "Binary Tools": "二进制工具",
      "dark_m": "深色模式 🌙", "light_m": "浅色模式 ☀️", "lang": "语言", "prec": "十进制精度", "info": "信息", "note": "精度说明", "ver": "版本", "sel": "已选", "places": "位", "no_fav": "暂无收藏", "no_hist": "未发现历史", "copy": "已复制", "offline": "离线", "retry": "重试", "connect": "连接到互联网",
      "sci": "科学计数法", "export": "导出历史", "csv_msg": "历史记录已复制", "reset": "重置应用状态", "reset_sub": "清除所有保存的状态"
    },
    "Russian": {
      "home": "Главная", "fav": "Избранное", "hist": "История", "set": "Настройки", "title": "УМНЫЙ КОНВЕРТЕР",
      "Geometry": "Геометрия", "Motion": "Движение", "Thermo": "Термо", "Electronics": "Электроника", "Digital": "Цифровой", "Binary Lab": "Двоичная лаб",
      "Length": "Длина", "Area": "Площадь", "Volume": "Объем", "Mass": "Масса", "Time": "Время", "Speed": "Скорость", "Acceleration": "Ускорение", "Angle": "Угол",
      "Temperature": "Температура", "Pressure": "Давление", "Energy": "Энергия", "Power": "Мощность", "Voltage": "Напряжение", "Current": "Ток", "Resistance": "Сопротивление", "Capacitance": "Емкость",
      "Frequency": "Частота", "Data Size": "Размер данных", "Data Rate": "Скорость данных", "Currency": "Валюта",
      "Number Systems": "Системы счисления", "Logarithm": "Логарифм", "Decibel": "Децибел", "Binary Tools": "Двоичные инструменты",
      "dark_m": "Темный режим 🌙", "light_m": "Светлый режим ☀️", "lang": "Язык", "prec": "Точность", "info": "Информация", "note": "О точности", "ver": "Версия", "sel": "Выбрано", "places": "знаков", "no_fav": "Нет избранного", "no_hist": "История пуста", "copy": "Скопировано", "offline": "Оффлайн", "retry": "Повторить", "connect": "Подключитесь к интернету",
      "sci": "Научный формат", "export": "Экспорт истории", "csv_msg": "История скопирована", "reset": "Сброс приложения", "reset_sub": "Очищает все сохраненные данные"
    },
    "Portuguese": {
      "home": "Início", "fav": "Favoritos", "hist": "Histórico", "set": "Configurações", "title": "CONVERSOR INTELIGENTE",
      "Geometry": "Geometria", "Motion": "Movimento", "Thermo": "Termo", "Electronics": "Eletrônicos", "Digital": "Digital", "Binary Lab": "Lab Binário",
      "Length": "Comprimento", "Area": "Área", "Volume": "Volume", "Mass": "Massa", "Time": "Tempo", "Speed": "Velocidade", "Acceleration": "Aceleração", "Angle": "Ângulo",
      "Temperature": "Temperatura", "Pressure": "Pressão", "Energy": "Energia", "Power": "Potência", "Voltage": "Voltagem", "Current": "Corrente", "Resistance": "Resistência", "Capacitância": "Capacitância",
      "Frequency": "Frequência", "Data Size": "Tamanho de dados", "Data Rate": "Taxa de dados", "Currency": "Moeda",
      "Number Systems": "Sistemas Numéricos", "Logarithm": "Logaritmo", "Decibel": "Decibel", "Binary Tools": "Ferramentas Binárias",
      "dark_m": "Modo Escuro 🌙", "light_m": "Modo Claro ☀️", "lang": "Idioma", "prec": "Precisão decimal", "info": "Informação", "note": "Nota de precisão", "ver": "Versão", "sel": "Selecionado", "places": "casas", "no_fav": "Sem favoritos", "no_hist": "Sem histórico", "copy": "Copiado", "offline": "Offline", "retry": "Repetir", "connect": "Conecte-se à Internet",
      "sci": "Notação científica", "export": "Exportar histórico", "csv_msg": "Histórico copiado", "reset": "Redefinir aplicativo", "reset_sub": "Limpa todos os estados salvos"
    },
    "German": {
      "home": "Start", "fav": "Favoriten", "hist": "Verlauf", "set": "Einstellungen", "title": "SMARTER KONVERTER",
      "Geometry": "Geometrie", "Motion": "Bewegung", "Thermo": "Thermo", "Electronics": "Elektronik", "Digital": "Digital", "Binary Lab": "Binär-Labor",
      "Length": "Länge", "Area": "Fläche", "Volume": "Volumen", "Mass": "Masse", "Time": "Zeit", "Speed": "Geschwindigkeit", "Acceleration": "Beschleunigung", "Angle": "Winkel",
      "Temperature": "Temperatur", "Pressure": "Druck", "Energy": "Energie", "Power": "Leistung", "Voltage": "Spannung", "Current": "Stromstärke", "Resistance": "Widerstand", "Capacitance": "Kapazität",
      "Frequency": "Frequenz", "Data Size": "Datengröße", "Data Rate": "Datenrate", "Currency": "Währung",
      "Number Systems": "Zahlensysteme", "Logarithm": "Logarithmus", "Decibel": "Dezibel", "Binary Tools": "Binär-Werkzeuge",
      "dark_m": "Dunkelmodus 🌙", "light_m": "Hellmodus ☀️", "lang": "Sprache", "prec": "Dezimalstellen", "info": "Information", "note": "Präzisionshinweis", "ver": "Version", "sel": "Ausgewählt", "places": "Stellen", "no_fav": "Noch keine Favoriten", "no_hist": "Kein Verlauf", "copy": "Kopiert", "offline": "Offline", "retry": "Wiederholen", "connect": "Mit Internet verbinden",
      "sci": "Wissensch. Notation", "export": "Verlauf exportieren", "csv_msg": "Verlauf kopiert", "reset": "App zurücksetzen", "reset_sub": "Löscht alle gespeicherten Zustände"
    }
  };

  String t(String key) => localizedText[selectedLang]?[key] ?? localizedText["English"]![key] ?? key;

  List<String> favorites = [];
  List<Map<String, String>> history = [];

  final List<String> topics = ["Geometry", "Motion", "Thermo", "Binary Lab", "Digital"];
  final Map<String, IconData> topicIcons = {
    "Geometry": Icons.architecture, "Motion": Icons.directions_run, "Thermo": Icons.whatshot, "Electronics": Icons.memory, "Digital": Icons.data_usage, "Binary Lab": Icons.code,
  };
  final List<Color> topicColors = [
    const Color(0xFF007AFF), const Color(0xFF34C759), const Color.fromARGB(255, 255, 149, 0), const Color(0xFFAF52DE), const Color(0xFFFF2D55), const Color(0xFF00BFFF),
  ];

  final Map<String, List<String>> sections = {
    "Geometry": ["Length", "Area", "Volume", "Mass"],
    "Motion": ["Time", "Speed", "Acceleration", "Angle"],
    "Thermo": ["Temperature", "Pressure", "Energy", "Power"],
    "Electronics": ["Voltage", "Current", "Resistance", "Capacitance"],
    "Digital": ["Frequency", "Data Size", "Data Rate", "Currency"],
    "Binary Lab": ["Number Systems", "Logarithm", "Decibel", "Binary Tools"]
  };

  final Map<String, IconData> sectionIcons = {
    "Length": Icons.straighten, "Area": Icons.layers, "Volume": Icons.view_in_ar, "Mass": Icons.fitness_center,
    "Time": Icons.schedule, "Speed": Icons.speed, "Acceleration": Icons.trending_up, "Angle": Icons.text_rotation_angleup,
    "Temperature": Icons.thermostat, "Pressure": Icons.compress, "Energy": Icons.bolt, "Power": Icons.ev_station,
    "Voltage": Icons.electric_bolt, "Current": Icons.waves, "Resistance": Icons.mediation, "Capacitance": Icons.battery_full,
    "Frequency": Icons.rss_feed, "Data Size": Icons.storage, "Data Rate": Icons.wifi_tethering, "Currency": Icons.payments,
    "Number Systems": Icons.pin, "Logarithm": Icons.functions, "Decibel": Icons.volume_up, "Binary Tools": Icons.terminal,
  };

  final Map<String, String> siDefaults = {
    "Length": "m", "Area": "m²", "Volume": "m³", "Mass": "kg", "Time": "sec",
    "Speed": "m/s", "Acceleration": "m/s²", "Angle": "degree", "Temperature": "°C",
    "Pressure": "Pa", "Energy": "J", "Power": "W", "Voltage": "V", "Current": "A",
    "Resistance": "Ω", "Capacitance": "F", "Frequency": "Hz", "Data Size": "byte",
    "Data Rate": "bps", "Currency": "USD",
    "Number Systems": "Decimal", "Logarithm": "log10(x)", "Decibel": "dB", "Binary Tools": "Decimal"
  };

  final Map<String, Map<String, double>> unitData = {
    "Length": {"m": 1.0, "km": 1000.0, "cm": 0.01, "mm": 0.001, "dm": 0.1, "dam": 10.0, "hm": 100.0, "nm": 1e-9, "µm": 1e-6, "pm": 1e-12, "Å": 1e-10, "mile": 1609.34, "ft": 0.3048, "in": 0.0254, "yd": 0.9144, "nmi": 1852.0},
    "Area": {"m²": 1.0, "km²": 1e6, "cm²": 1e-4, "mm²": 1e-6, "dm²": 0.01, "hectare": 10000.0, "acre": 4046.86, "mi²": 2.59e6},
    "Volume": {"m³": 1.0, "L": 0.001, "ml": 1e-6, "cl": 1e-5, "cm³": 1e-6, "gal": 0.00378, "qt": 0.000946, "pt": 0.000473, "cup": 0.00024},
    "Mass": {"kg": 1.0, "g": 0.001, "mg": 1e-6, "tonne": 1000.0, "lb": 0.4535, "oz": 0.0283, "carat": 0.0002},
    "Time": {"sec": 1.0, "min": 60.0, "hr": 3600.0, "day": 86400.0, "week": 604800.0, "ms": 0.001, "year": 3.154e7},
    "Speed": {"m/s": 1.0, "km/h": 0.2777, "mph": 0.447, "knot": 0.514},
    "Acceleration": {"m/s²": 1.0, "g": 9.806, "ft/s²": 0.3048},
    "Angle": {"degree": 1.0, "radian": 57.295, "grad": 0.9, "turn": 360.0},
    "Temperature": {"°C": 1.0, "°F": 1.0, "K": 1.0, "°R": 1.0, "°Re": 1.0},
    "Pressure": {"Pa": 1.0, "kPa": 1000.0, "bar": 1e5, "atm": 101325.0, "psi": 6894.7, "mmHg": 133.32},
    "Energy": {"J": 1.0, "kJ": 1000.0, "cal": 4.184, "kcal": 4184.0, "kWh": 3.6e6, "BTU": 1055.0},
    "Power": {"W": 1.0, "kW": 1000.0, "hp": 745.7},
    "Voltage": {"V": 1.0, "mV": 0.001, "kV": 1000.0},
    "Current": {"A": 1.0, "mA": 0.001, "kA": 1000.0},
    "Resistance": {"Ω": 1.0, "kΩ": 1000.0, "MΩ": 1e6},
    "Capacitance": {"F": 1.0, "µF": 1e-6, "nF": 1e-9, "pF": 1e-12},
    "Frequency": {"Hz": 1.0, "kHz": 1000.0, "MHz": 1e6, "GHz": 1e9},
    "Data Size": {"byte": 1.0, "bit": 0.125, "KB": 1024.0, "MB": 1.048e6, "GB": 1.073e9},
    "Data Rate": {"bps": 1.0, "kbps": 1000.0, "Mbps": 1e6, "Gbps": 1e9},
    "Number Systems": {"Binary": 2, "Octal": 8, "Decimal": 10, "Hexadecimal": 16, "Base 3": 3, "Base 5": 5, "Base 12": 12, "Base 32": 32, "Base 64": 64},
    "Logarithm": {"log10(x)": 10, "ln(x)": 2.718, "log2(x)": 2, "log3(x)": 3, "Antilog10": -10, "Antilog e": -2.718, "Antilog2": -2},
    "Decibel": {"dB": 1, "dBm": 2, "dBW": 3, "dBV": 4, "Power Ratio": 5, "Voltage Ratio": 6, "Current Ratio": 7, "Amplitude Ratio": 8},
    "Binary Tools": {"Decimal": 10, "1's Complement": 1, "2's Complement": 2, "Even Parity": 3, "Odd Parity": 4, "Signed Binary": 5, "Unsigned Binary": 6, "Bit Length": 7, "Bit Count": 8},
  };

  final Map<String, String> fullNames = {
    "USD": "US Dollar", "EUR": "Euro", "INR": "Indian Rupee", "GBP": "British Pound", "JPY": "Japanese Yen",
    "CNY": "Chinese Yuan", "AUD": "Australian Dollar", "CAD": "Canadian Dollar", "CHF": "Swiss Franc",
    "SGD": "Singapore Dollar", "AED": "UAE Dirham", "SAR": "Saudi Riyal", "HKD": "Hong Kong Dollar",
    "KRW": "S. Korean Won", "BRL": "Brazilian Real", "m": "Meter", "kg": "Kilogram", "Pa": "Pascal", "V": "Volt",
    "Binary": "Base 2", "Octal": "Base 8", "Decimal": "Base 10", "Hexadecimal": "Base 16"
  };

  @override
  void initState() {
    super.initState();
    _loadPersistedData();
    fetchCurrency();
  }

  Future<void> _loadPersistedData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      favorites = prefs.getStringList('my_favs') ?? [];
      decimalPlaces = prefs.getInt('decimal_p') ?? 3;
      useScientific = prefs.getBool('use_scientific') ?? false;
      selectedLang = prefs.getString('app_lang') ?? "English";
      
      topicIdx = prefs.getInt('last_topic_idx') ?? 0;
      sectionIdx = prefs.getInt('last_section_idx') ?? 0;

      // Load section-specific memories
      String? inputsJson = prefs.getString('section_inputs_map');
      if (inputsJson != null) {
        sectionInputValues = Map<String, String>.from(json.decode(inputsJson));
      }
      String? unitsJson = prefs.getString('section_units_map');
      if (unitsJson != null) {
        sectionFromUnits = Map<String, String>.from(json.decode(unitsJson));
      }

      _refreshController();

      final String? historyString = prefs.getString('my_history_json');
      if (historyString != null) {
        List<dynamic> decoded = json.decode(historyString);
        history = decoded.map((item) => Map<String, String>.from(item)).toList();
      }
    });
  }

  void _refreshController() {
    String currentSec = sections[topics[topicIdx]]![sectionIdx];
    _controller.text = sectionInputValues[currentSec] ?? "1";
  }

  Future<void> _saveCurrentState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('last_topic_idx', topicIdx);
    await prefs.setInt('last_section_idx', sectionIdx);
    
    // Save the maps as JSON strings to persist memory for all sections
    await prefs.setString('section_inputs_map', json.encode(sectionInputValues));
    await prefs.setString('section_units_map', json.encode(sectionFromUnits));
  }

  Future<void> _resetToDefaults() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('last_topic_idx');
    await prefs.remove('last_section_idx');
    await prefs.remove('section_inputs_map');
    await prefs.remove('section_units_map');

    setState(() {
      topicIdx = 0;
      sectionIdx = 0;
      sectionInputValues.clear();
      sectionFromUnits.clear();
      _controller.text = "1";
    });
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t("reset"))));
    }
  }

  // ... [fetchCurrency, addToHistory, exportHistoryToCSV, toggleFavorite methods remain same]

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
      if (history.length > 100) history.removeLast();
    });
    _saveHistory();
  }
  
  Future<void> _saveHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('my_history_json', json.encode(history));
  }

  Future<void> exportHistoryToCSV() async {
    if (history.isEmpty) return;
    String csvData = "Section,Value,From,Result,To\n";
    for (var entry in history) {
      csvData += "${entry['sec']},${entry['val']},${entry['from']},${entry['res']},${entry['to']}\n";
    }
    await Clipboard.setData(ClipboardData(text: csvData));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t("csv_msg"))));
    }
  }

  void toggleFavorite(String section, String from, String to) {
    String combo = "$section|$from|$to";
    setState(() {
      if (favorites.contains(combo)) favorites.remove(combo);
      else favorites.add(combo);
    });
    _saveFavorites();
  }
  
  Future<void> _saveFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('my_favs', favorites);
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
        topicIdx = foundTopic; 
        sectionIdx = foundSection; 
        sectionFromUnits[section] = from;
        sectionInputValues[section] = val;
        _controller.text = val; 
        _navIdx = 0;
      });
      _saveCurrentState();
    }
  }

  String formatBinaryOutput(dynamic val) {
    if (val is String) return val;
    double dVal = val.toDouble();
    if (useScientific && (dVal >= 10000 || (dVal < 0.001 && dVal != 0))) {
      return dVal.toStringAsExponential(decimalPlaces);
    }
    return dVal.toStringAsFixed(decimalPlaces).replaceAll(RegExp(r"([.]*0+)(?!.*\d)"), "");
  }

  String calculateResultString(String currentSec, String target, Map<String, double> units) {
    String rawInput = _controller.text;
    String? currentFromUnit = sectionFromUnits[currentSec] ?? siDefaults[currentSec];

    try {
      if (currentSec == "Number Systems") {
        try {
          int fromBase = units[currentFromUnit!]!.toInt();
          int toBase = units[target]!.toInt();
          BigInt decimal = BigInt.parse(rawInput, radix: fromBase);
          return decimal.toRadixString(toBase).toUpperCase();
        } catch (e) { return "Invalid Base"; }
      }

      if (currentSec == "Logarithm") {
        double x = double.tryParse(rawInput) ?? 1.0;
        if (target.contains("log") || target == "ln(x)") { if (x <= 0) return "Must be > 0"; }
        if (target == "log10(x)") return (math.log(x) / math.ln10).toStringAsFixed(decimalPlaces);
        if (target == "ln(x)") return math.log(x).toStringAsFixed(decimalPlaces);
        if (target == "log2(x)") return (math.log(x) / math.ln2).toStringAsFixed(decimalPlaces);
        if (target == "Antilog10") return math.pow(10, x).toStringAsFixed(decimalPlaces);
        if (target == "Antilog e") return math.pow(math.e, x).toStringAsFixed(decimalPlaces);
      }

      if (currentSec == "Decibel") {
        double val = double.tryParse(rawInput) ?? 1.0;
        if (target.contains("dB") && val <= 0) return "Ratio must be > 0";
        if (target == "dB (Power)") return (10 * math.log(val) / math.ln10).toStringAsFixed(2);
        if (target == "dB (Voltage)") return (20 * math.log(val) / math.ln10).toStringAsFixed(2);
        if (target == "Power Ratio") return math.pow(10, val / 10).toStringAsFixed(decimalPlaces);
        if (target == "Voltage Ratio") return math.pow(10, val / 20).toStringAsFixed(decimalPlaces);
      }

      if (currentSec == "Binary Tools") {
        try {
          if (target == "1's Complement") return rawInput.replaceAll('0', 'x').replaceAll('1', '0').replaceAll('x', '1');
          if (target == "2's Complement") {
            String ones = rawInput.replaceAll('0', 'x').replaceAll('1', '0').replaceAll('x', '1');
            return (BigInt.parse(ones, radix: 2) + BigInt.one).toRadixString(2);
          }
          if (target == "Even Parity") return (rawInput.replaceAll("0", "").length % 2 == 0) ? "0" : "1";
          if (target == "Odd Parity") return (rawInput.replaceAll("0", "").length % 2 != 0) ? "0" : "1";
          if (target == "Bit Count") return rawInput.replaceAll('0', '').length.toString();
          if (target == "Bit Length") return rawInput.length.toString();
        } catch (e) { return "Invalid Binary"; }
      }
      
      double inputNum = double.tryParse(rawInput) ?? 0.0;
      if (currentSec == "Temperature") return formatBinaryOutput(convertTemp(inputNum, currentFromUnit!, target));
      if (currentSec == "Currency") {
        if (units.isEmpty) return "0.0";
        double baseValue = (units[currentFromUnit] ?? 1.0) == 0 ? 0 : inputNum / units[currentFromUnit]!;
        return formatBinaryOutput(baseValue * (units[target] ?? 1.0));
      }
      return formatBinaryOutput((inputNum * (units[currentFromUnit] ?? 1.0)) / (units[target] ?? 1.0));
    } catch (e) { return "Error"; }
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
          const BannerAdWidget(),
          BottomNavigationBar(
            currentIndex: _navIdx,
            type: BottomNavigationBarType.fixed,
            onTap: (i) => setState(() => _navIdx = i),
            items: [
              BottomNavigationBarItem(icon: const Icon(Icons.home_outlined), activeIcon: const Icon(Icons.home), label: t("home")),
              BottomNavigationBarItem(icon: const Icon(Icons.star_outline), activeIcon: const Icon(Icons.star), label: t("fav")),
              BottomNavigationBarItem(icon: const Icon(Icons.history), label: t("hist")),
              BottomNavigationBarItem(icon: const Icon(Icons.settings_outlined), activeIcon: const Icon(Icons.settings), label: t("set")),
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
    
    // Retrieve this section's unit or default
    String? fromUnit = sectionFromUnits[currentSec] ?? siDefaults[currentSec] ?? (unitsMap.isNotEmpty ? unitsMap.keys.first : null);
    
    Color activeColor = topicColors[topicIdx];
    bool isDark = widget.currentMode == ThemeMode.dark;

    List<String> sortedKeys = unitsMap.keys.toList();
    sortedKeys.sort((a, b) {
      String comboA = "$currentSec|$fromUnit|$a";
      String comboB = "$currentSec|$fromUnit|$b";
      bool isFavA = favorites.contains(comboA);
      bool isFavB = favorites.contains(comboB);
      if (isFavA && !isFavB) return -1;
      if (!isFavA && isFavB) return 1;
      return a.compareTo(b); 
    });

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 15, bottom: 5),
          child: Text(t("title"), style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 2, color: activeColor)),
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
                          onChanged: (v) {
                            setState(() { 
                              sectionInputValues[currentSec] = v; 
                            });
                            _saveCurrentState();
                          },
                          keyboardType: (topics[topicIdx] == "Binary Lab" && currentSec != "Logarithm") ? TextInputType.text : const TextInputType.numberWithOptions(decimal: true),
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 50, fontWeight: FontWeight.w300, color: isDark ? Colors.white : Colors.black, letterSpacing: -1),
                          decoration: InputDecoration(border: InputBorder.none, hintText: "1", hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.black26)),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.content_paste, color: activeColor.withOpacity(0.5)),
                        onPressed: () async {
                          ClipboardData? data = await Clipboard.getData('text/plain');
                          if (data?.text != null) {
                            setState(() { 
                              _controller.text = data!.text!;
                              sectionInputValues[currentSec] = data.text!;
                            });
                            _saveCurrentState();
                          }
                        },
                      ),
                    ],
                  ),
                  if (fromUnit != null) _buildUnitDropdown(unitsMap, activeColor, currentSec, fromUnit),
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
                Text(t("offline"), style: const TextStyle(color: Colors.grey)),
                TextButton(onPressed: fetchCurrency, child: Text(t("retry")))
              ],
            ))
          : ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: sortedKeys.length,
              itemBuilder: (context, i) {
                String symbol = sortedKeys[i];
                String res = calculateResultString(currentSec, symbol, unitsMap);
                return _buildResultRow(symbol, res, activeColor, currentSec, fromUnit!);
              },
            ),
        ),
      ],
    );
  }

  Widget _buildTopicBar(Color activeColor) {
    bool isDark = widget.currentMode == ThemeMode.dark;
    return Container(
      height: 90, 
      width: double.infinity,
      decoration: BoxDecoration(
        color: activeColor.withOpacity(0.05), 
        border: Border(bottom: BorderSide(color: activeColor.withOpacity(0.1), width: 1)),
      ),
      child: Row(
        children: List.generate(topics.length, (i) {
          bool isActive = topicIdx == i;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() { 
                  topicIdx = i; 
                  sectionIdx = 0; 
                  _refreshController();
                });
                _saveCurrentState();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8), 
                decoration: BoxDecoration(
                  color: isActive ? topicColors[i] : (isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(topicIcons[topics[i]], size: 20, color: isActive ? Colors.black : (isDark ? Colors.white38 : Colors.black38)),
                    const SizedBox(height: 4),
                    Text(t(topics[i]), textAlign: TextAlign.center, style: TextStyle(fontSize: 9, color: isActive ? Colors.black : (isDark ? Colors.white70 : Colors.black87))),
                  ],
                ),
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
      height: 65,
      width: double.infinity,
      decoration: BoxDecoration(
        color: activeColor.withOpacity(0.12),
        border: Border.symmetric(horizontal: BorderSide(color: activeColor.withOpacity(0.1), width: 1)),
      ),
      child: Row(
        children: List.generate(secList.length, (i) {
          bool isActive = sectionIdx == i;
          return Expanded(
            child: InkWell(
              onTap: () {
                setState(() { 
                  sectionIdx = i; 
                  _refreshController();
                });
                _saveCurrentState();
              },
              child: Container(
                decoration: BoxDecoration(border: Border(bottom: BorderSide(color: isActive ? activeColor : Colors.transparent, width: 3))),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center, 
                  children: [
                    Icon(sectionIcons[secList[i]], size: 20, color: isActive ? activeColor : (isDark ? Colors.white24 : Colors.black26)),
                    const SizedBox(height: 4),
                    Text(t(secList[i]).toUpperCase(), textAlign: TextAlign.center, style: TextStyle(fontSize: 8, color: isActive ? activeColor : (isDark ? Colors.white24 : Colors.black26))),
                  ],
                ),
              ),
            ),
          );
        })
      ),
    );
  }

  Widget _buildResultRow(String symbol, String formattedVal, Color activeColor, String section, String fromUnit) {
    bool isDark = widget.currentMode == ThemeMode.dark;
    String comboKey = "$section|$fromUnit|$symbol";
    bool isFav = favorites.contains(comboKey);

    return ListTile(
      onLongPress: () {
        Clipboard.setData(ClipboardData(text: formattedVal));
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("${t("copy")} $formattedVal"), duration: const Duration(seconds: 1)));
      },
      onTap: () {
        addToHistory(fromUnit, symbol, _controller.text, formattedVal, section);
        HapticFeedback.lightImpact();
      },
      title: Text(fullNames[symbol] ?? symbol, style: TextStyle(color: isDark ? Colors.white.withOpacity(0.4) : Colors.black.withOpacity(0.5), fontSize: 13)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(formattedVal.length > 15 ? "${formattedVal.substring(0, 12)}..." : formattedVal, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w300, color: isDark ? Colors.white : Colors.black)),
          const SizedBox(width: 12),
          Text(symbol, style: TextStyle(fontSize: 10, color: activeColor, fontWeight: FontWeight.bold)),
          IconButton(
            icon: Icon(isFav ? Icons.star : Icons.star_border, color: isFav ? Colors.amber : (isDark ? Colors.white10 : Colors.black12)),
            onPressed: () => toggleFavorite(section, fromUnit, symbol),
          )
        ],
      ),
    );
  }

  // ... [buildFavorites, buildHistory, buildSettings remain mostly the same]

  Widget _buildFavorites() {
    bool isDark = widget.currentMode == ThemeMode.dark;
    return Column(
      children: [
        Padding(padding: const EdgeInsets.all(20), child: Text(t("fav"), style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black))),
        Expanded(
          child: favorites.isEmpty
            ? Center(child: Text(t("no_fav"), style: const TextStyle(color: Colors.grey)))
            : ListView.builder(
                itemCount: favorites.length,
                itemBuilder: (c, i) {
                   var parts = favorites[i].split('|');
                   return ListTile(
                    onTap: () => restoreCalculation(parts[0], parts[1], parts[2], "1.0"),
                    leading: const Icon(Icons.star, color: Colors.amber),
                    title: Text("${t(parts[0])}: ${parts[1]} ➔ ${parts[2]}", style: TextStyle(color: isDark ? Colors.white : Colors.black)),
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
          Text(t("hist"), style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
          if (history.isNotEmpty) IconButton(icon: const Icon(Icons.delete_sweep, color: Colors.redAccent), onPressed: () { setState(() => history.clear()); _saveHistory(); })
        ])),
        Expanded(
          child: history.isEmpty
            ? Center(child: Text(t("no_hist"), style: const TextStyle(color: Colors.grey)))
            : ListView.builder(
                itemCount: history.length,
                itemBuilder: (c, i) => ListTile(
                  onTap: () => restoreCalculation(history[i]['sec']!, history[i]['from']!, history[i]['to']!, history[i]['val']!),
                  leading: const Icon(Icons.history_toggle_off),
                  title: Text("${history[i]['val']} ${history[i]['from']} = ${history[i]['res']} ${history[i]['to']}", style: TextStyle(color: isDark ? Colors.white : Colors.black)),
                  subtitle: Text(t(history[i]['sec'] ?? ""), style: const TextStyle(fontSize: 10, color: Colors.grey)),
                ),
              ),
        ),
      ],
    );
  }

  Widget _buildSettings() {
    bool isDark = widget.currentMode == ThemeMode.dark;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t("set"), style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
          const SizedBox(height: 30),
          ListTile(
            title: Text(isDark ? t("dark_m") : t("light_m"), style: TextStyle(color: isDark ? Colors.white : Colors.black)),
            trailing: Switch(value: isDark, onChanged: (v) => widget.onThemeChanged(v)),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.language, color: Colors.blueAccent),
            title: Text(t("lang")),
            subtitle: Text("${t("sel")}: $selectedLang"),
            trailing: DropdownButton<String>(
              value: selectedLang,
              onChanged: (String? newVal) async {
                if (newVal != null) {
                  setState(() => selectedLang = newVal);
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString('app_lang', newVal);
                }
              },
              items: languages.map<DropdownMenuItem<String>>((String value) {
                return DropdownMenuItem<String>(value: value, child: Text(value));
              }).toList(),
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.format_list_numbered, color: Colors.green),
            title: Text(t("prec")),
            subtitle: Text("${t("sel")}: $decimalPlaces ${t("places")}"),
            trailing: DropdownButton<int>(
              value: decimalPlaces,
              onChanged: (int? newVal) async {
                if (newVal != null) {
                  setState(() => decimalPlaces = newVal);
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setInt('decimal_p', newVal);
                }
              },
              items: [0, 1, 2, 3, 4, 5, 6].map<DropdownMenuItem<int>>((int value) {
                return DropdownMenuItem<int>(value: value, child: Text("$value"));
              }).toList(),
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.science_outlined, color: Colors.purple),
            title: Text(t("sci")),
            trailing: Switch(
              value: useScientific,
              onChanged: (v) async {
                setState(() => useScientific = v);
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('use_scientific', v);
              },
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.ios_share, color: Colors.orange),
            title: Text(t("export")),
            onTap: exportHistoryToCSV,
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.refresh, color: Colors.redAccent),
            title: Text(t("reset")),
            subtitle: Text(t("reset_sub")),
            onTap: _resetToDefaults,
          ),
          const Divider(height: 40),
          Text(t("info"), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue)),
          const SizedBox(height: 10),
          Card(
            color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
            child: Padding(
              padding: const EdgeInsets.all(15.0),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.info_outline, color: Colors.blue),
                    title: Text(t("note")),
                    subtitle: Text("Precision: $decimalPlaces places", style: TextStyle(color: isDark ? Colors.white70 : Colors.black54)),
                  ),
                  const ListTile(
                    leading: Icon(Icons.verified_user_outlined, color: Colors.green),
                    title: Text("Version"),
                    subtitle: Text("v1.0.8 - Pro Binary Edition", style: TextStyle(color: Colors.grey)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnitDropdown(Map<String, double> units, Color activeColor, String currentSec, String currentUnit) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(border: Border.all(color: activeColor.withOpacity(0.2)), borderRadius: BorderRadius.circular(12)),
      child: DropdownButton<String>(
        value: currentUnit,
        underline: const SizedBox(),
        dropdownColor: widget.currentMode == ThemeMode.dark ? Colors.black : Colors.white,
        items: units.keys.map((u) => DropdownMenuItem(value: u, child: Text(fullNames[u] ?? u, style: TextStyle(fontSize: 14, color: activeColor)))).toList(),
        onChanged: (v) {
          setState(() { 
            sectionFromUnits[currentSec] = v!; 
          });
          _saveCurrentState();
        },
      ),
    );
  }
}
