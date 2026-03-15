import 'package:flutter/material.dart';
import 'package:planto/core/models/pot_stock.dart';
import 'package:planto/core/services/pot_service.dart';
import 'package:planto/core/theme/app_theme.dart';

class PotStockPage extends StatefulWidget {
  final PotService? potService;

  const PotStockPage({super.key, this.potService});

  @override
  State<PotStockPage> createState() => _PotStockPageState();
}

class _PotStockPageState extends State<PotStockPage> {
  late final PotService _potService = widget.potService ?? PotService();

  List<PotStock> _pots = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPots();
  }

  Future<void> _loadPots() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final pots = await _potService.getPotStock();
      setState(() {
        _pots = pots;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _showAddPotDialog() async {
    final diameterController = TextEditingController();
    final quantityController = TextEditingController(text: '1');
    final labelController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Ajouter des pots',
          style: TextStyle(
            color: AppTheme.textPrimaryC(context),
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: diameterController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Diametre (cm)',
                  hintText: 'Ex: 14',
                  prefixIcon: Icon(Icons.straighten),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Requis';
                  final d = double.tryParse(v);
                  if (d == null || d < 1) return 'Diametre invalide';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: quantityController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Quantite',
                  hintText: 'Ex: 3',
                  prefixIcon: Icon(Icons.inventory_2_outlined),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Requis';
                  final q = int.tryParse(v);
                  if (q == null || q < 1) return 'Quantite invalide';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: labelController,
                decoration: const InputDecoration(
                  labelText: 'Label (optionnel)',
                  hintText: 'Ex: Terre cuite',
                  prefixIcon: Icon(Icons.label_outline),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Annuler', style: TextStyle(color: AppTheme.textSecondaryC(context))),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context, true);
              }
            },
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );

    if (result == true) {
      try {
        await _potService.addToStock(
          diameterCm: double.parse(diameterController.text),
          quantity: int.parse(quantityController.text),
          label: labelController.text.isNotEmpty ? labelController.text : null,
        );
        _loadPots();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Pots ajoutes au stock')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur: $e')),
          );
        }
      }
    }
  }

  Future<void> _showEditQuantityDialog(PotStock pot) async {
    final controller = TextEditingController(text: pot.quantity.toString());

    final result = await showDialog<int?>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Modifier la quantite - ${pot.sizeDisplay}'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Quantite',
            prefixIcon: Icon(Icons.inventory_2_outlined),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: Text('Annuler', style: TextStyle(color: AppTheme.textSecondaryC(context))),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context, -1); // Signal to delete
            },
            child: Text('Supprimer', style: TextStyle(color: AppTheme.errorColor)),
          ),
          ElevatedButton(
            onPressed: () {
              final q = int.tryParse(controller.text);
              if (q != null && q >= 0) {
                Navigator.pop(context, q);
              }
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );

    if (result == null) return;

    try {
      if (result == -1) {
        await _potService.deleteStock(pot.id);
      } else {
        await _potService.updateStock(pot.id, result);
      }
      _loadPots();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg(context),
      appBar: AppBar(
        title: const Text('Stock de pots'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddPotDialog,
        backgroundColor: AppTheme.primaryColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Erreur: $_error', style: TextStyle(color: AppTheme.errorColor)),
                      const SizedBox(height: 16),
                      ElevatedButton(onPressed: _loadPots, child: const Text('Reessayer')),
                    ],
                  ),
                )
              : _pots.isEmpty
                  ? _buildEmptyState()
                  : _buildPotList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppTheme.accentColor.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.inventory_2_outlined,
                size: 48,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Aucun pot en stock',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimaryC(context),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Ajoutez vos pots pour gerer votre inventaire et faciliter les rempotages.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondaryC(context),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _showAddPotDialog,
              icon: const Icon(Icons.add),
              label: const Text('Ajouter des pots'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPotList() {
    final totalPots = _pots.fold<int>(0, (sum, pot) => sum + pot.quantity);
    final availableSizes = _pots.where((p) => p.quantity > 0).length;

    return RefreshIndicator(
      onRefresh: _loadPots,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Summary card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.cardBg(context),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.shadowSoft(context),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                _buildStat('Total', '$totalPots', Icons.inventory_2),
                Container(
                  width: 1,
                  height: 40,
                  color: AppTheme.divider(context),
                ),
                _buildStat('Tailles', '$availableSizes', Icons.straighten),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Pot list
          ...List.generate(_pots.length, (index) {
            final pot = _pots[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildPotCard(pot),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildStat(String label, String value, IconData icon) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: AppTheme.primaryColor, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimaryC(context),
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondaryC(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPotCard(PotStock pot) {
    return GestureDetector(
      onTap: () => _showEditQuantityDialog(pot),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.cardBg(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: pot.isAvailable
                ? AppTheme.borderLight(context)
                : AppTheme.errorBorder(context),
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.shadowSoft(context),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Pot icon with size
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: pot.isAvailable
                    ? AppTheme.accentColor.withOpacity(0.2)
                    : AppTheme.errorBgLight(context),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Text(
                  pot.sizeDisplay,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: pot.isAvailable
                        ? AppTheme.primaryColor
                        : AppTheme.errorText(context),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pot de ${pot.sizeDisplay}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimaryC(context),
                    ),
                  ),
                  if (pot.label != null && pot.label!.isNotEmpty)
                    Text(
                      pot.label!,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondaryC(context),
                      ),
                    ),
                ],
              ),
            ),
            // Quantity badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: pot.isAvailable
                    ? AppTheme.primaryColor.withOpacity(0.1)
                    : AppTheme.errorBgLight(context),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'x${pot.quantity}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: pot.isAvailable
                      ? AppTheme.primaryColor
                      : AppTheme.errorText(context),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right,
              color: AppTheme.textSecondaryC(context),
            ),
          ],
        ),
      ),
    );
  }
}
