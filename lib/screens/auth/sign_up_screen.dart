import '../../constants.dart';
import 'sign_in_screen.dart';
import 'package:flutter/material.dart';

import 'components/sign_up_form.dart';

class SignUpScreen extends StatelessWidget {
  final String? role;
  final _formKey = GlobalKey<FormState>();

  SignUpScreen({super.key, this.role});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/onboarding_bg.jpg',
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Color.fromARGB(200, 0, 0, 0),
                      Color.fromARGB(120, 0, 0, 0),
                      Color.fromARGB(40, 0, 0, 0),
                      Colors.transparent,
                    ],
                    stops: [0.0, 0.25, 0.55, 1.0],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(defaultPadding),
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 24,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Create Account",
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall!
                              .copyWith(fontWeight: FontWeight.bold),
                        ),
                        Row(
                          children: [
                            const Text("Already have an account?"),
                            TextButton(
                              onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => SignInScreen(),
                                  )),
                              child: const Text(
                                "Sign In!",
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: defaultPadding * 1.5),
                        SignUpForm(formKey: _formKey, role: role, centerButton: true),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}