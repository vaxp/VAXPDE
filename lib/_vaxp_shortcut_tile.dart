import 'package:flutter/material.dart';

class MacShortcutTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;
  const MacShortcutTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final Color bg = active
        ? Theme.of(context).colorScheme.primary.withOpacity(0.18)
        : Colors.white.withOpacity(0.7);
    final Color border = active
        ? Theme.of(context).colorScheme.primary.withOpacity(0.45)
        : Colors.black12;
    final Color iconColor = active
        ? Theme.of(context).colorScheme.primary
        : Colors.black54;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: border, width: 1.2),
          ),
          child: Row(
            children: [
              Icon(icon, color: iconColor, size: 28),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: iconColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}