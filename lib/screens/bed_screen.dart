import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

class BedScreen extends StatefulWidget {
  const BedScreen({super.key});

  @override
  State<BedScreen> createState() => _BedScreenState();
}

class _BedScreenState extends State<BedScreen> {
  bool _isOn = false;
  double _intensity = 5;

  Duration _selectedDuration = const Duration(minutes: 5);
  Duration _remainingDuration = Duration.zero;
  Timer? _countdownTimer;

  void _startTimer(Duration duration) {
    if (!_isOn) return; // ✅ 꺼져있으면 타이머 작동 안 함

    _countdownTimer?.cancel();
    setState(() {
      _selectedDuration = duration;
      _remainingDuration = duration;
    });

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingDuration.inSeconds > 0) {
        setState(() {
          _remainingDuration -= const Duration(seconds: 1);
        });
      } else {
        _countdownTimer?.cancel();
        setState(() => _isOn = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('⏰ 타이머가 종료되어 침대 흔들기가 꺼졌습니다.')),
        );
      }
    });
  }

  void _showTimerPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (_) {
        return SizedBox(
          height: 250,
          child: CupertinoTimerPicker(
            mode: CupertinoTimerPickerMode.ms,
            initialTimerDuration: _selectedDuration,
            onTimerDurationChanged: (Duration newDuration) {
              setState(() {
                _selectedDuration = newDuration;
              });
            },
          ),
        );
      },
    );
  }

  String _format(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isRunning = _remainingDuration.inSeconds > 0;

    return Scaffold(
      appBar: AppBar(title: const Text('침대 제어')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // ✅ 침대 ON/OFF
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('침대 흔들기',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    Switch(
                      value: _isOn,
                      activeColor: Colors.deepPurple,
                      onChanged: (val) {
                        setState(() => _isOn = val);
                        if (!val) {
                          _countdownTimer?.cancel();
                          _remainingDuration = Duration.zero;
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ✅ 강도 슬라이더
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('강도: ${_intensity.toInt()}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                Slider(
                  value: _intensity,
                  min: 1,
                  max: 10,
                  divisions: 9,
                  label: _intensity.toInt().toString(),
                  onChanged: _isOn ? (val) => setState(() => _intensity = val) : null,
                  activeColor: Colors.deepPurple,
                  inactiveColor: Colors.grey.shade300,
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ✅ 타이머 설정 + 시작
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showTimerPicker(context),
                    icon: const Icon(Icons.timer),
                    label: Text(
                      '${_selectedDuration.inMinutes}분 설정',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple.shade100,
                      foregroundColor: Colors.deepPurple.shade900,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isOn
                        ? () => _startTimer(_selectedDuration)
                        : null,
                    child: const Text('타이머 시작'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // ✅ 남은 시간 표시
            if (isRunning)
              Column(
                children: [
                  const Text('남은 시간',
                      style: TextStyle(fontSize: 14, color: Colors.grey)),
                  Text(
                    _format(_remainingDuration),
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurple,
                    ),
                  ),
                ],
              ),

            const Spacer(),

            // ✅ 상태 요약
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.bed),
                      const SizedBox(width: 8),
                      Text(
                        '상태: ${_isOn ? 'ON' : 'OFF'}',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('강도: ${_intensity.toInt()}  /  타이머: ${_selectedDuration.inMinutes}분'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
