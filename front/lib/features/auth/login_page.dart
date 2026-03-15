import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:planto/core/services/auth_service.dart';
import 'package:planto/core/services/house_service.dart';
import 'package:planto/core/theme/app_theme.dart';
import 'package:planto/features/home/home_page.dart';
import 'package:planto/features/auth/register_page.dart';
import 'package:planto/features/auth/forgot_password_page.dart';
import 'package:planto/features/onboarding/onboarding_page.dart';

/// Login page with PLANTO design
class LoginPage extends StatefulWidget {
  final AuthService? authService;
  final HouseService? houseService;
  final Future<String> Function()? googleLoginFn;

  const LoginPage({super.key, this.authService, this.houseService, this.googleLoginFn});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  late final AuthService _authService = widget.authService ?? AuthService();
  late final HouseService _houseService = widget.houseService ?? HouseService();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Navigate to home or onboarding depending on whether user has houses
  Future<void> _navigateAfterLogin(String email) async {
    try {
      final houses = await _houseService.getMyHouses();
      if (!mounted) return;
      if (houses.isEmpty) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => OnboardingPage(userEmail: email)),
        );
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => HomePage(userEmail: email)),
        );
      }
    } catch (_) {
      // On error, go to home page directly
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => HomePage(userEmail: email)),
        );
      }
    }
  }

  Future<void> _handleLogin() async {
    // Validate inputs
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      setState(() => _errorMessage = 'Veuillez remplir tous les champs');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final email = await _authService.login(
        _emailController.text.trim(),
        _passwordController.text,
      );

      if (mounted) {
        await _navigateAfterLogin(email);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleGoogleLogin() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final email = await (widget.googleLoginFn?.call() ?? _authService.loginWithGoogle());

      if (mounted) {
        await _navigateAfterLogin(email);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background with leaf pattern
          _buildBackground(),
          
          // Main content
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Login card
                    _buildLoginCard(),
                    
                    const SizedBox(height: 24),
                    
                    // Sign up link
                    _buildSignUpLink(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackground() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.scaffoldBg(context),
      ),
      child: CustomPaint(
        size: Size.infinite,
        painter: LeafPatternPainter(),
      ),
    );
  }

  Widget _buildLoginCard() {
    return Container(
      constraints: const BoxConstraints(maxWidth: 400),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Logo
              _buildLogo(),
              
              const SizedBox(height: 16),
              
              // Welcome text
              Text(
                'Bon retour parmi nous ! 🌿',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppTheme.textSecondaryC(context),
                ),
              ),

              const SizedBox(height: 32),

              // Email field
              Semantics(
                label: 'email_field',
                child: TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    hintText: 'Adresse email',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Password field
              Semantics(
                label: 'password_field',
                child: TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    hintText: 'Mot de passe',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      ),
                      onPressed: () {
                        setState(() => _obscurePassword = !_obscurePassword);
                      },
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Error message
              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.errorBgLight(context),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.errorBorder(context)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: AppTheme.errorText(context), size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(color: AppTheme.errorText(context), fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
              
              const SizedBox(height: 24),
              
              // Login button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleLogin,
                  child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('SE CONNECTER'),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Forgot password
              TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ForgotPasswordPage()),
                  );
                },
                child: Text(
                  'Mot de passe oublié ?',
                  style: TextStyle(
                    color: AppTheme.textSecondaryC(context),
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Divider
              Row(
                children: [
                  Expanded(child: Divider(color: AppTheme.divider(context))),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'ou',
                      style: TextStyle(color: AppTheme.textSecondaryC(context)),
                    ),
                  ),
                  Expanded(child: Divider(color: AppTheme.divider(context))),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Social login buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Google
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.divider(context), width: 1),
                    ),
                    child: IconButton(
                      onPressed: _isLoading ? null : _handleGoogleLogin,
                      icon: SvgPicture.asset(
                        'assets/icons/google_logo.svg',
                        width: 22,
                        height: 22,
                      ),
                      padding: const EdgeInsets.all(12),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Column(
      children: [
        // Leaf icon
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            border: Border.all(color: AppTheme.primaryColor, width: 2),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(
            Icons.eco_outlined,
            size: 32,
            color: AppTheme.primaryColor,
          ),
        ),
        const SizedBox(height: 12),
        // App name
        Text(
          'PLANTO',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimaryC(context),
            letterSpacing: 2,
          ),
        ),
      ],
    );
  }

  Widget _buildSignUpLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Pas encore de compte ? ',
          style: TextStyle(color: AppTheme.textSecondaryC(context)),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const RegisterPage()),
            );
          },
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(
            '[S\'inscrire]',
            style: TextStyle(
              color: AppTheme.textPrimaryC(context),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

/// Custom painter for leaf pattern background
class LeafPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.secondaryColor.withAlpha(38)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // Draw decorative leaves in corners
    _drawLeaf(canvas, paint, Offset(size.width * 0.1, size.height * 0.15), 0.8);
    _drawLeaf(canvas, paint, Offset(size.width * 0.05, size.height * 0.25), 0.6, flipX: true);
    _drawLeaf(canvas, paint, Offset(size.width * 0.85, size.height * 0.1), 0.7, flipX: true);
    _drawLeaf(canvas, paint, Offset(size.width * 0.9, size.height * 0.2), 0.5);
    _drawLeaf(canvas, paint, Offset(size.width * 0.08, size.height * 0.75), 0.7);
    _drawLeaf(canvas, paint, Offset(size.width * 0.92, size.height * 0.8), 0.6, flipX: true);
  }

  void _drawLeaf(Canvas canvas, Paint paint, Offset position, double scale, {bool flipX = false}) {
    canvas.save();
    canvas.translate(position.dx, position.dy);
    if (flipX) canvas.scale(-1, 1);
    canvas.scale(scale);

    final path = Path();
    // Simple leaf shape
    path.moveTo(0, 0);
    path.quadraticBezierTo(30, -20, 60, -60);
    path.quadraticBezierTo(40, -40, 20, -30);
    path.quadraticBezierTo(10, -20, 0, 0);
    
    // Stem
    path.moveTo(0, 0);
    path.lineTo(0, 40);

    canvas.drawPath(path, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
