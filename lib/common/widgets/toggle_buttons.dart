import 'package:flutter/material.dart';

class QuickToggleButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const QuickToggleButton({
    super.key,
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          height: 60,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: active ? Colors.blue.withOpacity(0.15) : Colors.white.withOpacity(0.6),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: active ? Colors.blue.withOpacity(0.4) : Colors.black.withOpacity(0.08),
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: active ? Colors.blue : Colors.black87,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: active ? Colors.blue : Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SmallToggleButton extends StatelessWidget {
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  const SmallToggleButton({
    super.key,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: active ? Colors.blue.withOpacity(0.15) : Colors.white.withOpacity(0.6),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: active ? Colors.blue.withOpacity(0.4) : Colors.black.withOpacity(0.08),
              width: 1.5,
            ),
          ),
          child: Icon(
            icon,
            color: active ? Colors.blue : Colors.black87,
            size: 28,
          ),
        ),
      ),
    );
  }
}