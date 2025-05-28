import 'package:flutter/material.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('내 계정'),
      ),
      body: const Center(
        child: Text('여기에 사용자 정보나 설정 화면 넣을 수 있어요'),
      ),
    );
  }
}
