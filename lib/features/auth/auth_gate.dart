import 'package:chat_app/features/Base/main_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/notification/notification_service.dart';
import '../Home/home_view.dart';
import 'controller.dart';
import 'forget_password/reset_password.dart';
import 'signin/view.dart';

// Decides the screen:
//   checking reset link  -> spinner
//   reset link is OK     -> Reset Password
//   logged in            -> Home
//   logged out           -> Sign In
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // If the reset link did not work, tell the user why.
    ref.listen<AsyncValue<dynamic>>(sessionProvider, (previous, next) {
      final session = next.value;
      if (session != null) {
        NotificationService.syncTokenForLoggedInUser();
      }
    });

    final recovery = ref.watch(passwordRecoveryProvider);
    final session = ref.watch(sessionProvider);

    if (recovery.status == RecoveryStatus.processing) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (recovery.status == RecoveryStatus.ready) {
      return const ResetPasswordView();
    }

    return session.when(
      data: (s) => s == null ? const SignInView() : const MainScreen(),
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => const SignInView(),
    );
  }
}