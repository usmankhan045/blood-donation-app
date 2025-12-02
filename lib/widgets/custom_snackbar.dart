import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../services/navigation_service.dart';

/// 🎨 MODERN TOP SNACKBAR SYSTEM
/// - Appears at the TOP of the screen
/// - Short, non-intrusive duration
/// - Tappable with navigation support
/// - Beautiful animations
class AppSnackbar {
  static OverlayEntry? _currentOverlay;
  
  /// ✅ Success Snackbar
  static void showSuccess(
    BuildContext context,
    String message, {
    String? subtitle,
    VoidCallback? onTap,
    String? navigateTo,
  }) {
    _showTop(
      context,
      message: message,
      subtitle: subtitle,
      icon: Icons.check_circle_rounded,
      backgroundColor: const Color(0xFF10B981),
      onTap: onTap,
      navigateTo: navigateTo,
    );
  }

  /// ❌ Error Snackbar
  static void showError(
    BuildContext context,
    String message, {
    String? subtitle,
    VoidCallback? onTap,
  }) {
    _showTop(
      context,
      message: message,
      subtitle: subtitle,
      icon: Icons.error_rounded,
      backgroundColor: const Color(0xFFEF4444),
      onTap: onTap,
    );
  }

  /// ⚠️ Warning Snackbar
  static void showWarning(
    BuildContext context,
    String message, {
    String? subtitle,
    VoidCallback? onTap,
  }) {
    _showTop(
      context,
      message: message,
      subtitle: subtitle,
      icon: Icons.warning_rounded,
      backgroundColor: const Color(0xFFF59E0B),
      onTap: onTap,
    );
  }

  /// ℹ️ Info Snackbar
  static void showInfo(
    BuildContext context,
    String message, {
    String? subtitle,
    VoidCallback? onTap,
    String? navigateTo,
  }) {
    _showTop(
      context,
      message: message,
      subtitle: subtitle,
      icon: Icons.info_rounded,
      backgroundColor: const Color(0xFF3B82F6),
      onTap: onTap,
      navigateTo: navigateTo,
    );
  }

  /// 🩸 Blood Request Created
  static void showBloodRequest(
    BuildContext context, {
    required String title,
    required String bloodType,
    required int donorsNotified,
    required int bloodBanksNotified,
    String? navigateTo,
  }) {
    _showTopExtended(
      context,
      title: title,
      subtitle: '$bloodType Blood • $donorsNotified donors • $bloodBanksNotified banks notified',
      icon: Icons.bloodtype_rounded,
      backgroundColor: const Color(0xFFDC2626),
      navigateTo: navigateTo ?? '/recipient/my_requests',
    );
  }

  /// 🔔 Notification Snackbar
  static void showNotification(
    BuildContext context, {
    required String title,
    required String body,
    String? type,
    String? requestId,
    String? threadId,
    VoidCallback? onTap,
  }) {
    IconData icon;
    Color color;
    String? navigateTo;
    
    switch (type) {
      case 'blood_request':
      case 'emergency_blood_request':
        icon = Icons.bloodtype_rounded;
        color = const Color(0xFFDC2626);
        navigateTo = '/donor_requests';
        break;
      case 'request_accepted':
        icon = Icons.check_circle_rounded;
        color = const Color(0xFF10B981);
        navigateTo = '/recipient/my_requests';
        break;
      case 'chat_message':
        icon = Icons.chat_bubble_rounded;
        color = const Color(0xFF8B5CF6);
        navigateTo = '/chats';
        break;
      case 'fulfillment_reminder':
        icon = Icons.access_time_filled_rounded;
        color = const Color(0xFFF59E0B);
        navigateTo = '/blood_bank_dashboard';
        break;
      default:
        icon = Icons.notifications_rounded;
        color = BloodAppTheme.primary;
    }
    
    _showTop(
      context,
      message: title,
      subtitle: body,
      icon: icon,
      backgroundColor: color,
      onTap: onTap,
      navigateTo: navigateTo,
      duration: const Duration(seconds: 3),
    );
  }

  /// 🎯 Request Accepted
  static void showRequestAccepted(
    BuildContext context, {
    required String acceptorName,
    required String bloodType,
    String? navigateTo,
    VoidCallback? onTap,
  }) {
    _showTop(
      context,
      message: 'Request Accepted! 🎉',
      subtitle: '$acceptorName accepted your $bloodType blood request',
      icon: Icons.volunteer_activism_rounded,
      backgroundColor: const Color(0xFF10B981),
      navigateTo: navigateTo,
      onTap: onTap,
    );
  }

  /// 💬 New Chat Message
  static void showChatMessage(
    BuildContext context, {
    required String senderName,
    required String message,
    String? threadId,
    VoidCallback? onTap,
  }) {
    _showTop(
      context,
      message: senderName,
      subtitle: message.length > 50 ? '${message.substring(0, 50)}...' : message,
      icon: Icons.chat_bubble_rounded,
      backgroundColor: const Color(0xFF8B5CF6),
      onTap: onTap,
      navigateTo: '/chats',
      duration: const Duration(seconds: 2),
    );
  }

  /// 🩸 Request Action Snackbar
  static void showRequestAction(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
    String? navigateTo,
  }) {
    _showTop(
      context,
      message: title,
      subtitle: subtitle,
      icon: icon,
      backgroundColor: color,
      onTap: onTap,
      navigateTo: navigateTo,
    );
  }

  /// 🎬 Main TOP Snackbar
  static void _showTop(
    BuildContext context, {
    required String message,
    String? subtitle,
    required IconData icon,
    required Color backgroundColor,
    VoidCallback? onTap,
    String? navigateTo,
    Duration duration = const Duration(milliseconds: 2500),
  }) {
    // Dismiss current if exists
    _dismissCurrent();
    
    final overlay = Overlay.of(context);
    
    _currentOverlay = OverlayEntry(
      builder: (context) => _TopSnackbarWidget(
        message: message,
        subtitle: subtitle,
        icon: icon,
        backgroundColor: backgroundColor,
        duration: duration,
        onTap: () {
          _dismissCurrent();
          if (onTap != null) {
            onTap();
          } else if (navigateTo != null) {
            NavigationService.instance.navigateTo(navigateTo);
          }
        },
        onDismiss: _dismissCurrent,
      ),
    );
    
    overlay.insert(_currentOverlay!);
  }

  /// 📊 Extended Top Snackbar (with more info)
  static void _showTopExtended(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color backgroundColor,
    String? navigateTo,
    VoidCallback? onTap,
    Duration duration = const Duration(seconds: 3),
  }) {
    _dismissCurrent();
    
    final overlay = Overlay.of(context);
    
    _currentOverlay = OverlayEntry(
      builder: (context) => _TopSnackbarWidget(
        message: title,
        subtitle: subtitle,
        icon: icon,
        backgroundColor: backgroundColor,
        duration: duration,
        showArrow: true,
        onTap: () {
          _dismissCurrent();
          if (onTap != null) {
            onTap();
          } else if (navigateTo != null) {
            NavigationService.instance.navigateTo(navigateTo);
          }
        },
        onDismiss: _dismissCurrent,
      ),
    );
    
    overlay.insert(_currentOverlay!);
  }

  /// Dismiss current snackbar
  static void _dismissCurrent() {
    _currentOverlay?.remove();
    _currentOverlay = null;
  }

  /// Dismiss all snackbars (can be called from outside)
  static void dismiss() {
    _dismissCurrent();
  }
}

/// 🎨 Top Snackbar Widget with animations
class _TopSnackbarWidget extends StatefulWidget {
  final String message;
  final String? subtitle;
  final IconData icon;
  final Color backgroundColor;
  final Duration duration;
  final VoidCallback onTap;
  final VoidCallback onDismiss;
  final bool showArrow;

  const _TopSnackbarWidget({
    required this.message,
    this.subtitle,
    required this.icon,
    required this.backgroundColor,
    required this.duration,
    required this.onTap,
    required this.onDismiss,
    this.showArrow = false,
  });

  @override
  State<_TopSnackbarWidget> createState() => _TopSnackbarWidgetState();
}

class _TopSnackbarWidgetState extends State<_TopSnackbarWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  bool _isVisible = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _controller.forward();

    // Auto dismiss
    Future.delayed(widget.duration, () {
      if (_isVisible && mounted) {
        _dismiss();
      }
    });
  }

  void _dismiss() async {
    if (!_isVisible) return;
    _isVisible = false;
    await _controller.reverse();
    widget.onDismiss();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    
    return Positioned(
      top: topPadding + 8,
      left: 12,
      right: 12,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: GestureDetector(
            onTap: widget.onTap,
            onVerticalDragUpdate: (details) {
              if (details.delta.dy < -5) {
                _dismiss();
              }
            },
            child: Material(
              color: Colors.transparent,
              child: Container(
                decoration: BoxDecoration(
                  color: widget.backgroundColor,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: widget.backgroundColor.withOpacity(0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Stack(
                    children: [
                      // Background pattern
                      Positioned(
                        right: -20,
                        top: -20,
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.1),
                          ),
                        ),
                      ),
                      Positioned(
                        right: 30,
                        bottom: -30,
                        child: Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.05),
                          ),
                        ),
                      ),
                      // Content
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            // Icon
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                widget.icon,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Text
                            Expanded(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.message,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                      height: 1.2,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (widget.subtitle != null) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      widget.subtitle!,
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.85),
                                        fontSize: 12,
                                        height: 1.3,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            // Arrow indicator
                            if (widget.showArrow) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.arrow_forward_ios_rounded,
                                  color: Colors.white,
                                  size: 12,
                                ),
                              ),
                            ],
                            // Close button
                            const SizedBox(width: 4),
                            GestureDetector(
                              onTap: _dismiss,
                              child: Padding(
                                padding: const EdgeInsets.all(4),
                                child: Icon(
                                  Icons.close_rounded,
                                  color: Colors.white.withOpacity(0.7),
                                  size: 18,
                                ),
                              ),
                            ),
                          ],
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

/// 🎬 Legacy support - Animated Snackbar (for old code compatibility)
class AnimatedSnackbar extends StatefulWidget {
  final Widget child;
  final VoidCallback onDismiss;

  const AnimatedSnackbar({
    super.key,
    required this.child,
    required this.onDismiss,
  });

  @override
  State<AnimatedSnackbar> createState() => _AnimatedSnackbarState();
}

class _AnimatedSnackbarState extends State<AnimatedSnackbar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: widget.child,
      ),
    );
  }
}
