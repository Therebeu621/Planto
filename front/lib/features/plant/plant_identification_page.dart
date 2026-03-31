import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:planto/core/models/plant_identification_result.dart';
import 'package:planto/core/services/gemini_service.dart';
import 'package:planto/core/theme/app_theme.dart';
import 'package:planto/features/plant/add_plant_page.dart';

/// Ecran d'analyse IA d'une plante
/// Affiche un loader pendant l'analyse puis redirige vers le formulaire
class PlantIdentificationPage extends StatefulWidget {
  final Uint8List imageBytes;
  final GeminiService? geminiService;
  final Widget Function(
    PlantIdentificationResult? aiData,
    Uint8List imageBytes,
  )?
  addPlantPageBuilder;

  const PlantIdentificationPage({
    super.key,
    required this.imageBytes,
    this.geminiService,
    this.addPlantPageBuilder,
  });

  @override
  State<PlantIdentificationPage> createState() =>
      _PlantIdentificationPageState();
}

class _PlantIdentificationPageState extends State<PlantIdentificationPage>
    with SingleTickerProviderStateMixin {
  late final GeminiService _geminiService =
      widget.geminiService ?? GeminiService();
  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;

  bool _isAnalyzing = true;
  String _statusMessage = 'Analyse de votre plante en cours...';

  @override
  void initState() {
    super.initState();
    _setupAnimation();
    _analyzeImage();
  }

  void _setupAnimation() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _analyzeImage() async {
    try {
      setState(() {
        _statusMessage = 'Envoi de l\'image...';
      });

      await Future.delayed(const Duration(milliseconds: 500));

      setState(() {
        _statusMessage = 'Notre botaniste IA analyse votre plante...';
      });

      final result = await _geminiService.identifyPlant(widget.imageBytes);

      setState(() {
        _statusMessage = 'Plante identifiee !';
        _isAnalyzing = false;
      });

      await Future.delayed(const Duration(milliseconds: 800));

      if (mounted) {
        // Naviguer vers AddPlantPage et propager le resultat
        final addResult = await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) =>
                widget.addPlantPageBuilder?.call(result, widget.imageBytes) ??
                AddPlantPage(aiData: result, aiPhoto: widget.imageBytes),
          ),
        );
        // Propager le resultat a HomePage
        if (mounted) {
          Navigator.of(context).pop(addResult);
        }
      }
    } on GeminiException catch (e) {
      _handleError(e.message);
    } catch (e) {
      _handleError('Erreur inattendue: $e');
    }
  }

  void _handleError(String message) {
    if (!mounted) return;

    setState(() {
      _isAnalyzing = false;
      _statusMessage = 'Identification impossible';
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        scrollable: true,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.error_outline, color: Colors.orange.shade700),
            const SizedBox(width: 12),
            const Expanded(child: Text('Identification impossible')),
          ],
        ),
        content: Text(
          '$message\n\nVous pouvez saisir les informations manuellement.',
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Fermer le dialog
              Navigator.pop(context); // Retourner a l'ecran precedent
            },
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context); // Fermer le dialog
              // Aller vers le formulaire avec la photo
              final addResult = await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      widget.addPlantPageBuilder?.call(
                        null,
                        widget.imageBytes,
                      ) ??
                      AddPlantPage(aiPhoto: widget.imageBytes),
                ),
              );
              // Propager le resultat a HomePage
              if (mounted) {
                Navigator.of(context).pop(addResult);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
            ),
            child: const Text('Saisie manuelle'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.lightBg(context),
      body: SafeArea(
        child: Column(
          children: [
            // Header avec bouton retour
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.cardBg(context),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.shadowSoft(context),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.arrow_back, size: 20),
                    ),
                  ),
                ],
              ),
            ),

            // Contenu principal
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Image avec animation
                    ScaleTransition(
                      scale: _pulseAnimation,
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final imageSize = (constraints.maxWidth * 0.5).clamp(
                            120.0,
                            180.0,
                          );
                          return Container(
                            width: imageSize,
                            height: imageSize,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.primaryColor.withOpacity(0.3),
                                  blurRadius: 30,
                                  spreadRadius: 5,
                                ),
                              ],
                            ),
                            child: ClipOval(
                              child: Image.memory(
                                widget.imageBytes,
                                fit: BoxFit.cover,
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 48),

                    // Icone IA
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: _isAnalyzing
                            ? Colors.purple.withOpacity(0.1)
                            : AppTheme.primaryColor.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        _isAnalyzing ? '✨' : '🌱',
                        style: const TextStyle(fontSize: 40),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Message de statut
                    Text(
                      _statusMessage,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: _isAnalyzing
                            ? AppTheme.textGreyDark(context)
                            : AppTheme.primaryColor,
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Loader ou checkmark
                    if (_isAnalyzing)
                      SizedBox(
                        width: 40,
                        height: 40,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.purple.shade400,
                          ),
                        ),
                      )
                    else
                      Icon(
                        Icons.check_circle,
                        size: 40,
                        color: AppTheme.primaryColor,
                      ),

                    const SizedBox(height: 48),

                    // Texte explicatif
                    if (_isAnalyzing)
                      Text(
                        'Notre IA botaniste analyse la forme des feuilles,\nles couleurs et les caracteristiques de votre plante...',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.textGrey(context),
                          height: 1.5,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
