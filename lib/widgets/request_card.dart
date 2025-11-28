import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/blood_request_model.dart';
import '../providers/request_provider.dart';
import 'countdown_timer.dart';

/// Beautiful request card widget with countdown timer for both donor and recipient views
class RequestCard extends StatelessWidget {
  final BloodRequest request;
  final bool isRecipientView;
  final VoidCallback? onAccept;
  final VoidCallback? onViewDetails;
  final VoidCallback? onCancel;
  final bool showActions;

  const RequestCard({
    Key? key,
    required this.request,
    this.isRecipientView = false,
    this.onAccept,
    this.onViewDetails,
    this.onCancel,
    this.showActions = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: _getCardGradient(request),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with blood type and status
              _buildHeader(context),
              const SizedBox(height: 12),

              // Request details
              _buildDetails(context),
              const SizedBox(height: 12),

              // Countdown timer for active requests
              if (request.isActive) _buildTimerSection(context),

              // Status info for non-active requests
              if (!request.isActive) _buildStatusInfo(context),

              // Actions for donor/recipient
              if (showActions) _buildActionButtons(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        // Blood type badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _getBloodTypeColor(request.bloodType),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            request.bloodType,
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const Spacer(),

        // Status badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: request.statusColor.withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: request.statusColor, width: 1),
          ),
          child: Text(
            request.statusText.toUpperCase(),
            style: TextStyle(
              color: request.statusColor,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDetails(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Location and distance
        Row(
          children: [
            Icon(Icons.location_on, size: 16, color: Colors.white70),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                '${request.city} • ${request.address}',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Units and urgency
        Row(
          children: [
            Icon(Icons.bloodtype, size: 16, color: Colors.white70),
            const SizedBox(width: 4),
            Text(
              '${request.units} unit(s)',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
              ),
            ),
            const SizedBox(width: 16),
            Icon(request.urgencyIcon, size: 16, color: request.urgencyColor),
            const SizedBox(width: 4),
            Text(
              request.urgency.toUpperCase(),
              style: TextStyle(
                color: request.urgencyColor,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),

        // Hospital info
        if (request.hospital != null && request.hospital!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.local_hospital, size: 16, color: Colors.white70),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  request.hospital!,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],

        // Notes
        if (request.notes != null && request.notes!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.note, size: 16, color: Colors.white70),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  request.notes!,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],

        // Accepted by info
        if (request.isAccepted && request.acceptedByName != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.person, size: 16, color: Colors.green),
              const SizedBox(width: 4),
              Text(
                'Accepted by: ${request.acceptedByName}',
                style: TextStyle(
                  color: Colors.green,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildTimerSection(BuildContext context) {
    return Consumer<RequestProvider>(
      builder: (context, provider, child) {
        final timeRemaining = provider.getTimerForRequest(request.id);

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _getTimerBorderColor(request),
              width: 2,
            ),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Time Remaining',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Icon(
                    Icons.timer,
                    color: _getTimerIconColor(request),
                    size: 20,
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Circular countdown timer
              CountdownTimer(
                duration: timeRemaining ?? request.timeRemaining ?? Duration.zero,
                request: request,
                onExpired: () {
                  // Refresh data when timer expires
                  provider.fetchMyRequests();
                  provider.fetchAvailableRequests();
                },
              ),

              const SizedBox(height: 4),

              // Time text
              Text(
                request.timeRemainingString,
                style: TextStyle(
                  color: _getTimerTextColor(request),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusInfo(BuildContext context) {
    String statusMessage = '';
    IconData statusIcon = Icons.info;
    Color statusColor = Colors.grey;

    if (request.isCompleted) {
      statusMessage = 'Donation completed successfully';
      statusIcon = Icons.check_circle;
      statusColor = Colors.green;
    } else if (request.isExpiredStatus) {
      statusMessage = 'Request expired after 1 hour';
      statusIcon = Icons.timer_off;
      statusColor = Colors.red;
    } else if (request.isCancelled) {
      statusMessage = 'Request was cancelled';
      statusIcon = Icons.cancel;
      statusColor = Colors.orange;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor, width: 1),
      ),
      child: Row(
        children: [
          Icon(statusIcon, color: statusColor, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              statusMessage,
              style: TextStyle(
                color: statusColor,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Row(
        children: [
          // View Details Button
          Expanded(
            child: OutlinedButton(
              onPressed: onViewDetails,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: BorderSide(color: Colors.white),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: Text(
                'View Details',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ),

          const SizedBox(width: 12),

          // Action Button (Accept/Cancel/Complete)
          if (_shouldShowActionButton()) ...[
            Expanded(
              child: ElevatedButton(
                onPressed: _getActionCallback(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _getActionButtonColor(),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: Text(
                  _getActionButtonText(),
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  bool _shouldShowActionButton() {
    if (isRecipientView) {
      return request.canCancel;
    } else {
      return request.canAccept;
    }
  }

  VoidCallback? _getActionCallback() {
    if (isRecipientView) {
      return request.canCancel ? onCancel : null;
    } else {
      return request.canAccept ? onAccept : null;
    }
  }

  Color _getActionButtonColor() {
    if (isRecipientView) {
      return Colors.orange;
    } else {
      if (request.isCritical) return Colors.red;
      if (request.isAboutToExpire) return Colors.orange;
      return Colors.green;
    }
  }

  String _getActionButtonText() {
    if (isRecipientView) {
      return 'Cancel';
    } else {
      if (request.isCritical) return 'URGENT ACCEPT';
      if (request.isAboutToExpire) return 'ACCEPT NOW';
      return 'ACCEPT';
    }
  }

  // Helper methods for styling
  LinearGradient _getCardGradient(BloodRequest request) {
    if (request.isCritical) {
      return LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Colors.red.shade600, Colors.red.shade800],
      );
    } else if (request.isAboutToExpire) {
      return LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Colors.orange.shade600, Colors.orange.shade800],
      );
    } else if (request.isUrgent) {
      return LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Colors.deepOrange.shade500, Colors.red.shade700],
      );
    } else {
      return LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Colors.blue.shade600, Colors.purple.shade600],
      );
    }
  }

  Color _getBloodTypeColor(String bloodType) {
    switch (bloodType) {
      case 'A+': return Colors.red.shade600;
      case 'A-': return Colors.red.shade800;
      case 'B+': return Colors.blue.shade600;
      case 'B-': return Colors.blue.shade800;
      case 'AB+': return Colors.purple.shade600;
      case 'AB-': return Colors.purple.shade800;
      case 'O+': return Colors.green.shade600;
      case 'O-': return Colors.green.shade800;
      default: return Colors.grey.shade600;
    }
  }

  Color _getTimerBorderColor(BloodRequest request) {
    if (request.isCritical) return Colors.red;
    if (request.isAboutToExpire) return Colors.orange;
    return Colors.white30;
  }

  Color _getTimerIconColor(BloodRequest request) {
    if (request.isCritical) return Colors.red;
    if (request.isAboutToExpire) return Colors.orange;
    return Colors.white;
  }

  Color _getTimerTextColor(BloodRequest request) {
    if (request.isCritical) return Colors.red.shade200;
    if (request.isAboutToExpire) return Colors.orange.shade200;
    return Colors.white70;
  }
}