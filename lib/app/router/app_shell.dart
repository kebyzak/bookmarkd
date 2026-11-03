import 'package:bookmarkd/app/theme/app_theme.dart';
import 'package:bookmarkd/app/theme/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

enum _Tab {
  reading('Reading'),
  shelf('Shelf'),
  discover('Discover'),
  you('You');

  const _Tab(this.label);

  final String label;
}

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: shell,
    bottomNavigationBar: _BottomBar(
      index: shell.currentIndex,
      onTap: (i) {
        HapticFeedback.selectionClick();
        shell.goBranch(i, initialLocation: i == shell.currentIndex);
      },
    ),
  );
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.index, required this.onTap});

  final int index;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: context.colors.background,
      border: Border(top: BorderSide(color: context.colors.border)),
    ),
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Space.xs, 6, Space.xs, 0),
        child: SizedBox(
          height: 56,
          child: Row(
            children: [
              for (final tab in _Tab.values)
                Expanded(
                  child: _TabButton(tab: tab, active: tab.index == index, onTap: () => onTap(tab.index)),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _TabButton extends StatelessWidget {
  const _TabButton({required this.tab, required this.active, required this.onTap});

  final _Tab tab;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? context.colors.textPrimary : context.colors.textSecondary;
    return Semantics(
      selected: active,
      button: true,
      label: tab.label,
      child: InkResponse(
        onTap: onTap,
        radius: 32,
        child: ExcludeSemantics(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CustomPaint(size: const Size.square(24), painter: _TabIconPainter(tab, color)),
              const SizedBox(height: Space.xxs),
              Text(
                tab.label,
                maxLines: 1,
                textScaler: MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.2),
                style: TextStyle(fontSize: 11, fontWeight: active ? FontWeight.w600 : FontWeight.w500, color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabIconPainter extends CustomPainter {
  const _TabIconPainter(this.tab, this.color);

  final _Tab tab;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path();
    switch (tab) {
      case _Tab.reading:
        path
          ..moveTo(3, 5.5)
          ..cubicTo(5.5, 4.5, 8.5, 4.5, 12, 6)
          ..cubicTo(15.5, 4.5, 18.5, 4.5, 21, 5.5)
          ..lineTo(21, 19)
          ..cubicTo(18.5, 18, 15.5, 18, 12, 19.5)
          ..cubicTo(8.5, 18, 5.5, 18, 3, 19)
          ..close()
          ..moveTo(12, 6)
          ..lineTo(12, 19.5);
      case _Tab.shelf:
        path
          ..moveTo(5, 4)
          ..lineTo(5, 19)
          ..moveTo(9, 4)
          ..lineTo(9, 19)
          ..moveTo(13.5, 5)
          ..lineTo(17.5, 19)
          ..moveTo(3, 20)
          ..lineTo(21, 20);
      case _Tab.discover:
        path
          ..addOval(Rect.fromCircle(center: const Offset(11, 11), radius: 7))
          ..moveTo(20, 20)
          ..lineTo(16, 16);
      case _Tab.you:
        path
          ..addOval(Rect.fromCircle(center: const Offset(12, 8), radius: 4))
          ..moveTo(4, 20)
          ..cubicTo(5.5, 16, 8.5, 14, 12, 14)
          ..cubicTo(15.5, 14, 18.5, 16, 20, 20);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_TabIconPainter old) => old.tab != tab || old.color != color;
}
