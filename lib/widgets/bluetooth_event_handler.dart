import 'package:flutter/material.dart';

class BluetoothEventHandler extends StatelessWidget {
  final String event;
  final Color color;

  const BluetoothEventHandler({
    super.key,
    required this.event,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      event,
      style: TextStyle(color: color),
    );
  }
}