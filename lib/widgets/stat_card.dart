import 'package:flutter/material.dart';

class StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String unit;
  final IconData icon;
  final Color backgroundColor;
  final Color iconColor;

  const StatCard({
    Key? key,
    required this.title,
    required this.value,
    required this.unit,
    required this.icon,
    this.backgroundColor = const Color(0xFF18181B), // Standardfärg är mörkgrå
    this.iconColor = Colors.white,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
        border: backgroundColor == const Color(0xFFDC2626) // Röd färg
            ? null // Ingen border för röd bakgrund
            : Border.all(
                color: const Color(0xFF4C4C4C), // grå border
                width: 1,
              ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 18),
              const SizedBox(width: 8),
              Text(title, style: TextStyle(color: Colors.grey.shade300, fontSize: 14)),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                unit,
                style: TextStyle(color: const Color.fromARGB(255, 255, 255, 255), fontSize: 14),
              ),
            ],
          ),
        ],
      ),
    );
  }
}