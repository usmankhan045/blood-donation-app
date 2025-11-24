import 'package:flutter/material.dart';

class RecipientAlertsScreen extends StatelessWidget {
  const RecipientAlertsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Placeholder: wire to FCM inbox later
    return Scaffold(
      appBar: AppBar(title: const Text('Alerts')),
      body: const Center(
        child: Text('No alerts yet.'),
      ),
    );
  }
}
