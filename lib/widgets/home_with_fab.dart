import 'package:flutter/material.dart';
import 'package:fashionmobile/page/home.dart';
import 'package:fashionmobile/widgets/chat_dialog.dart';

class HomeWithFloatingButton extends StatelessWidget {
  const HomeWithFloatingButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: const HomePage(),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 60.0, right: 10.0),
        child: FloatingActionButton(
          onPressed: () {
            showDialog(
              context: context,
              builder: (context) => const ChatDialog(),
            );
          },
          mini: true,
          child: const Icon(Icons.chat),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}
