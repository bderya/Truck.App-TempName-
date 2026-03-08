import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// High-contrast slide toggle for driver Online/Offline.
/// When [isOnline], shows a pulsating green dot to indicate live connection.
class OnlineOfflineToggle extends StatelessWidget {
  const OnlineOfflineToggle({
    super.key,
    required this.isOnline,
    required this.onChanged,
    this.enabled = true,
  });

  final bool isOnline;
  final ValueChanged<bool> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isOnline) _PulsatingGreenDot(),
        const SizedBox(height: 8),
        _SlideToggle(
          isOnline: isOnline,
          onChanged: onChanged,
          enabled: enabled,
        ),
      ],
    );
  }
}

class _PulsatingGreenDot extends StatefulWidget {
  @override
  State<_PulsatingGreenDot> createState() => _PulsatingGreenDotState();
}

class _PulsatingGreenDotState extends State<_PulsatingGreenDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _scale = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _opacity = Tween<double>(begin: 0.7, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _opacity.value,
          child: Transform.scale(
            scale: _scale.value,
            child: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: Colors.green.shade600,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.green.withValues(alpha: 0.6),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SlideToggle extends StatelessWidget {
  const _SlideToggle({
    required this.isOnline,
    required this.onChanged,
    required this.enabled,
  });

  final bool isOnline;
  final ValueChanged<bool> onChanged;
  final bool enabled;

  static const double _width = 200;
  static const double _height = 52;
  static const double _thumbSize = 44;
  static const double _padding = 4;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        height: _height,
        width: _width,
        decoration: BoxDecoration(
          color: isOnline ? Colors.green.shade900 : Colors.grey.shade800,
          borderRadius: BorderRadius.circular(_height / 2),
          border: Border.all(
            color: isOnline ? Colors.green.shade400 : Colors.grey.shade600,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: enabled ? () => onChanged(false) : null,
                    behavior: HitTestBehavior.opaque,
                    child: Center(
                      child: Text(
                        'offline'.tr(),
                        style: TextStyle(
                          color: isOnline ? Colors.white38 : Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: enabled ? () => onChanged(true) : null,
                    behavior: HitTestBehavior.opaque,
                    child: Center(
                      child: Text(
                        'online'.tr(),
                        style: TextStyle(
                          color: isOnline ? Colors.white : Colors.white38,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Positioned(
              left: _padding + (isOnline ? (_width - _padding * 2 - _thumbSize) : 0),
              top: _padding,
              child: GestureDetector(
                onTap: enabled ? () => onChanged(!isOnline) : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  width: _thumbSize,
                  height: _thumbSize,
                  decoration: BoxDecoration(
                    color: isOnline ? Colors.green.shade400 : Colors.grey.shade400,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    isOnline ? Icons.wifi : Icons.wifi_off,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
