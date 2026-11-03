import 'package:bookmarkd/app/theme/app_theme.dart';
import 'package:bookmarkd/app/theme/tokens.dart';
import 'package:flutter/material.dart';

enum LoadStatus { initial, loading, success, failure }

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, this.message, this.action});

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.xl, vertical: Space.xxl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(color: context.colors.accentSoft, shape: BoxShape.circle),
            child: Icon(icon, color: context.colors.accent, size: 28),
          ),
          const SizedBox(height: Space.md),
          Text(title, style: text.titleMedium, textAlign: TextAlign.center),
          if (message != null) ...[
            const SizedBox(height: Space.xs),
            Text(
              message!,
              style: text.bodyMedium?.copyWith(color: context.colors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
          if (action != null) ...[const SizedBox(height: Space.lg), action!],
        ],
      ),
    );
  }
}

class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => EmptyState(
    icon: Icons.cloud_off_rounded,
    title: "That didn't load",
    message: message,
    action: OutlinedButton.icon(
      onPressed: onRetry,
      icon: const Icon(Icons.refresh_rounded, size: 18),
      label: const Text('Try again'),
    ),
  );
}

void showMessage(BuildContext context, String message, {SnackBarAction? action}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message), action: action));
}

class UnsavedChangesGuard extends StatelessWidget {
  const UnsavedChangesGuard({super.key, required this.dirty, required this.child});

  final bool dirty;
  final Widget child;

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !dirty,
    onPopInvokedWithResult: (didPop, _) async {
      if (didPop) return;
      final discard = await showDialog<bool>(
        context: context,
        builder: (d) => AlertDialog(
          title: const Text('Discard changes?'),
          content: const Text("What you've changed here won't be saved."),
          actions: [
            TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Keep editing')),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: context.colors.danger),
              onPressed: () => Navigator.pop(d, true),
              child: const Text('Discard'),
            ),
          ],
        ),
      );
      if (discard == true && context.mounted) Navigator.of(context).pop();
    },
    child: child,
  );
}
