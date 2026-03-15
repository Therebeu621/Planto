import 'package:flutter/material.dart';
import 'package:planto/core/models/room.dart';
import 'package:planto/core/theme/app_theme.dart';

/// PlantCard widget - displays a plant in the home page list
class PlantCard extends StatelessWidget {
  final PlantSummary plant;
  final VoidCallback onWater;
  final VoidCallback onTap;

  const PlantCard({
    super.key,
    required this.plant,
    required this.onWater,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      shadowColor: AppTheme.shadow(context),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          GestureDetector(
            onTap: onTap,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  _buildImage(context),
                  const SizedBox(width: 12),
                  Expanded(child: _buildInfo(context)),
                  const SizedBox(width: 56),
                ],
              ),
            ),
          ),
          Positioned(
            right: 4,
            top: 0,
            bottom: 0,
            child: Center(
              child: _buildWaterButton(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImage(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: plant.photoUrl != null && plant.photoUrl!.isNotEmpty
          ? Image.network(
              plant.photoUrl!,
              width: 60,
              height: 60,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _buildPlaceholderImage(context),
            )
          : _buildPlaceholderImage(context),
    );
  }

  Widget _buildPlaceholderImage(BuildContext context) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: AppTheme.isDark(context) ? 0.2 : 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        Icons.local_florist,
        color: AppTheme.textGrey(context),
        size: 30,
      ),
    );
  }

  Widget _buildInfo(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          plant.nickname,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: AppTheme.textPrimaryC(context),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: _buildBadges(),
        ),
      ],
    );
  }

  List<Widget> _buildBadges() {
    final badges = <Widget>[];

    final int? daysLeft;
    final bool isUrgent;

    if (plant.nextWateringDate != null) {
      daysLeft = plant.daysUntilWatering;
      isUrgent = daysLeft! <= 0;
    } else {
      isUrgent = plant.needsWatering;
      daysLeft = null;
    }

    if (isUrgent) {
      badges.add(_buildBadge(
        '\u{1F4A7} \u00C0 arroser',
        Colors.orange.shade100,
        Colors.orange.shade800,
      ));
    } else if (daysLeft != null) {
      badges.add(_buildBadge(
        '\u{1F4A7} J-$daysLeft',
        AppTheme.primaryColor.withValues(alpha: 0.15),
        AppTheme.primaryColor,
      ));
    }

    return badges;
  }

  Widget _buildBadge(String text, Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }

  Widget _buildWaterButton(BuildContext context) {
    final isUrgent = plant.needsWatering;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onWater,
        borderRadius: BorderRadius.circular(50),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isUrgent
                  ? Colors.orange.shade50
                  : AppTheme.primaryColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
              border: Border.all(
                color: isUrgent
                    ? Colors.orange.shade200
                    : AppTheme.primaryColor.withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
            child: Icon(
              Icons.water_drop_outlined,
              color: isUrgent ? Colors.orange.shade700 : AppTheme.primaryColor,
              size: 22,
            ),
          ),
        ),
      ),
    );
  }
}
