import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

class TempController extends ChangeNotifier {
  double _temperature = 36.5;
  double get temperature => _temperature;

  final List<double> _history = [];
  List<double> get history => List.unmodifiable(_history); // 외부에서 읽기 전용

  Timer? _timer;

  TempController() {
    _startAutoUpdate();
  }

  void _startAutoUpdate() {
    final random = Random();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) {
      final newTemp = 35.0 + random.nextDouble() * 4.0;
      _temperature = double.parse(newTemp.toStringAsFixed(2));

      _history.add(_temperature);
      if (_history.length > 10) {
        _history.removeAt(0);
      }

      notifyListeners();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
