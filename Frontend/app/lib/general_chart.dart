import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class GeneralChart extends StatelessWidget {
  final List<double> values;
  final String unit; // Options: 'mmHg', 'mm', 'm3', 'm', or '' for none

  const GeneralChart({
    super.key,
    required this.values,
    this.unit = '', // Default to none
  });

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) {
      return const Center(child: Text("No data available", style: TextStyle(color: Colors.grey)));
    }

    double maxLevel = values.reduce((a, b) => a > b ? a : b);
    double maxY = 0;
    
    if (maxLevel == 0) {
      maxY = 5.0;
    } else {
      maxY = maxLevel * 1.1;
    }

    // Dynamic color logic based on threshold
    List<Color> lineColor = [Colors.blue, Colors.cyan];
    List<Color> underlineColor = [const Color.fromARGB(60, 33, 149, 243), const Color.fromARGB(0, 33, 149, 243)];

    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              interval: 1,
              getTitlesWidget: (value, meta) {
                if (value.toInt() % 2 != 0) return const Text('');
                return Text('${value.toInt()}h', style: const TextStyle(color: Colors.grey, fontSize: 10));
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: maxY / 5 > 0 ? maxY / 5 : 1.0, // Dynamic intervals
              getTitlesWidget: (value, meta) {
                // Show value with the unit on the Y-axis
                return Text('${value.toStringAsFixed(1)}$unit', 
                  style: const TextStyle(color: Colors.grey, fontSize: 9));
              },
              reservedSize: 45, // Increased to fit units
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        minY: 0,
        maxY: maxY,
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (touchedSpot) => const Color.fromARGB(210, 68, 137, 255),
            getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
              return touchedBarSpots.map((barSpot) {
                return LineTooltipItem(
                  '${barSpot.y.toStringAsFixed(2)} $unit', // Use the custom unit in tooltip
                  const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                );
              }).toList();
            },
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: values.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value)).toList(),
            isCurved: true,
            curveSmoothness: 0.35,
            gradient: LinearGradient(colors: lineColor),
            barWidth: 4,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: underlineColor,
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
      ),
    );
  }
}