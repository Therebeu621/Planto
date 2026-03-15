import 'package:flutter/material.dart';
import 'package:planto/core/services/profile_service.dart';
import 'package:planto/core/theme/app_theme.dart';

/// Email verification page shown after registration
class EmailVerificationPage extends StatefulWidget {
  final String email;
  final VoidCallback onVerified;
  final ProfileService? profileService;

  const EmailVerificationPage({
    super.key,
    required this.email,
    required this.onVerified,
    this.profileService,
  });

  @override
  State<EmailVerificationPage> createState() => _EmailVerificationPageState();
}

class _EmailVerificationPageState extends State<EmailVerificationPage> {
  late final ProfileService _profileService = widget.profileService ?? ProfileService();
  final _codeController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _handleVerify() async {
    if (_codeController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Veuillez entrer le code recu');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _profileService.verifyEmail(_codeController.text.trim());
      if (mounted) {
        setState(() {
          _isLoading = false;
          _successMessage = 'Email verifie avec succes !';
        });
        await Future.delayed(const Duration(seconds: 1));
        widget.onVerified();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  Future<void> _handleResend() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      await _profileService.resendVerification();
      if (mounted) {
        setState(() {
          _isLoading = false;
          _successMessage = 'Code renvoye !';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verification email'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(
                        Icons.mark_email_read,
                        size: 48,
                        color: AppTheme.primaryColor,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Verifiez votre email',
                        style: Theme.of(context).textTheme.titleLarge,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Un code a 6 chiffres a ete envoye a\n${widget.email}',
                        style: TextStyle(color: AppTheme.textSecondaryC(context)),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      TextField(
                        controller: _codeController,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 24, letterSpacing: 8),
                        decoration: const InputDecoration(
                          hintText: '000000',
                          counterText: '',
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (_errorMessage != null)
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: AppTheme.errorBgLight(context),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppTheme.errorBorder(context)),
                          ),
                          child: Text(
                            _errorMessage!,
                            style: TextStyle(color: AppTheme.errorText(context), fontSize: 14),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      if (_successMessage != null)
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green.shade200),
                          ),
                          child: Text(
                            _successMessage!,
                            style: TextStyle(color: Colors.green.shade700, fontSize: 14),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _handleVerify,
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('VERIFIER'),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _isLoading ? null : _handleResend,
                        child: const Text('Renvoyer le code'),
                      ),
                      TextButton(
                        onPressed: () => widget.onVerified(),
                        child: Text(
                          'Passer pour le moment',
                          style: TextStyle(color: AppTheme.textSecondaryC(context)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
