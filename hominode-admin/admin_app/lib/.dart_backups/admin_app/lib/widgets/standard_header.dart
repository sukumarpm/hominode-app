import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Primary App Header - Standard reusable header component for all screens
/// 
/// Features:
/// - Consistent gradient background (#2563EB → #1E40AF)
/// - Auto back button detection (hidden on root screens)
/// - Optional subtitle support
/// - Rounded bottom corners (20px radius)
/// - Proper safe area handling
/// - Fixed height (96-104px)
class PrimaryAppHeader extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String? subtitle;
  final bool showBackButton;
  final VoidCallback? onBackPressed;
  final Widget? actionWidget;

  const PrimaryAppHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.showBackButton = true,
    this.onBackPressed,
    this.actionWidget,
  });

  @override
  Widget build(BuildContext context) {
    // Auto-detect if we can go back
    final canPop = Navigator.canPop(context);
    final shouldShowBack = showBackButton && canPop;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF2563EB), // Gradient Start
            Color(0xFF1E40AF), // Gradient End
          ],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light, // Light status bar icons
        automaticallyImplyLeading: false,
        toolbarHeight: _getToolbarHeight(),
        flexibleSpace: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Back Button (Left)
                if (shouldShowBack) ...[
                  GestureDetector(
                    onTap: onBackPressed ?? () => Navigator.pop(context),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.arrow_back_ios_new,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                ],
                
                // Title and Subtitle (Center/Left-aligned)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          height: 1.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: Colors.white.withOpacity(0.8),
                            height: 1.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                
                // Action Widget (Right)
                if (actionWidget != null) ...[
                  const SizedBox(width: 16),
                  actionWidget!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  double _getToolbarHeight() {
    // Base height + extra space for subtitle if present
    return subtitle != null ? 104.0 : 96.0;
  }

  @override
  Size get preferredSize => Size.fromHeight(_getToolbarHeight());
}

/// Legacy StandardHeader - Kept for backward compatibility
/// @deprecated Use PrimaryAppHeader instead
class StandardHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onBackPressed;
  final Widget? actionWidget;
  final bool showBackButton;
  final Color? backgroundColor;
  final Color? textColor;

  const StandardHeader({
    super.key,
    required this.title,
    this.onBackPressed,
    this.actionWidget,
    this.showBackButton = true,
    this.backgroundColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 100,
      floating: true,
      pinned: false,
      backgroundColor: Colors.transparent,
      elevation: 0,
      automaticallyImplyLeading: false,
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: backgroundColor != null
                ? [backgroundColor!, backgroundColor!]
                : [
                    const Color(0xFF2563EB),
                    const Color(0xFF1E40AF),
                  ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                if (showBackButton)
                  GestureDetector(
                    onTap: onBackPressed ?? () => Navigator.pop(context),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                if (showBackButton) const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: textColor ?? Colors.white,
                    ),
                  ),
                ),
                if (actionWidget != null) ...[
                  const SizedBox(width: 16),
                  actionWidget!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Legacy StandardAppBar - Kept for backward compatibility  
/// @deprecated Use PrimaryAppHeader instead
class StandardAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final VoidCallback? onBackPressed;
  final Widget? actionWidget;
  final bool showBackButton;
  final Color? backgroundColor;
  final Color? textColor;

  const StandardAppBar({
    super.key,
    required this.title,
    this.onBackPressed,
    this.actionWidget,
    this.showBackButton = true,
    this.backgroundColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: backgroundColor != null
              ? [backgroundColor!, backgroundColor!]
              : [
                  const Color(0xFF2563EB),
                  const Color(0xFF1E40AF),
                ],
        ),
      ),
      child: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            if (showBackButton)
              GestureDetector(
                onTap: onBackPressed ?? () => Navigator.pop(context),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.arrow_back_ios_new,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            if (showBackButton) const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: textColor ?? Colors.white,
                ),
              ),
            ),
            if (actionWidget != null) ...[
              const SizedBox(width: 16),
              actionWidget!,
            ],
          ],
        ),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}