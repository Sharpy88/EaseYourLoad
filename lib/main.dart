import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

final notifications = NotificationService();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize Firebase before anything that depends on it
  await Firebase.initializeApp();
  await notifications.initialize();
  runApp(const AppEntry());
}

/// AppEntry routes between sign-in flow and the main app depending on auth state.
class AppEntry extends StatelessWidget {
  const AppEntry({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // While waiting for auth state, show a splash
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const MaterialApp(home: Scaffold(body: Center(child: CircularProgressIndicator())));
        }
        final user = snapshot.data;
        if (user == null) return const SignInApp();
        // Optionally require email verification
        if (!user.emailVerified) return SignInApp(showVerifyNotice: true);
        // Signed in and verified: show the main app
        return const MentalLoadApp();
      },
    );
  }
}

class SignInApp extends StatelessWidget {
  final bool showVerifyNotice;
  const SignInApp({super.key, this.showVerifyNotice = false});

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Ease Your Mind - Sign in',
    home: SignInPage(showVerifyNotice: showVerifyNotice),
  );
}

class SignInPage extends StatefulWidget {
  final bool showVerifyNotice;
  const SignInPage({super.key, this.showVerifyNotice = false});
  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool loading = false;
  String? message;

  Future<void> _signIn() async {
    setState(() { loading = true; message = null; });
    try {
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text,
      );
      if (!(cred.user?.emailVerified ?? false)) {
        setState(() {
          message = 'Please verify your email address. Check your inbox.';
        });
      }
    } on FirebaseAuthException catch (e) {
      setState(() { message = e.message; });
    } finally {
      setState(() { loading = false; });
    }
  }

  Future<void> _register() async {
    setState(() { loading = true; message = null; });
    try {
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text,
      );
      await cred.user?.sendEmailVerification();
      setState(() { message = 'Account created. Verification email sent.'; });
    } on FirebaseAuthException catch (e) {
      setState(() { message = e.message; });
    } finally {
      setState(() { loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign in')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.showVerifyNotice) ...[
              const Text('Your email is not verified. Please verify before continuing.'),
              const SizedBox(height: 12),
            ],
            TextFormField(
              controller: emailController,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: passwordController,
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            const SizedBox(height: 12),
            if (message != null) Text(message!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: loading ? null : _signIn,
                    child: loading ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Sign in'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: loading ? null : _register,
                    child: const Text('Create account'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () async {
                final email = emailController.text.trim();
                if (email.isEmpty) {
                  setState(() { message = 'Enter your email to receive reset link.'; });
                  return;
                }
                await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
                setState(() { message = 'Password reset email sent.'; });
              },
              child: const Text('Forgot password?'),
            ),
          ],
        ),
      ),
    );
  }
}

// --- Existing app code starts here (unchanged for the most part) ---

class MentalLoadApp extends StatelessWidget {
  const MentalLoadApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Ease Your Mind',
    theme: ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xfff4efe9),
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xff3c4f3f),
        primary: const Color(0xff3c4f3f),
        secondary: const Color(0xffb2865b),
        surface: const Color(0xfffcfbf8),
        onSurface: const Color(0xff232724),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xfff4efe9),
        elevation: 0,
        foregroundColor: Color(0xff2f322c),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        color: const Color(0xfffcfbf8),
        shadowColor: const Color(0x14000000),
      ),
      textTheme: ThemeData.light().textTheme.copyWith(
        headlineMedium: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 28,
          letterSpacing: -0.5,
          color: Color(0xff232724),
        ),
        titleLarge: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 20,
          letterSpacing: -0.4,
          color: Color(0xff232724),
        ),
        bodyMedium: const TextStyle(
          fontSize: 14,
          color: Color(0xff5f655f),
          height: 1.45,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: const Color(0xfff4efe9),
        elevation: 0,
        indicatorColor: const Color(0xff3c4f3f).withValues(alpha: 0.14),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          return const TextStyle(fontWeight: FontWeight.w600);
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? const Color(0xff3c4f3f) : const Color(0xff6c706b),
          );
        }),
      ),
    ),
    home: const HomeShell(),
  );
}

// --- rest of the original main.dart file unchanged beyond this point ---
