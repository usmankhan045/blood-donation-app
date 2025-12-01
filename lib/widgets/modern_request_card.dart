import 'package:flutter/material.dart';
import '../models/blood_request_model.dart';
import '../core/theme.dart';

/// 🎨 MODERN REQUEST CARD - Beautiful, Clean & Consistent
class ModernRequestCard extends StatelessWidget {
  final BloodRequest request;
  final bool isRecipientView;
  final VoidCallback? onAccept;
  final VoidCallback? onDecline;
  final VoidCallback? onViewDetails;
  final VoidCallback? onCancel;
  final VoidCallback? onComplete;
  final VoidCallback? onChat;
  final bool showActions;
  final bool showTimer;

  const ModernRequestCard({
    Key? key,
    required this.request,
    this.isRecipientView = false,
    this.onAccept,
    this.onDecline,
    this.onViewDetails,
    this.onCancel,
    this.onComplete,
    this.onChat,
    this.showActions = true,
    this.showTimer = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(BloodAppTheme.radiusLg),
        boxShadow: BloodAppTheme.cardShadow,
      ),
      child: Column(
        children: [
          // Header with gradient
          _buildHeader(),

          // Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Request Info Row
                _buildInfoRow(),

                const SizedBox(height: 12),

                // Location Row
                _buildLocationRow(),

                // Timer Section (for active requests)
                if (showTimer && request.isActive) ...[
                  const SizedBox(height: 16),
                  _buildTimerSection(),
                ],

                // Status Section (for non-active)
                if (!request.isActive) ...[
                  const SizedBox(height: 12),
                  _buildStatusSection(),
                ],

                // Action Buttons
                if (showActions && _shouldShowActions()) ...[
                  const SizedBox(height: 16),
                  _buildActionButtons(context),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: _getHeaderGradient(),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(BloodAppTheme.radiusLg),
          topRight: Radius.circular(BloodAppTheme.radiusLg),
        ),
      ),
      child: Row(
        children: [
          // Blood Type Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.water_drop,
                  size: 18,
                  color: BloodAppTheme.getBloodTypeColor(request.bloodType),
                ),
                const SizedBox(width: 6),
                Text(
                  request.bloodType,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: BloodAppTheme.getBloodTypeColor(request.bloodType),
                  ),
                ),
              ],
            ),
          ),

          const Spacer(),

          // Units Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${request.units} unit${request.units > 1 ? 's' : ''}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          const SizedBox(width: 8),

          // Urgency Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_getUrgencyIcon(), size: 14, color: _getUrgencyColor()),
                const SizedBox(width: 4),
                Text(
                  request.urgency.toUpperCase(),
                  style: TextStyle(
                    color: _getUrgencyColor(),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow() {
    return Row(
      children: [
        // Requester Info
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isRecipientView ? 'Your Request' : request.requesterName,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: BloodAppTheme.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                request.hospital ?? 'No hospital specified',
                style: TextStyle(
                  fontSize: 13,
                  color: BloodAppTheme.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),

        // Status Badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: request.statusColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: request.statusColor.withOpacity(0.3)),
          ),
          child: Text(
            request.statusText,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: request.statusColor,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLocationRow() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: BloodAppTheme.background,
        borderRadius: BorderRadius.circular(BloodAppTheme.radiusMd),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: BloodAppTheme.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.location_on,
              size: 18,
              color: BloodAppTheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  request.city,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: BloodAppTheme.textPrimary,
                  ),
                ),
                Text(
                  request.address,
                  style: TextStyle(
                    fontSize: 12,
                    color: BloodAppTheme.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: BloodAppTheme.info.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '${request.searchRadius}km',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: BloodAppTheme.info,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimerSection() {
    final progress = request.timerProgress;
    final isExpiring = request.isAboutToExpire;
    final isCritical = request.isCritical;

    Color timerColor = BloodAppTheme.primary;
    if (isCritical)
      timerColor = BloodAppTheme.error;
    else if (isExpiring)
      timerColor = BloodAppTheme.warning;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [timerColor.withOpacity(0.1), timerColor.withOpacity(0.05)],
        ),
        borderRadius: BorderRadius.circular(BloodAppTheme.radiusMd),
        border: Border.all(color: timerColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          // Timer Icon with Animation
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 44,
                height: 44,
                child: CircularProgressIndicator(
                  value: 1 - progress,
                  strokeWidth: 4,
                  backgroundColor: timerColor.withOpacity(0.2),
                  valueColor: AlwaysStoppedAnimation<Color>(timerColor),
                ),
              ),
              Icon(Icons.timer, size: 20, color: timerColor),
            ],
          ),
          const SizedBox(width: 14),

          // Timer Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isCritical
                      ? '⚠️ CRITICAL - Expiring Soon!'
                      : isExpiring
                      ? '⏰ Expiring Soon'
                      : 'Time Remaining',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: timerColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  request.timeRemainingString,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: timerColor,
                  ),
                ),
              ],
            ),
          ),

          // Progress Text
          Text(
            '${((1 - progress) * 100).toInt()}%',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: timerColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusSection() {
    IconData icon;
    String message;
    Color color;

    if (request.isAccepted) {
      icon = Icons.check_circle;
      message = 'Accepted by ${request.acceptedByName ?? 'donor'}';
      color = BloodAppTheme.success;
    } else if (request.isCompleted) {
      icon = Icons.verified;
      message = 'Donation completed successfully';
      color = BloodAppTheme.info;
    } else if (request.isExpiredStatus) {
      icon = Icons.timer_off;
      message = 'Request expired after 1 hour';
      color = BloodAppTheme.error;
    } else if (request.isCancelled) {
      icon = Icons.cancel;
      message = 'Request was cancelled';
      color = BloodAppTheme.textSecondary;
    } else {
      icon = Icons.info;
      message = 'Request status unknown';
      color = BloodAppTheme.textSecondary;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(BloodAppTheme.radiusMd),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ),
          // Chat button for accepted requests
          if (request.isAccepted && onChat != null)
            Material(
              color: BloodAppTheme.primary,
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                onTap: onChat,
                borderRadius: BorderRadius.circular(8),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.chat, color: Colors.white, size: 16),
                      SizedBox(width: 4),
                      Text(
                        'Chat',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    // For donors viewing available requests - show 3 buttons
    if (!isRecipientView && request.isActive && onDecline != null) {
      return Column(
        children: [
          Row(
            children: [
              // Decline Button
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onDecline,
                  icon: const Icon(Icons.close, size: 16),
                  label: const Text('Decline'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: BloodAppTheme.error,
                    side: BorderSide(color: BloodAppTheme.error.withOpacity(0.5)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(BloodAppTheme.radiusMd),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Accept Button
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: onAccept,
                  icon: Icon(
                    request.isCritical ? Icons.emergency : Icons.volunteer_activism,
                    size: 18,
                  ),
                  label: Text(
                    request.isCritical ? 'URGENT!' : request.isAboutToExpire ? 'Accept Now' : 'Accept',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: request.isCritical
                        ? BloodAppTheme.error
                        : request.isAboutToExpire
                            ? BloodAppTheme.warning
                            : BloodAppTheme.success,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(BloodAppTheme.radiusMd),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Details Button - Full width
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: onViewDetails,
              icon: const Icon(Icons.info_outline, size: 16),
              label: const Text('View Details'),
              style: TextButton.styleFrom(
                foregroundColor: BloodAppTheme.textSecondary,
                padding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
        ],
      );
    }

    // Default 2-button layout for other cases
    return Row(
      children: [
        // View Details Button
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onViewDetails,
            icon: const Icon(Icons.visibility, size: 18),
            label: const Text('Details'),
            style: OutlinedButton.styleFrom(
              foregroundColor: BloodAppTheme.primary,
              side: const BorderSide(color: BloodAppTheme.primary),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(BloodAppTheme.radiusMd),
              ),
            ),
          ),
        ),

        const SizedBox(width: 12),

        // Primary Action Button
        if (_getPrimaryAction() != null)
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _getPrimaryAction(),
              icon: Icon(_getPrimaryActionIcon(), size: 18),
              label: Text(_getPrimaryActionText()),
              style: ElevatedButton.styleFrom(
                backgroundColor: _getPrimaryActionColor(),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(BloodAppTheme.radiusMd),
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // 🛠️ HELPER METHODS
  // ═══════════════════════════════════════════════════════════════

  bool _shouldShowActions() {
    if (isRecipientView) {
      return request.isActive || request.isAccepted;
    } else {
      return request.isActive;
    }
  }

  LinearGradient _getHeaderGradient() {
    if (request.isCritical) {
      return const LinearGradient(
        colors: [Color(0xFFE53935), Color(0xFFB71C1C)],
      );
    } else if (request.isAboutToExpire) {
      return const LinearGradient(
        colors: [Color(0xFFF57C00), Color(0xFFE65100)],
      );
    } else if (request.urgency == 'emergency') {
      return const LinearGradient(
        colors: [Color(0xFFD32F2F), Color(0xFFB71C1C)],
      );
    } else if (request.urgency == 'high') {
      return const LinearGradient(
        colors: [Color(0xFFFF7043), Color(0xFFE64A19)],
      );
    } else {
      return const LinearGradient(
        colors: [BloodAppTheme.primary, BloodAppTheme.primaryDark],
      );
    }
  }

  IconData _getUrgencyIcon() {
    switch (request.urgency) {
      case 'emergency':
        return Icons.emergency;
      case 'high':
        return Icons.priority_high;
      case 'normal':
        return Icons.info;
      default:
        return Icons.low_priority;
    }
  }

  Color _getUrgencyColor() {
    switch (request.urgency) {
      case 'emergency':
        return BloodAppTheme.emergency;
      case 'high':
        return BloodAppTheme.urgent;
      case 'normal':
        return BloodAppTheme.normal;
      default:
        return BloodAppTheme.low;
    }
  }

  VoidCallback? _getPrimaryAction() {
    if (isRecipientView) {
      if (request.isActive) return onCancel;
      if (request.isAccepted) return onComplete;
      return null;
    } else {
      if (request.isActive) return onAccept;
      return null;
    }
  }

  IconData _getPrimaryActionIcon() {
    if (isRecipientView) {
      if (request.isActive) return Icons.cancel;
      if (request.isAccepted) return Icons.check;
      return Icons.info;
    } else {
      return Icons.volunteer_activism;
    }
  }

  String _getPrimaryActionText() {
    if (isRecipientView) {
      if (request.isActive) return 'Cancel';
      if (request.isAccepted) return 'Complete';
      return 'Info';
    } else {
      if (request.isCritical) return 'URGENT!';
      if (request.isAboutToExpire) return 'Accept Now';
      return 'Accept';
    }
  }

  Color _getPrimaryActionColor() {
    if (isRecipientView) {
      if (request.isActive) return BloodAppTheme.warning;
      if (request.isAccepted) return BloodAppTheme.success;
      return BloodAppTheme.info;
    } else {
      if (request.isCritical) return BloodAppTheme.error;
      if (request.isAboutToExpire) return BloodAppTheme.warning;
      return BloodAppTheme.success;
    }
  }
}
