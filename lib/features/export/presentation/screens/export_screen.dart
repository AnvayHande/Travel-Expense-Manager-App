import 'package:flutter/material.dart';
import '../../../../core/widgets/custom_app_bar.dart';

class ExportScreen extends StatelessWidget {
  const ExportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(title: 'Export'),
      body: const Center(
        child: Text('Export Screen'),
      ),
    );
  }
}
