import 'package:flutter/material.dart';

class QuickActionButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;
  const QuickActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
    Key? key,
  }) : super(key: key);

  @override
  State<QuickActionButton> createState() => _QuickActionButtonState();
}

class _QuickActionButtonState extends State<QuickActionButton> {
  bool _pressed = false;

  Color _getColor(BuildContext context) {
    if (_pressed) {
      return Theme.of(context).colorScheme.primary.withOpacity(0.7);
    }
    if (widget.active) {
      return Theme.of(context).colorScheme.primary;
    }
    return Theme.of(context).colorScheme.surfaceVariant;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(32),
            onTap: widget.onTap,
            onHighlightChanged: (v) => setState(() => _pressed = v),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: CircleAvatar(
                radius: 28,
                backgroundColor: _getColor(context),
                child: Icon(widget.icon, size: 32, color: widget.active ? Colors.white : null),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(widget.label, style: const TextStyle(fontSize: 13)),
      ],
    );
  }
}