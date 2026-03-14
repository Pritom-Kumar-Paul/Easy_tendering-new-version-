import 'package:flutter/material.dart';
import 'package:flutter_application_7/login_page.dart';
import 'package:flutter_application_7/sign_up_page.dart';

class LoginAndSignUp extends StatefulWidget {
  const LoginAndSignUp({super.key});

  @override
  State<LoginAndSignUp> createState() => _LoginAndSignUpState();
}

class _LoginAndSignUpState extends State<LoginAndSignUp> {
  bool isLogin = true;

  void togglePage() {
    setState(() {
      isLogin = !isLogin;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Prothome ekti gorgeous background gradient add korchi
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1E3C72), // Deep Navy
              Color(0xFF2A5298), // Royal Blue
              Color(0xFFF8F9FD), // Soft White/Blue
            ],
            stops: [0.0, 0.4, 1.0],
          ),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 500),
          // Switcher-er transitions style (Fade + Scale)
          transitionBuilder: (Widget child, Animation<double> animation) {
            return FadeTransition(
              opacity: animation,
              child: ScaleTransition(
                scale: animation.drive(
                  Tween(begin: 0.95, end: 1.0).chain(CurveTween(curve: Curves.easeOut)),
                ),
                child: child,
              ),
            );
          },
          // Unique key use kora hoyeche transition trigger korar jonno
          child: isLogin
              ? LoginPage(key: const ValueKey('LoginPage'), onPressed: togglePage)
              : SignUp(key: const ValueKey('SignUpPage'), onPressed: togglePage),
        ),
      ),
    );
  }
}