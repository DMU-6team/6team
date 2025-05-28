import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/temp_controller.dart';
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}


class _HomeScreenState extends State<HomeScreen> {
  bool _isBedOn = false; // 침대 제어 상태

  @override
  Widget build(BuildContext context) {
    final temp = context.watch<TempController>().temperature;
    return Scaffold(
      body: Column(
        children: [
          // 📷 카메라 (2 비율)
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Image.asset(
                  'assets/images/testImg.jpg',
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),

          // 🤖 침대 제어 + 🌡️ 온도 (1 비율)
          Expanded(
            flex: 1,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  // 🌙 침대 제어 카드
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _isBedOn ? Colors.deepPurple.shade200 : Colors.deepPurple.shade50,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(2, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.bed_outlined,
                              color: _isBedOn ? Colors.white : Colors.deepPurple,
                              size: 28),
                          const SizedBox(height: 10),
                          Text(
                            '침대 제어',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: _isBedOn ? Colors.white : Colors.deepPurple,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Switch.adaptive(
                            value: _isBedOn,
                            activeColor: Colors.white,
                            inactiveTrackColor: Colors.deepPurple.shade200,
                            onChanged: (value) {
                              setState(() {
                                _isBedOn = value;
                              });
                            },
                          ),
                          Text(
                            _isBedOn ? '켜짐' : '꺼짐',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: _isBedOn ? Colors.white : Colors.deepPurple,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(width: 12),

                  // 🌡️ 온도 카드
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(2, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.thermostat, color: Colors.deepOrange, size: 28),
                          const SizedBox(height: 10),
                          const Text(
                            '현재 온도',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.deepOrange,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '${temp.toStringAsFixed(1)}℃',
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w700,
                              color: Colors.deepOrange,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),


          // 🎵 음악 컨트롤 (1 비율)
          Expanded(
            flex: 1,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('🎵 재생 중: 자장가1.mp3', style: TextStyle(fontSize: 16)),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        IconButton(
                          onPressed: () {},
                          icon: const Icon(Icons.skip_previous, size: 32),
                        ),
                        IconButton(
                          onPressed: () {},
                          icon: const Icon(Icons.play_arrow, size: 32),
                        ),
                        IconButton(
                          onPressed: () {},
                          icon: const Icon(Icons.skip_next, size: 32),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
