import 'package:flutter/material.dart';
import 'package:planto/core/services/room_service.dart';
import 'package:planto/core/theme/app_theme.dart';
import 'package:planto/core/utils/api_error_formatter.dart';

class AddRoomDialog extends StatefulWidget {
  final RoomService? roomService;

  const AddRoomDialog({super.key, this.roomService});

  @override
  State<AddRoomDialog> createState() => _AddRoomDialogState();
}

class _AddRoomDialogState extends State<AddRoomDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  late final RoomService _roomService = widget.roomService ?? RoomService();
  bool _isLoading = false;
  String _selectedType = 'LIVING_ROOM';

  final List<Map<String, dynamic>> _roomTypes = [
    {'name': 'Salon', 'icon': '\u{1F6CB}\u{FE0F}', 'value': 'LIVING_ROOM'},
    {'name': 'Chambre', 'icon': '\u{1F6CF}\u{FE0F}', 'value': 'BEDROOM'},
    {'name': 'Cuisine', 'icon': '\u{1F373}', 'value': 'KITCHEN'},
    {'name': 'Salle de bain', 'icon': '\u{1F6BF}', 'value': 'BATHROOM'},
    {'name': 'Bureau', 'icon': '\u{1F4BB}', 'value': 'OFFICE'},
    {'name': 'Balcon', 'icon': '\u{1F33F}', 'value': 'BALCONY'},
    {'name': 'Jardin', 'icon': '\u{1F333}', 'value': 'GARDEN'},
    {'name': 'Autre', 'icon': '\u{1F3E0}', 'value': 'OTHER'},
  ];

  Future<void> _submit() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        await _roomService.createRoom(
          _nameController.text.trim(),
          _selectedType,
        );
        if (mounted) {
          Navigator.of(context).pop(true);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(formatApiError(e)),
              backgroundColor: Colors.red,
            ),
          );
          setState(() => _isLoading = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    const gridSpacing = 8.0;
    final availableWidth = screenWidth - 80;
    final useTwoColumns = availableWidth < 320;
    final crossAxisCount = useTwoColumns ? 2 : 3;
    final itemWidth =
        (availableWidth - ((crossAxisCount - 1) * gridSpacing)) /
        crossAxisCount;

    return AlertDialog(
      scrollable: true,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      backgroundColor: AppTheme.cardBg(context),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        'Ajouter une pi\u00e8ce',
        style: TextStyle(color: AppTheme.textPrimaryC(context)),
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Nom de la pi\u00e8ce',
                hintText: 'Ex: Salon',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(
                  Icons.meeting_room,
                  color: AppTheme.primaryColor,
                ),
                fillColor: AppTheme.inputFill(context),
                filled: true,
              ),
              validator: (value) {
                final trimmed = value?.trim() ?? '';
                if (trimmed.isEmpty) {
                  return 'Veuillez entrer un nom';
                }
                if (trimmed.length > 100) {
                  return 'Le nom de la piece doit contenir au maximum 100 caracteres';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
            Text(
              'Type de pi\u00e8ce',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: AppTheme.textPrimaryC(context),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.maxFinite,
              child: Wrap(
                spacing: gridSpacing,
                runSpacing: gridSpacing,
                children: _roomTypes.map((type) {
                  final isSelected = _selectedType == type['value'];

                  return SizedBox(
                    width: itemWidth,
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _selectedType = type['value'];
                          final currentText = _nameController.text.trim();
                          final isRoomTypeName = _roomTypes.any(
                            (t) => t['name'] == currentText,
                          );
                          if (currentText.isEmpty || isRoomTypeName) {
                            _nameController.text = type['name'];
                          }
                        });
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppTheme.primaryColor.withOpacity(
                                  AppTheme.isDark(context) ? 0.2 : 0.1,
                                )
                              : AppTheme.cardBg(context),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? AppTheme.primaryColor
                                : AppTheme.borderLight(context),
                            width: 2,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              type['icon'],
                              style: const TextStyle(fontSize: 24),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              type['name'],
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: isSelected
                                    ? AppTheme.primaryColor
                                    : AppTheme.textPrimaryC(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Annuler',
            style: TextStyle(color: AppTheme.textGrey(context)),
          ),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Cr\u00e9er'),
        ),
      ],
    );
  }
}
