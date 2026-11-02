import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/theme/tokens.dart';
import '../../../../core/widgets/states.dart';
import '../session_cubit.dart';
import 'brand_mark.dart';

class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: BlocBuilder<SessionCubit, SessionState>(
        builder: (context, state) => switch (state) {
          SessionFailure(:final message) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ErrorState(message: message, onRetry: context.read<SessionCubit>().retry),
              TextButton(onPressed: context.read<SessionCubit>().signOut, child: const Text('Sign out')),
            ],
          ),
          _ => const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              BrandMark(size: 56),
              SizedBox(height: Space.lg),
              SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5)),
            ],
          ),
        },
      ),
    ),
  );
}
