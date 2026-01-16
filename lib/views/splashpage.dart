import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pawpal/myconfig.dart';
import 'package:pawpal/views/mainpage.dart';
import 'package:pawpal/models/user.dart';
import 'package:pawpal/views/loginpage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    
    // Setup animations
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _animationController.forward();
    _checkAutoLogin();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  /**
   * REQUIREMENT: Load user info on app startup
   * 
   * This function is called when the app starts (splash screen).
   * It attempts to restore the user session from SharedPreferences.
   * 
   * Process:
   * 1. First, try to load saved user_data from SharedPreferences
   *    - If user_data exists and is valid → Navigate to MainPage (auto-login)
   *    - This is the primary method (fastest, no API call needed)
   * 
   * 2. Fallback: If user_data doesn't exist, try auto-login with email/password
   *    - Only if "Remember Me" was checked during login
   *    - Makes API call to verify credentials
   *    - Updates SharedPreferences with fresh user data
   * 
   * 3. If both fail → Navigate to LoginPage
   * 
   * This ensures users don't need to login every time they open the app.
   */
  void _checkAutoLogin() async {
    // Add a minimum splash duration for better UX (2 seconds)
    await Future.delayed(const Duration(seconds: 2));

    SharedPreferences prefs = await SharedPreferences.getInstance();
    
    // REQUIREMENT: Load user info on app startup
    // First, try to load saved user data from SharedPreferences
    // This is the fastest method - no API call needed
    String? userDataJson = prefs.getString('user_data');
    if (userDataJson != null && userDataJson.isNotEmpty) {
      try {
        // Parse JSON string to User object
        Map<String, dynamic> userData = jsonDecode(userDataJson);
        User user = User.fromJson(userData);
        
        // If user data is valid, navigate directly to MainPage
        // This provides instant login without API call
        if (mounted && user.userId != null) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => MainPage(user: user)),
          );
          return;  // Exit early - user session restored successfully
        }
      } catch (e) {
        print("Error loading user data: $e");
        // If parsing fails, continue to fallback method
      }
    }
    
    // Fallback: Auto-login with email/password (if Remember Me was checked)
    // This makes an API call to verify credentials and get fresh user data
    bool? rememberMe = prefs.getBool('rememberme');
    String? email = prefs.getString('email');
    String? password = prefs.getString('password');

    if (rememberMe == true && email != null && email.isNotEmpty && password != null && password.isNotEmpty) {
      _autoLogin(email, password);  // Attempt API-based auto-login
    } else {
      // No saved session - navigate to login page
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginPage()),
        );
      }
    }
  }

  void _autoLogin(String email, String password) async {
    try {
      String baseUrl = MyConfig().baseUrl;
      if (baseUrl.endsWith('/')) {
        baseUrl = baseUrl.substring(0, baseUrl.length - 1);
      }
      
      var response = await http.post(
        Uri.parse("$baseUrl/pawpal/api/login_user.php"),
        body: {"email": email, "password": password},
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Connection timeout');
        },
      );

      if (mounted) {
        if (response.statusCode == 200) {
          var jsondata = jsonDecode(response.body);
          if (jsondata['status'] == 'success') {
            User user = User.fromJson(jsondata['data']);
            
            /**
             * REQUIREMENT: Save user session using SharedPreferences
             * 
             * After successful auto-login, save user data to SharedPreferences.
             * This ensures the session persists for future app launches.
             */
            SharedPreferences prefs = await SharedPreferences.getInstance();
            await prefs.setString('user_data', jsonEncode(user.toJson()));
            await prefs.setString('user_id', user.userId ?? '');
            
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => MainPage(user: user)),
            );
            return;
          }
        }
        // If auto-login fails, go to login page
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginPage()),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginPage()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.black,
              Colors.grey.shade900,
              Colors.grey.shade800,
            ],
          ),
        ),
        child: Center(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // App Icon/Logo
                  Container(
                    padding: const EdgeInsets.all(30),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.pets,
                      size: 80,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 32),
                  
                  // App Name
                  const Text(
                    'PawPal',
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Tagline
                  Text(
                    'Your Pet Adoption Companion',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withOpacity(0.9),
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 48),
                  
                  // Loading Indicator
                  const SizedBox(
                    width: 40,
                    height: 40,
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      strokeWidth: 3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
