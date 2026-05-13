import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class WaterChart extends StatelessWidget {
  final List<double> values;
  final double? threshold; // Added optional threshold parameter

  const WaterChart({super.key, required this.values, this.threshold});

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) {
      return const Center(child: Text("No data available", style: TextStyle(color: Colors.grey)));
    }

    double maxLevel = values.reduce((a, b) => a > b ? a : b);
    double minLevel = values.reduce((a, b) => a < b ? a : b);

    double maxY = 0;
    
    // Ensure the chart is tall enough to show the threshold if provided
    if (threshold != null && threshold! > maxLevel) {
      maxY = threshold!;
    } else if (maxLevel == 0) {
      maxY = 5.0;
    } else {
      maxY = maxLevel * 1.1;
    }

    if (minLevel > 0) minLevel=0;

    List<Color> lineColor = [Colors.blue, Colors.cyan];
    List<Color> underlineColor = [const Color.fromARGB(60, 33, 149, 243), const Color.fromARGB(0, 33, 149, 243)];

    if (threshold != null) {
      if (values.last >= threshold!) {
        lineColor = [Colors.red.shade600, Colors.red.shade300];
        underlineColor = [const Color.fromARGB(60, 229, 56, 53), const Color.fromARGB(0, 229, 115, 115)];
      } else if (values.last >= threshold!*0.8) {
        lineColor = [Colors.yellow, Colors.yellow.shade700];
        underlineColor = [const Color.fromARGB(60, 255, 235, 59), const Color.fromARGB(0, 251, 193, 45)];
      }
    }

    


    return LineChart(
      LineChartData(
        // Extra Lines Configuration for the Threshold
        extraLinesData: ExtraLinesData(
          horizontalLines: [
            if (threshold != null)
              HorizontalLine(
                y: threshold!,
                color: const Color.fromARGB(180, 244, 67, 54),
                strokeWidth: 2,
                dashArray: [5, 5], // Creates a dashed line effect
                label: HorizontalLineLabel(
                  show: true,
                  alignment: Alignment.topRight,
                  padding: const EdgeInsets.only(right: 5, bottom: 5),
                  style: const TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                  labelResolver: (line) => 'Limit: ${line.y.toStringAsFixed(1)}m',
                ),
              ),
          ],
        ),
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
              interval: 1,
              getTitlesWidget: (value, meta) {
                return Text(value.toStringAsFixed(1), style: const TextStyle(color: Colors.grey, fontSize: 10));
              },
              reservedSize: 30,
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        minY: minLevel,
        maxY: maxY,
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (touchedSpot) => const Color.fromARGB(210, 68, 137, 255),
            getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
              return touchedBarSpots.map((barSpot) {
                return LineTooltipItem(
                  '${barSpot.y.toStringAsFixed(2)} m',
                  const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                );
              }).toList();
            },
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: values
                .asMap()
                .entries
                .map((e) => FlSpot(e.key.toDouble(), e.value))
                .toList(),
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