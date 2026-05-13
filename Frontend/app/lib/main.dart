import 'dart:io';
import 'dart:math';

import 'package:digital_kae_fai/general_chart.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';

import 'package:flutter/foundation.dart'; // สำหรับเช็คว่ารันบนเว็บหรือมือถือ
import 'water_chart.dart'; // อิมพอร์ตไฟล์กราฟของคุณเข้ามา
import 'package:flutter_map/flutter_map.dart'; // ใช้ flutter_map แทน
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'stat_value.dart';

import 'user_data.dart';

// Global Variables
String todayDateFormatted = DateFormat('dd-MM-yyyy').format(DateTime.now());
String selectedDateFormatted = DateFormat('dd-MM-yyyy').format(DateTime.now());
DateTime selectedDate = DateTime.now();
String globalZone = "CM-1";
String floodChance = "n/a";
String waterStatus = "n/a";
double predictedLevel = 0;
double waterLevel = 0;
double rainfall = 0;
List<double> damDischarges = [0,0];
List<List<double>> allWaterLevel = [[],[],[],[],[]];
List<List<double>> allWaterDischarge = [[],[],[],[],[]];
List<List<double>> allDischargeLevel = [[],[],[]];
List<int> lastUpdatedLevel = [0,0,0,0,0];
List<int> lastUpdatedDischarge = [0,0,0,0,0];

String getBaseUrl() {
  return kIsWeb ? 'http://127.0.0.1:8000' : 'http://10.0.2.2:8000';
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true),
      home: const MainNavigation(),
    );
  }
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});
  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _selectedIndex = 0;
  String? _targetZoneForMap; 

  void _goToMapWithZone(String zone) {
    setState(() {
      _targetZoneForMap = zone; 
      _selectedIndex = 2; 
    });
  }

  // Handle Date Refresh Globally
  Future<void> _selectDateGlobal(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = picked;
        selectedDateFormatted = DateFormat('dd-MM-yyyy').format(picked);
      });
      // Trigger the fetch immediately so Header and Children update
      await fetchWaterData(); 
    }
  }

  @override
  void initState() {
    super.initState();
    _loadAllSettings();
  }

  // Inside _MainNavigationState in main.dart
  Future<void> _loadAllSettings() async {
    // We keep loading the Zone because you likely still want that to persist
    final savedZone = await UserData.getZone();
    
    // REMOVE the call to UserData.getDate() here.
    // By not loading it, the app will use the default global variables 
    // (which are set to DateTime.now() at the top of your file).

    if (!mounted) return;
    setState(() {
      globalZone = savedZone;
      
      // Reset to today's date explicitly on every startup
      selectedDate = DateTime.now();
      selectedDateFormatted = DateFormat('dd-MM-yyyy').format(selectedDate);
      fetchWaterData();
    });
  }

  Future<void> fetchWaterData() async {
    final baseUrl = getBaseUrl();
    final waterURL = Uri.parse('$baseUrl/water24h?stations=20,75,67,103,1&date=$selectedDateFormatted');
    final stationDischargeURL = Uri.parse('$baseUrl/discharge24h?stations=20,75,67,103,1&date=$selectedDateFormatted');
    final floodURL = Uri.parse('$baseUrl/predict_chance');
    final statusURL = Uri.parse('$baseUrl/level_status?date=$selectedDateFormatted');
    final predictURL = Uri.parse('$baseUrl/predict_level?date=$selectedDateFormatted');
    final dischargeURL = Uri.parse('$baseUrl/discharge_delta_all');
    final rainURL = Uri.parse('$baseUrl/rainfall');
    final damURL = Uri.parse('$baseUrl/dam');
    try {
      dynamic response = await http.get(waterURL);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (mounted) {
          setState(() {
            allWaterLevel = (data[0] as List).map((stationList) {
              return (stationList as List).map((value) => (value as num).toDouble()).toList();
            }).toList();
            lastUpdatedLevel = (data[1] as List).map((value) => (value as num).toInt()).toList();
            waterLevel = allWaterLevel[4].last;
          });
        }
      }
    } catch (e) {}
    try {
      dynamic response = await http.get(stationDischargeURL);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (mounted) {
          setState(() {
            allWaterDischarge = (data[0] as List).map((stationList) {
              return (stationList as List).map((value) => (value as num).toDouble()).toList();
            }).toList();
            lastUpdatedDischarge = (data[1] as List).map((value) => (value as num).toInt()).toList();
          });
        }
      }
    } catch (e) {}
    try {
      dynamic response = await http.get(floodURL);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (mounted) {
          setState(() {
            floodChance = data.toString();
          });
        }
      }
    } catch (e) {}
    try {
      dynamic response = await http.get(statusURL);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (mounted) {
          setState(() {
            waterStatus = data.toString();
          });
        }
      }
    } catch (e) {}
    try {
      dynamic response = await http.get(predictURL);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (mounted) {
          setState(() {
            predictedLevel = (data as num).toDouble();
          });
        }
      }
    } catch (e) {}
    try {
      dynamic response = await http.get(dischargeURL);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (mounted) {
          setState(() {
            allDischargeLevel = (data as List).map((e) {
              return (e as List).map((value) => (value as num).toDouble()).toList();
            }).toList();
          });
        }
      }
    } catch (e) {}
    try {
      dynamic response = await http.get(rainURL);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (mounted) {
          setState(() {
            rainfall = (data as num).toDouble();
          });
        }
      }
    } catch (e) {}
    try {
      dynamic response = await http.get(damURL);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (mounted) {
          setState(() {
            damDischarges = (data as List).map((e) => (e as num).toDouble()).toList();
          });
        }
      }
    } catch (e) {}
  }
  

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE3F2FD),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: IndexedStack(
              index: _selectedIndex,
              children: [
                HomeScreenContent(onDateChange: () => _selectDateGlobal(context)),
                ZoneSelectionScreen(onNavigateToMap: _goToMapWithZone), 
                OSMMapScreen(
                  targetZone: _targetZoneForMap, 
                  date: selectedDateFormatted, // Important: pass the global date here
                ),
                const StatisticsScreen(), 
                const SettingsScreen(), 
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildCustomBottomNav(),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.only(top: 50, bottom: 16),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          HeaderColumn(title: "พื้นที่", value: globalZone),
          HeaderColumn(title: "ข้อมูล ณ วันที่", value: selectedDateFormatted), 
          HeaderColumn(title: "โอกาสน้ำท่วม", value: selectedDateFormatted == todayDateFormatted ? floodChance : "n/a"),
        ],
      ),
    );
  }

  Widget _buildCustomBottomNav() {
    return Container(
      height: 80,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _navItem(Icons.home_outlined, 0),
          _navItem(Icons.layers_outlined, 1),
          _navItem(Icons.map_outlined, 2),
          _navItem(Icons.bar_chart_outlined, 3),
          _navItem(Icons.settings_outlined, 4),
        ],
      ),
    );
  }

  Widget _navItem(IconData icon, int index) {
    bool isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => setState(() {
        _selectedIndex = index;
        if(index != 2) _targetZoneForMap = null; // Reset map target when leaving map
      }),
      child: Icon(icon, size: 32, color: isSelected ? Colors.blue : Colors.grey.shade400),
    );
  }
}


















class HomeScreenContent extends StatefulWidget {
  final VoidCallback onDateChange;
  const HomeScreenContent({super.key, required this.onDateChange});
  @override
  State<HomeScreenContent> createState() => _HomeScreenContentState();
}

class _HomeScreenContentState extends State<HomeScreenContent> {
  bool isLoading = true;
  List<dynamic> dailyDataList = [];

  @override
  void initState() {
    super.initState();
  }

  @override
  void didUpdateWidget(covariant HomeScreenContent oldWidget) {
    super.didUpdateWidget(oldWidget);
  }

  Color _getFlagColor() {
    if (waterStatus.contains("น้ำท่วม")) return Colors.red;
    if (waterStatus == "สูง" || floodChance == "สูง") return Colors.deepOrange;
    if (waterStatus == "ค่อนข้างสูง" || floodChance == "ค่อนข้างสูง") return Colors.orange;
    if (floodChance == "เฝ้าระวัง") return Colors.yellow;
    return Colors.green;
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      children: [
        // Dashboard Pill
        _buildHeaderSection("Dashboard"),

        const SizedBox(height: 15),

        _buildDashboardCard(
          title: "การเฝ้าระวังสถานการณ์น้ำ",
          subtitle: "ระดับน้ำที่คาดการณ์ไว้ (6-8 ชม.): ${selectedDateFormatted == todayDateFormatted ? predictedLevel.toStringAsFixed(2) : "X.XX"} ม.\n"
                    "โอกาสน้ำท่วม: ${selectedDateFormatted == todayDateFormatted ? floodChance : "n/a"}\n"
                    "สถานะปัจจุบัน: $waterStatus",
          trailing: Icon(Icons.flag, color: _getFlagColor(), size: 60),
        ),
        const SizedBox(height: 15),

        _buildDashboardCard(
          title: "สถานีวัดระดับน้ำ P.1",
          subtitle: "สะพานนวรัฐ อ.เมือง จ.เชียงใหม่\nข้อมูล ณ เวลา ${lastUpdatedLevel[4]}.00น.",
          customChild: SizedBox(height: 150, child: WaterChart(values: allWaterLevel[4].isNotEmpty ? allWaterLevel[4] : [0,0,0,0,0], threshold: 3.7,)),
        ),
        const SizedBox(height: 15),

        _buildDashboardCard(
          title: "สถานีวัดระดับน้ำ P.103",
          subtitle: "บ้านป่าข่อยใต้ อ.เมือง จ.เชียงใหม่\nข้อมูล ณ เวลา ${lastUpdatedLevel[3]}.00น.",
          customChild: SizedBox(height: 150, child: WaterChart(values: allWaterLevel[3].isNotEmpty ? allWaterLevel[3] : [0,0,0,0,0], threshold: 6.8,)),
        ),
        const SizedBox(height: 15),
        
        _buildDashboardCard(
          title: "สถานีวัดระดับน้ำ P.67",
          subtitle: "บ้านแม่แต อ.สันทราย จ.เชียงใหม่\nข้อมูล ณ เวลา ${lastUpdatedLevel[2]}.00น.",
          customChild: SizedBox(height: 150, child: WaterChart(values: allWaterLevel[2].isNotEmpty ? allWaterLevel[2] : [0,0,0,0,0], threshold: 3.0,)),
        ),
        const SizedBox(height: 15),

        _buildDashboardCard(
          title: "สถานีวัดระดับน้ำ P.75",
          subtitle: "บ้านช่อแล อ.แม่แตง จ.เชียงใหม่\nข้อมูล ณ เวลา ${lastUpdatedLevel[1]}.00น.",
          customChild: SizedBox(height: 150, child: WaterChart(values: allWaterLevel[1].isNotEmpty ? allWaterLevel[1] : [0,0,0,0,0], threshold: 3.7,)),
        ),
        const SizedBox(height: 15),

        _buildDashboardCard(
          title: "สถานีวัดระดับน้ำ P.20",
          subtitle: "บ้านเชียงดาว อ.เชียงดาว จ.เชียงใหม่\nข้อมูล ณ เวลา ${lastUpdatedLevel[0]}.00น.",
          customChild: SizedBox(height: 150, child: WaterChart(values: allWaterLevel[0].isNotEmpty ? allWaterLevel[0] : [0,0,0,0,0], threshold: 2.8,)),
        ),
        const SizedBox(height: 15),

        const SizedBox(height: 20),
        // Date Picker Button
        ElevatedButton.icon(
          onPressed: widget.onDateChange,
          icon: const Icon(Icons.calendar_today),
          label: Text("เปลี่ยนวันที่: $selectedDateFormatted"),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: Colors.blue,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            padding: const EdgeInsets.symmetric(vertical: 15),
          ),
        ),
      ],
    );
  }

  Widget _buildDashboardCard({required String title, required String subtitle, Widget? trailing, Widget? customChild}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 18, color: Colors.grey, fontWeight: FontWeight.bold)),
                    Text(subtitle, style: const TextStyle(fontSize: 14, color: Colors.grey)),
                  ],
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
          if (customChild != null) Padding(padding: const EdgeInsets.only(top: 10), child: customChild),
        ],
      ),
    );
  }

  Widget _buildHeaderSection(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(25),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
        ),
        child: Text(
          title,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w400, color: Colors.grey),
        ),
      ),
    );
  }
}










class ZoneSelectionScreen extends StatefulWidget {
  // เพิ่มตัวแปรสำหรับรับคำสั่งเปลี่ยนหน้าและส่งรหัสโซน
  final Function(String) onNavigateToMap;

  const ZoneSelectionScreen({super.key, required this.onNavigateToMap});

  @override
  State<ZoneSelectionScreen> createState() => _ZoneSelectionScreenState();
}

class _ZoneSelectionScreenState extends State<ZoneSelectionScreen> {
  String defaultZone = "CM-1";
  String selectedZone = "CM-1";
  Color textColor = Colors.black;
  Color textPredictedColor = Colors.black;
  Color flagColor = Colors.green;
  

  final Map<String, List<String>> zoneLocations = {
    'CM-1': ['บ้านป่าพร้าวนอก', 'โรงเหล้า', 'ร้านอาหารวังปลา', 'ทางลอดใต้สะพานไปป่าแดด'],
    'CM-2': ['ถนนเจริญประเทศ', 'โรงเรียนมงฟอร์ตประถม', 'ป่าไม้เชียงใหม่', 'วัดชัยมงคล'],
    'CM-3': ['บ้านเด่น', 'การไฟฟ้าบ้านเด่น', 'หมู่บ้านจินดานิเวศน์'],
    'CM-4': ['ห้างริมปิงซุปเปอร์สโตร์', 'วัดท่าสะต๋อย', 'ตลาดทองคำ', 'ค่ายกาวิละ'],
    'CM-5': ['ตลาดหนองหอย', 'ถนนเกาะกลาง', 'โรงเรียนมงฟอร์ตวิทยาลัย', 'วัดเมืองสาตรหลวง'],
    'CM-6': ['ถนนประชาสัมพันธ์', 'ถนนช้างคลาน', 'ไนท์บาซาร์', 'แยกแสงตะวัน', 'วัดหัวฝ่าย'],
    'CM-7': ['ถนนรถไฟ', 'บ้านต้นขาม', 'สถานีรถไฟ', 'ศิริวัฒนา', 'กาดหลวง', 'กาดเมืองใหม่'],
  };

  final Map<String, double> zoneThreshold = {
    'CM-1': 3.7,
    'CM-2': 3.9,
    'CM-3': 4.0,
    'CM-4': 4.1,
    'CM-5': 4.2,
    'CM-6': 4.3,
    'CM-7': 4.6,
  };

  Color _getTextColor(double level, double threshold) {
    if (level>=threshold) return Colors.red.shade900;
    if (level>=threshold*0.8) return Colors.orange.shade700;
    return Colors.black;
  }

  Color _getFlagColor(double level, double threshold) {
    if (level>=threshold) return Colors.red;
    if (level>=threshold*0.8) return Colors.yellow;
    return Colors.green;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFD6EAF5),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildHeaderSection("Zones"),
          const SizedBox(height: 20),
          
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            childAspectRatio: 2.5,
            mainAxisSpacing: 15,
            crossAxisSpacing: 15,
            children: [
              for (int i = 1; i <= 3; i++) _buildZoneButton("CM-$i"),
              for (int i = 4; i <= 7; i++) _buildZoneDisabledButton("CM-$i"),
              _buildDefaultSelectButton(),
            ],
          ),
          const SizedBox(height: 25),
          
          _buildInfoCard(),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildZoneButton(String zoneCode) {
    bool isSelected = selectedZone == zoneCode;
    bool isDefault = defaultZone == zoneCode;
    return GestureDetector(
      onTap: () {
        setState(() {
          selectedZone = zoneCode;
          flagColor =  _getFlagColor( selectedDateFormatted == todayDateFormatted ? max(predictedLevel, waterLevel) : waterLevel, zoneThreshold[selectedZone]!);
          textColor = _getTextColor(waterLevel, zoneThreshold[selectedZone]!);
          textPredictedColor = selectedDateFormatted == todayDateFormatted ? _getTextColor(predictedLevel, zoneThreshold[selectedZone]!) : Colors.grey;
          });
        },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: isSelected ? Border.all(color: Colors.blue, width: 2) : null,
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
        ),
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text("โซน $zoneCode", 
                style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
              if (isDefault) const Padding(
                padding: EdgeInsets.only(left: 6.0),
                child: Icon(Icons.star, color: Colors.amber, size: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildZoneDisabledButton(String zoneCode) {
    return GestureDetector(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey[400],
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.grey, width: 1),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
        ),
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text("โซน $zoneCode", 
                style: TextStyle(fontWeight: FontWeight.normal, color: Colors.grey[600])),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDefaultSelectButton() {
    return GestureDetector(
      onTap: () {
        setState(() {
          defaultZone = selectedZone;
          globalZone = selectedZone;
        });
        UserData.saveZone(selectedZone);
        },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Text("เลือกเป็น", style: TextStyle(fontSize: 10, color: Colors.grey)),
            Text("โซนหลัก", style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("การเฝ้าระวังสถานการณ์น้ำ ($selectedZone)", style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text("โอกาสน้ำท่วม: ${selectedDateFormatted == todayDateFormatted ? floodChance : "n/a"}", style: TextStyle(color: Colors.grey, fontSize: 13)),
                    Text("ระดับน้ำที่คาดการณ์ไว้ (6-8 ชม.): ${selectedDateFormatted == todayDateFormatted ? predictedLevel.toStringAsFixed(2) : "X.XX"}/${zoneThreshold[selectedZone]} ม.", style: TextStyle(color: textPredictedColor, fontSize: 13)),
                    Text("ระดับน้ำปัจจุบัน: $waterLevel/${zoneThreshold[selectedZone]} ม.", style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 13)),
                  ],
                ),
              ),
              Icon(Icons.flag, color: flagColor, size: 50),
            ],
          ),
          const Divider(height: 25),
          const Text("สถานที่สำคัญในโซนนี้:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: zoneLocations[selectedZone]!
                .map((loc) => Text("• $loc", style: const TextStyle(fontSize: 12, color: Colors.black54)))
                .toList(),
          ),
          const SizedBox(height: 20),
          
          // ---- ปุ่มใหม่สำหรับลิงก์ไปหน้าแผนที่ ----
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                // เรียกใช้ฟังก์ชันที่ส่งมาจาก MainNavigation และส่งค่า selectedZone ไป
                widget.onNavigateToMap(selectedZone);
              },
              icon: const Icon(Icons.map_outlined),
              label: Text("ดูพื้นที่ $selectedZone บนแผนที่"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                elevation: 2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderSection(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(25),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
        ),
        child: Text(
          title,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w400, color: Colors.grey),
        ),
      ),
    );
  }
}









class OSMMapScreen extends StatefulWidget {
  final String? targetZone;
  final String date; // Receive date to trigger updates

  const OSMMapScreen({
    super.key,
    this.targetZone,
    required this.date,
  });

  @override
  State<OSMMapScreen> createState() => _OSMMapScreenState();
}

class _OSMMapScreenState extends State<OSMMapScreen> {
  final MapController _mapController = MapController();
  String? selectedZoneId;

  // Your original polygon coordinates preserved and mapped to Zone IDs
  final List<Map<String, dynamic>> polygonData = [
    {
      'id': 'CM-1',
      'threshold': 3.7,
      'labelPos': const LatLng(18.764, 99.002),
      'points': const [
        LatLng(18.760421, 98.997196), LatLng(18.761062, 98.996678),
        LatLng(18.764847, 98.999964), LatLng(18.766053, 99.000169),
        LatLng(18.769766, 99.000495), LatLng(18.769583, 99.001718),
        LatLng(18.768152, 99.001758), LatLng(18.764923, 99.003578),
        LatLng(18.763858, 99.003651), LatLng(18.762557, 99.003164),
        LatLng(18.761485, 99.001414), LatLng(18.761339, 98.998928),
        LatLng(18.760982, 98.997897),
      ]
    },
    {
      'id': 'CM-2',
      'threshold': 3.9,
      'labelPos': const LatLng(18.775, 99.002),
      'points': const [
        LatLng(18.766053, 99.000169), LatLng(18.769766, 99.000495),
        LatLng(18.769583, 99.001718), LatLng(18.773223, 99.003259),
        LatLng(18.775697, 99.005875), LatLng(18.776957, 99.006506),
        LatLng(18.778896, 99.006170), LatLng(18.782454, 99.004096),
        LatLng(18.786557, 99.004317), LatLng(18.786479, 99.002172),
        LatLng(18.780721, 99.001434), LatLng(18.777414, 98.999535),
        LatLng(18.770112, 98.998949), LatLng(18.765962, 99.000227),
        LatLng(18.763465, 98.997414), LatLng(18.761478, 98.996656),
        LatLng(18.761062, 98.996678), LatLng(18.764847, 98.999964),
      ]
    },
    {
      'id': 'CM-3',
      'threshold': 4.0,
      'labelPos': const LatLng(18.771, 99.004),
      'points': const [
        LatLng(18.766345, 99.003773), LatLng(18.766898, 99.005668),
        LatLng(18.772544, 99.006575), LatLng(18.774493, 99.007919),
        LatLng(18.778220, 99.007836), LatLng(18.785132, 99.006063),
        LatLng(18.784856, 99.004979), LatLng(18.782802, 99.005111),
        LatLng(18.777756, 99.007429), LatLng(18.776521, 99.007418),
        LatLng(18.775395, 99.006696), LatLng(18.774363, 99.005250),
        LatLng(18.773857, 99.004604), LatLng(18.771266, 99.002617),
        LatLng(18.769228, 99.002300), LatLng(18.767588, 99.002790),
        LatLng(18.766403, 99.003701),
      ]
    },
  ];

  @override
  void initState() {
    super.initState();
    selectedZoneId = widget.targetZone;
    fetchData();
  }

  @override
  void didUpdateWidget(OSMMapScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Refresh colors if date changes, or move camera if target zone changes
    if (widget.date != oldWidget.date) fetchData();
    if (widget.targetZone != oldWidget.targetZone && widget.targetZone != null) {
      setState(() => selectedZoneId = widget.targetZone);
      _focusOnZone(widget.targetZone!);
    }
  }

  Future<void> fetchData() async {
    final url = Uri.parse('${getBaseUrl()}/level?station=1&date=${widget.date}');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (mounted && data is num) setState(() => waterLevel = data.toDouble());
      }
    } catch (e) {
      if (mounted) setState(() => waterLevel = 0);
    }
  }

  // Point-in-Polygon Algorithm for interaction
  bool _isPointInPolygon(LatLng point, List<LatLng> polygon) {
    int i, j = polygon.length - 1;
    bool oddNodes = false;
    double x = point.longitude;
    double y = point.latitude;
    for (i = 0; i < polygon.length; i++) {
      if ((polygon[i].latitude < y && polygon[j].latitude >= y ||
              polygon[j].latitude < y && polygon[i].latitude >= y) &&
          (polygon[i].longitude <= x || polygon[j].longitude <= x)) {
        if (polygon[i].longitude +
                (y - polygon[i].latitude) /
                    (polygon[j].latitude - polygon[i].latitude) *
                    (polygon[j].longitude - polygon[i].longitude) < x) {
          oddNodes = !oddNodes;
        }
      }
      j = i;
    }
    return oddNodes;
  }

  void _handleMapTap(TapPosition tapPosition, LatLng latlng) {
    String? foundZone;
    for (var zone in polygonData) {
      if (_isPointInPolygon(latlng, zone['points'])) {
        foundZone = zone['id'];
        break;
      }
    }
    setState(() => selectedZoneId = foundZone);
    if (foundZone != null) _focusOnZone(foundZone);
  }

  void _focusOnZone(String zoneId) {
    final zone = polygonData.firstWhere((z) => z['id'] == zoneId, orElse: () => {});
    if (zone.isNotEmpty) {
      _mapController.move(zone['labelPos'], 14.5);
    }
  }

  Color _getBorderColor(dynamic level) {
    if (waterLevel>=level) return Color.fromARGB(255, 255, 50, 50);
    if (waterLevel>=level*0.8) return Color.fromARGB(255, 255, 255, 50);
    return Color.fromARGB(255, 50, 255, 50);
  }

  Color _getFillColor(double threshold) {
    if (waterLevel >= threshold) return const Color.fromARGB(100, 255, 50, 50);
    if (waterLevel >= threshold*0.8) return const Color.fromARGB(100, 255, 255, 50);
    return const Color.fromARGB(100, 50, 255, 50);
  }

  Color _getTextColor(double level, double threshold) {
    if (level>=threshold) return Colors.red.shade900;
    if (level>=threshold*0.8) return Colors.orange.shade700;
    return Colors.black;
  }

  Color _getFlagColor(double level, double threshold) {
    if (level>=threshold) return Colors.red;
    if (level>=threshold*0.8) return Colors.yellow;
    return Colors.green;
  }

  double _getZoneThreshold(String zoneId) {
    final zone = polygonData.firstWhere(
      (z) => z['id'] == zoneId, 
      orElse: () => {'threshold': 0.0}
    );
    return zone['threshold'] as double;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: const LatLng(18.775, 99.002),
              initialZoom: 13.5,
              onTap: _handleMapTap,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.kaefai.app',
              ),
              PolygonLayer(
                polygons: polygonData.map((zone) => Polygon(
                  points: zone['points'],
                  color: _getFillColor(zone['threshold']),
                  borderStrokeWidth: 3,
                  borderColor: _getBorderColor(zone['threshold']),
                )).toList(),
              ),
              // Marker Layer for Zone Labels inside Polygons
              MarkerLayer(
                markers: polygonData.map((zone) => Marker(
                  point: zone['labelPos'],
                  width: 60,
                  height: 30,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: const Color.fromARGB(60, 255, 255, 255),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Center(
                      child: Text(
                        zone['id'],
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                  ),
                )).toList(),
              ),
            ],
          ),

          if (selectedZoneId != null)
            Positioned(
              bottom: 20, left: 20, right: 20,
              child: _buildInfoOverlay(selectedZoneId!),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoOverlay(String zoneId) {
    final double threshold = _getZoneThreshold(zoneId);
    Color textColor = _getTextColor(waterLevel, threshold);
    Color textPredictedColor = _getTextColor(predictedLevel, threshold);
    Color flagColor = _getFlagColor(selectedDateFormatted == todayDateFormatted ? max(waterLevel, predictedLevel) : waterLevel, threshold);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text("โซน: $zoneId", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                    Text("โอกาสน้ำท่วม: ${selectedDateFormatted == todayDateFormatted ? floodChance : "n/a"}", style: TextStyle(color: Colors.grey, fontSize: 13)),
                    Text("ระดับน้ำที่คาดการณ์ไว้ (6-8 ชม.): ${selectedDateFormatted == todayDateFormatted ? predictedLevel.toStringAsFixed(2) : "X.XX"}/$threshold ม.", style: TextStyle(color: textPredictedColor, fontSize: 13)),
                    Text("ระดับน้ำปัจจุบัน: $waterLevel/$threshold ม.", style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 13)),
                  ],
              ),
              Icon(Icons.flag, color: flagColor, size: 40),
            ],
          ),
        ],
      ),
    );
  }
}











class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  // สถานะเพื่อเช็คว่าอยู่ที่หน้าหลักสถิติ หรือหน้าสถิติเพิ่มเติม
  bool showMoreStats = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFD6EAF5),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: showMoreStats ? _buildMoreStatsPage() : _buildMainStatsPage(),
            ),
          ),
        ],
      ),
    );
  }

  // --- หน้าหลักสถิติ (ภาพที่ 2) ---
  Widget _buildMainStatsPage() {
    return ListView(
      key: const ValueKey("MainStats"),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        _buildHeaderSection("Statistics"),
        const SizedBox(height: 15),
        _buildStatCard("△Discharge", "ความต่างของอัตราการไหลเชิงปริมาตร", allDischargeLevel[0], unit: "m³/s"),
        const SizedBox(height: 20),
        _buildStatCard("△Discharge + Rain", "ความต่างของอัตราการไหลเชิงปริมาตร + ฝน", allDischargeLevel[1], unit: "m³/s"),
        const SizedBox(height: 20),
        _buildStatCard("△Discharge + Rain + Dam", "ความต่างของอัตราการไหลเชิงปริมาตร + ฝนและเขื่อน", allDischargeLevel[2], unit: "m³/s"),
        const SizedBox(height: 20),
        // ปุ่มสถิติเพิ่มเติม
        GestureDetector(
          onTap: () => setState(() => showMoreStats = true),
          child: Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 5)],
            ),
            child: const Center(
              child: Text("สถิติเพิ่มเติม", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey)),
            ),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  // --- หน้าสถิติเพิ่มเติม (ภาพที่ 1) ---
  Widget _buildMoreStatsPage() {
    return ListView(
      key: const ValueKey("MoreStats"),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        Row(
          children: [
            _buildHeaderSection("สถิติเพิ่มเติม"),
            const Spacer(),
            TextButton(
              onPressed: () => setState(() => showMoreStats = false),
              child: const Text("ย้อนกลับ", style: TextStyle(color: Colors.grey)),
            ),
          ],
        ),
        const SizedBox(height: 15),
        StatValueCard(title: "Effective Rainfall", value: rainfall, unit: "mm"),
        const SizedBox(height: 15),
        StatValueCard(title: "Dam Discharge (อ่างแม่งัดสมบูรณ์ชล)", value: damDischarges[1], unit: "mm"),
        const SizedBox(height: 15),
        StatValueCard(title: "Dam Discharge (อ่างเก็บน้ำแม่จอกหลวง)", value: damDischarges[0], unit: "mm"),
        const SizedBox(height: 15),
        _buildStatCard("Discharge P.1", "สะพานนวรัฐ อ.เมือง จ.เชียงใหม่", allWaterDischarge[4], unit: "m³/s"),
        const SizedBox(height: 15),
        _buildStatCard("Discharge P.103", "บ้านป่าข่อยใต้ อ.เมือง จ.เชียงใหม่", allWaterDischarge[3], unit: "m³/s"),
        const SizedBox(height: 15),
        _buildStatCard("Discharge P.67", "บ้านแม่แต อ.สันทราย จ.เชียงใหม่", allWaterDischarge[2], unit: "m³/s"),
        const SizedBox(height: 15),
        _buildStatCard("Discharge P.75", "บ้านช่อแล อ.แม่แตง จ.เชียงใหม่", allWaterDischarge[1], unit: "m³/s"),
        const SizedBox(height: 15),
        _buildStatCard("Discharge P.20", "บ้านเชียงดาว อ.เชียงดาว จ.เชียงใหม่", allWaterDischarge[0], unit: "m³/s"),
        const SizedBox(height: 15),
        
        // _buildStatCard("IDF (Intensity-Duration-Frequency)", "ข้อมูลความเข้มฝน", [0.1, 0.1, 0.1, 0.1, 0.1]),
        // const SizedBox(height: 15),
        // _buildStatCard("Hyetograph (SCS Curve Number)", "การกระจายตัวของฝน", [0.2, 0.5, 0.8, 0.4, 0.2]),
        // const SizedBox(height: 15),
        // _buildStatCard("Effective Rainfall", "ปริมาณฝนส่วนเกิน", [0.1, 0.3, 0.6, 0.2, 0.1]),
        // const SizedBox(height: 15),
        // _buildStatCard("Runoff (Discharge)", "ปริมาณน้ำท่า", [10.0, 50.0, 120.0, 80.0, 40.0]),
        // const SizedBox(height: 15),
        // _buildStatCard("River Capacity (Manning)", "ความสามารถในการรับน้ำ", [150, 150, 150, 150, 150]),
        // const SizedBox(height: 15),
        // _buildStatCard("Dam Discharge", "การระบายน้ำจากเขื่อน", [5, 10, 5, 5, 5]),
        // const SizedBox(height: 30),
      ],
    );
  }

  // Widget ส่วนหัวข้อ
  Widget _buildHeaderSection(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(25),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
        ),
        child: Text(
          title,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w400, color: Colors.grey),
        ),
      ),
    );
  }

  // Widget การ์ดสถิติพร้อมกราฟ
  Widget _buildStatCard(String title, String subtitle, List<double> data, {String unit=""}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey)),
          Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.black26)),
          const SizedBox(height: 10),
          SizedBox(
            height: 150,
            child: GeneralChart(values: data, unit: unit), // เรียกใช้งาน Component กราฟเดิม
          ),
        ],
      ),
    );
  }
}














class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // สถานะการเปิด-ปิด Switch
  bool floodAlert = true;
  bool useGPS = true;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFD6EAF5), // พื้นหลังสีฟ้าอ่อน
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildHeaderSection("Configurations"),
          const SizedBox(height: 15),

          // ปุ่ม Switch แจ้งเตือน
          _buildSwitchTile("แจ้งเตือนภัยเฝ้าระวังน้ำท่วม", floodAlert, (val) {
            setState(() => floodAlert = val);
          }),
          const SizedBox(height: 15),

          // ปุ่ม Switch GPS
          // _buildSwitchTile("ใช้ระบบ GPS", useGPS, (val) {
          //   setState(() => useGPS = val);
          // }),
          // const SizedBox(height: 20),

          _buildHeaderSection("เพิ่มเติม"),
          const SizedBox(height: 15),

          // การ์ดหมายเลขโทรศัพท์ต่างๆ
          _buildContactCard(),
          const SizedBox(height: 20),

          // การ์ด Build a Flood Wise Community
          _buildCommunityCard(),
          const SizedBox(height: 80), // เผื่อระยะสำหรับ Bottom Nav
        ],
      ),
    );
  }

  // ส่วนหัวข้อแบบมีพื้นหลังสีขาวมน
  Widget _buildHeaderSection(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(25),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
        ),
        child: Text(
          title,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w400, color: Colors.grey),
        ),
      ),
    );
  }

  // แถบ Switch ตั้งค่า
  Widget _buildSwitchTile(String title, bool value, ValueChanged<bool> onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 3))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontSize: 16, color: Colors.black54)),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: Colors.greenAccent,
          ),
        ],
      ),
    );
  }

  // การ์ดรวมเบอร์ติดต่อฉุกเฉิน
  Widget _buildContactCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("หมายเลขโทรศัพท์ต่างๆ", 
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 10),
          _buildContactItem("รายงานเหตุด่วนเหตุร้าย", "191"),
          _buildContactItem("รถพยาบาลและหน่วยกู้ภัย", "1669"),
          _buildContactItem("ศูนย์อุทกวิทยาชลประทานภาคเหนือตอนบน", "053-248925"),
        ],
      ),
    );
  }

  Widget _buildContactItem(String label, String phone) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.black54, fontSize: 13)),
          Text("• $phone", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        ],
      ),
    );
  }

  // การ์ดเชิญเข้าชุมชน (QR Code)
  Widget _buildCommunityCard() {
    const String lineUrl = "https://line.me/ti/g2/Zwxov23-F1pHV_gPKqx6KxwJbVVlVUFefKsJfQ?utm_source=invitation&utm_medium=link_copy&utm_campaign=default";

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Build a Flood Wise Community", 
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey)),
                const SizedBox(height: 8),
                RichText(
                  text: TextSpan(
                    style: const TextStyle(fontSize: 12, color: Colors.black54, fontFamily: 'Kanit'), // Match your app font
                    children: [
                      const TextSpan(text: "มาช่วยกันตรวจสอบระดับน้ำจากพื้นที่ต่างๆ และแจ้งในชุมชนของเราผ่านทาง Line OpenChat\n"),
                      TextSpan(
                        text: "Click Me!",
                        style: const TextStyle(
                          color: Colors.blue,
                          decoration: TextDecoration.underline,
                        ),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () async {
                            final Uri url = Uri.parse(lineUrl);
                            if (await canLaunchUrl(url)) {
                              await launchUrl(url, mode: LaunchMode.externalApplication);
                            }
                          },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Image.asset('img/qr_code.jpg'),
          ),
        ],
      ),
    );
  }
}













class InfoCard extends StatelessWidget {
  final double height;
  final String? title;
  final String? subtitle;
  final String? content;
  final bool isLoading;
  final Widget? customChild;

  const InfoCard({
    super.key, 
    required this.height, 
    this.title, 
    this.subtitle,
    this.content, 
    this.isLoading = false,
    this.customChild,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 255, 255, 255),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color.fromARGB(80, 0, 0, 0),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null)
                  Text(
                    title!,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                // if (subtitle != null)
                //   const SizedBox(height: 2),
                //   Text(
                //     subtitle!,
                //     style: const TextStyle(fontWeight: FontWeight.w300, fontSize: 12),
                //   ),
                const SizedBox(height: 4),
                if (customChild != null) // ถ้ามีการส่ง customChild (เช่น ListView) มาให้แสดงตัวนี้
                  Expanded(child: customChild!)
                else if (content != null)
                  Expanded(
                    child: Text(
                      content!,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
              ],
            ),
    );
  }
}

class CustomBottomNav extends StatelessWidget {
  const CustomBottomNav({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80,
      decoration: const BoxDecoration(
        color: Color.fromARGB(255, 255, 255, 255),
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(40),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: const [
          Icon(Icons.settings, size: 30),
          Icon(Icons.settings, size: 30),
          Icon(Icons.settings, size: 30),
        ],
      ),
    );
  }
}

// Widget ย่อยสำหรับ Header
class HeaderColumn extends StatelessWidget {
  final String title, value;
  const HeaderColumn({super.key, required this.title, required this.value});
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      ],
    );
  }
}