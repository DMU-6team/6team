import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../controllers/temp_controller.dart';

class TempScreen extends StatelessWidget {
  const TempScreen({super.key});

  String _getStatusText(double value) {
    if (value < 35.5) return '⚠️ 낮은 온도';
    if (value > 37.5) return '🔥 높은 온도';
    return '✅ 정상 온도';
  }

  Color _getStatusColor(double value) {
    if (value < 35.5) return Colors.blueAccent;
    if (value > 37.5) return Colors.redAccent;
    return Colors.green;
  }

  @override
  Widget build(BuildContext context) {
    final tempValue = context.watch<TempController>().temperature;
    final tempHistory = context.watch<TempController>().history;
    final status = _getStatusText(tempValue);
    final statusColor = _getStatusColor(tempValue);

    final dailyTemps = const [
      {'time': '6시', 'value': 36.1},
      {'time': '9시', 'value': 36.5},
      {'time': '12시', 'value': 36.9},
      {'time': '15시', 'value': 37.2},
      {'time': '18시', 'value': 36.7},
      {'time': '21시', 'value': 36.4},
    ];

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(Icons.thermostat, size: 48, color: statusColor),
            const SizedBox(height: 16),
            Text(
              '${tempValue.toStringAsFixed(1)} ℃',
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: statusColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              status,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: statusColor,
              ),
            ),

            const SizedBox(height: 32),
            const Divider(thickness: 1),
            const SizedBox(height: 12),
            const Text('📈 실시간 온도 변화 (최근 10개)', style: TextStyle(fontSize: 18)),
            const SizedBox(height: 12),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  minY: 34,
                  maxY: 40,
                  gridData: FlGridData(show: true),
                  borderData: FlBorderData(show: true),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 1,
                        getTitlesWidget: (value, meta) =>
                            Text('${(value + 1).toInt()}',
                                style: const TextStyle(fontSize: 10)),
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: true, interval: 1),
                    ),
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: tempHistory
                          .asMap()
                          .entries
                          .map((e) => FlSpot(e.key.toDouble(), e.value))
                          .toList(),
                      isCurved: true,
                      color: statusColor,
                      barWidth: 4,
                      dotData: FlDotData(show: true),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),
            const Divider(thickness: 1),
            const SizedBox(height: 12),
            const Text('📅 오늘의 시간대별 온도', style: TextStyle(fontSize: 18)),
            const SizedBox(height: 12),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  minY: 35,
                  maxY: 38,
                  gridData: FlGridData(show: true),
                  borderData: FlBorderData(show: true),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          int idx = value.toInt();
                          if (idx >= 0 && idx < dailyTemps.length) {
                            return Text(dailyTemps[idx]['time'].toString());
                          }
                          return const Text('');
                        },
                        interval: 1,
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        interval: 0.5,
                      ),
                    ),
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      isCurved: true,
                      barWidth: 4,
                      color: Colors.deepPurple,
                      dotData: FlDotData(show: true),
                        spots: dailyTemps.asMap().entries.map((e) {
                          final y = e.value['value'];
                          return FlSpot(e.key.toDouble(), y is double ? y : double.parse(y.toString()));
                        }).toList(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}