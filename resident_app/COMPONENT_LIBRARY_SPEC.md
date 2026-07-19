# 🧩 Standardized Component Library

## 1. AppCard - Universal Card Component

### Design Specs
- Background: `#FFFFFF`
- Border: 1px `#E5E7EB`
- Border Radius: 14px
- Shadow: `rgba(0, 0, 0, 0.04)` blur 8px, offset (0, 2)
- Padding: 12px (default), 16px (large)

### Implementation

```dart
// lib/src/components/app_card.dart
import 'package:flutter/material.dart';

enum AppCardSize { small, medium, large }

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final AppCardSize size;
  final Color? backgroundColor;
  final bool hasBorder;
  final bool hasShadow;

  const AppCard({
    Key? key,
    required this.child,
    this.padding,
    this.onTap,
    this.size = AppCardSize.medium,
    this.backgroundColor,
    this.hasBorder = true,
    this.hasShadow = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final effectivePadding = padding ?? _getPadding();
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: effectivePadding,
        decoration: BoxDecoration(
          color: backgroundColor ?? Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: hasBorder
              ? Border.all(color: const Color(0xFFE5E7EB))
              : null,
          boxShadow: hasShadow
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: child,
      ),
    );
  }

  EdgeInsets _getPadding() {
    switch (size) {
      case AppCardSize.small:
        return const EdgeInsets.all(10);
      case AppCardSize.medium:
        return const EdgeInsets.all(12);
      case AppCardSize.large:
        return const EdgeInsets.all(16);
    }
  }
}
```

### Usage Examples

```dart
// Simple card
AppCard(
  child: Text('Hello World'),
)

// Card with tap
AppCard(
  onTap: () => print('Tapped'),
  child: Column(
    children: [
      Text('Title'),
      Text('Subtitle'),
    ],
  ),
)

// Large card without shadow
AppCard(
  size: AppCardSize.large,
  hasShadow: false,
  child: YourContent(),
)
```

---

## 2. AppButton - Standardized Button Component

### Design Specs

#### Primary Button
- Background: `#2563EB`
- Text: White, 16px, w600
- Height: 48px
- Border Radius: 12px
- No shadow (elevation: 0)

#### Secondary Button
- Background: Transparent
- Border: 1.5px `#2563EB`
- Text: `#2563EB`, 16px, w600
- Height: 48px
- Border Radius: 12px

#### Text Button
- Background: Transparent
- Text: `#2563EB`, 15px, w600
- No border
- Minimal padding

### Implementation

```dart
// lib/src/components/app_button.dart
import 'package:flutter/material.dart';

enum AppButtonType { primary, secondary, text, destructive }
enum AppButtonSize { small, medium, large }

class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final AppButtonType type;
  final AppButtonSize size;
  final bool isLoading;
  final IconData? icon;
  final bool fullWidth;

  const AppButton({
    Key? key,
    required this.label,
    this.onPressed,
    this.type = AppButtonType.primary,
    this.size = AppButtonSize.medium,
    this.isLoading = false,
    this.icon,
    this.fullWidth = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final height = _getHeight();
    final fontSize = _getFontSize();
    
    Widget button;
    
    switch (type) {
      case AppButtonType.primary:
        button = _buildPrimaryButton(height, fontSize);
        break;
      case AppButtonType.secondary:
        button = _buildSecondaryButton(height, fontSize);
        break;
      case AppButtonType.text:
        button = _buildTextButton(fontSize);
        break;
      case AppButtonType.destructive:
        button = _buildDestructiveButton(height, fontSize);
        break;
    }
    
    if (fullWidth) {
      return SizedBox(width: double.infinity, child: button);
    }
    
    return button;
  }

  Widget _buildPrimaryButton(double height, double fontSize) {
    return SizedBox(
      height: height,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2563EB),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24),
        ),
        child: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : _buildButtonContent(fontSize, Colors.white),
      ),
    );
  }

  Widget _buildSecondaryButton(double height, double fontSize) {
    return SizedBox(
      height: height,
      child: OutlinedButton(
        onPressed: isLoading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF2563EB),
          side: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24),
        ),
        child: _buildButtonContent(fontSize, const Color(0xFF2563EB)),
      ),
    );
  }

  Widget _buildTextButton(double fontSize) {
    return TextButton(
      onPressed: isLoading ? null : onPressed,
      style: TextButton.styleFrom(
        foregroundColor: const Color(0xFF2563EB),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      child: _buildButtonContent(fontSize, const Color(0xFF2563EB)),
    );
  }

  Widget _buildDestructiveButton(double height, double fontSize) {
    return SizedBox(
      height: height,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFEF4444),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24),
        ),
        child: _buildButtonContent(fontSize, Colors.white),
      ),
    );
  }

  Widget _buildButtonContent(double fontSize, Color color) {
    if (icon != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: fontSize + 2),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
    }
    
    return Text(
      label,
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  double _getHeight() {
    switch (size) {
      case AppButtonSize.small:
        return 40;
      case AppButtonSize.medium:
        return 48;
      case AppButtonSize.large:
        return 56;
    }
  }

  double _getFontSize() {
    switch (size) {
      case AppButtonSize.small:
        return 14;
      case AppButtonSize.medium:
        return 16;
      case AppButtonSize.large:
        return 17;
    }
  }
}
```

### Usage Examples

```dart
// Primary button
AppButton(
  label: 'Continue',
  onPressed: () => print('Pressed'),
)

// Secondary button with icon
AppButton(
  label: 'Cancel',
  type: AppButtonType.secondary,
  icon: Icons.close,
  onPressed: () => Navigator.pop(context),
)

// Loading state
AppButton(
  label: 'Submitting...',
  isLoading: true,
)

// Full width button
AppButton(
  label: 'Sign In',
  fullWidth: true,
  onPressed: _handleSignIn,
)

// Destructive action
AppButton(
  label: 'Delete Account',
  type: AppButtonType.destructive,
  onPressed: _showDeleteConfirmation,
)
```

---

## 3. AppTextField - Standardized Input Field

### Design Specs
- Height: 52px
- Border: 1px `#E5E7EB`
- Border Radius: 12px
- Focus Border: 2px `#2563EB`
- Placeholder: `#9CA3AF`, 15px
- Text: `#111111`, 15px
- Padding: 16px horizontal

### Implementation

```dart
// lib/src/components/app_text_field.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppTextField extends StatelessWidget {
  final String? label;
  final String? hint;
  final TextEditingController? controller;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final int? maxLines;
  final int? maxLength;
  final List<TextInputFormatter>? inputFormatters;
  final bool enabled;
  final FocusNode? focusNode;

  const AppTextField({
    Key? key,
    this.label,
    this.hint,
    this.controller,
    this.keyboardType,
    this.obscureText = false,
    this.prefixIcon,
    this.suffixIcon,
    this.validator,
    this.onChanged,
    this.maxLines = 1,
    this.maxLength,
    this.inputFormatters,
    this.enabled = true,
    this.focusNode,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 8),
        ],
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          validator: validator,
          onChanged: onChanged,
          maxLines: maxLines,
          maxLength: maxLength,
          inputFormatters: inputFormatters,
          enabled: enabled,
          focusNode: focusNode,
          style: const TextStyle(
            fontSize: 15,
            color: Color(0xFF111111),
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
              fontSize: 15,
              color: Color(0xFF9CA3AF),
            ),
            prefixIcon: prefixIcon,
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFF2563EB),
                width: 2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFEF4444)),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFFEF4444),
                width: 2,
              ),
            ),
            counterText: '',
          ),
        ),
      ],
    );
  }
}
```

### Usage Examples

```dart
// Basic text field
AppTextField(
  label: 'Full Name',
  hint: 'Enter your full name',
  controller: _nameController,
)

// Email field with validation
AppTextField(
  label: 'Email',
  hint: 'your@email.com',
  keyboardType: TextInputType.emailAddress,
  validator: (value) {
    if (value?.isEmpty ?? true) return 'Email is required';
    if (!value!.contains('@')) return 'Invalid email';
    return null;
  },
)

// Password field
AppTextField(
  label: 'Password',
  hint: 'Enter password',
  obscureText: true,
  suffixIcon: IconButton(
    icon: Icon(Icons.visibility_off),
    onPressed: () => toggleVisibility(),
  ),
)

// Phone number with formatting
AppTextField(
  label: 'Phone Number',
  hint: '+91 1234567890',
  keyboardType: TextInputType.phone,
  inputFormatters: [
    FilteringTextInputFormatter.digitsOnly,
    LengthLimitingTextInputFormatter(10),
  ],
)

// Multiline text area
AppTextField(
  label: 'Description',
  hint: 'Enter description',
  maxLines: 4,
  maxLength: 500,
)
```

---

## 4. AppHeader - Standardized Screen Header

### Design Specs
- Background: Gradient `#2563EB` → `#1E40AF`
- Height: Auto (based on content)
- Border Radius: 24px bottom corners
- Title: White, 20px, w600
- Back button: 20px icon, 8px padding
- Padding: 16px top, 20px bottom, 16px horizontal

### Implementation

```dart
// lib/src/components/app_header.dart
import 'package:flutter/material.dart';

class AppHeader extends StatelessWidget {
  final String title;
  final bool showBackButton;
  final VoidCallback? onBackPressed;
  final List<Widget>? actions;
  final Widget? subtitle;

  const AppHeader({
    Key? key,
    required this.title,
    this.showBackButton = true,
    this.onBackPressed,
    this.actions,
    this.subtitle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF2563EB),
            Color(0xFF1E40AF),
          ],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 16, 16, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (showBackButton)
                    IconButton(
                      onPressed: onBackPressed ?? () => Navigator.pop(context),
                      icon: const Icon(
                        Icons.arrow_back_ios,
                        color: Colors.white,
                        size: 20,
                      ),
                      padding: const EdgeInsets.all(8),
                    ),
                  if (showBackButton) const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (actions != null) ...actions!,
                ],
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 8),
                Padding(
                  padding: EdgeInsets.only(left: showBackButton ? 48 : 0),
                  child: subtitle,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
```

### Usage Examples

```dart
// Basic header
AppHeader(
  title: 'Messages',
)

// Header without back button
AppHeader(
  title: 'Dashboard',
  showBackButton: false,
)

// Header with actions
AppHeader(
  title: 'Settings',
  actions: [
    IconButton(
      icon: Icon(Icons.search, color: Colors.white),
      onPressed: () => showSearch(),
    ),
  ],
)

// Header with subtitle
AppHeader(
  title: 'Profile',
  subtitle: Text(
    'Block A, Flat 301',
    style: TextStyle(
      color: Colors.white70,
      fontSize: 14,
    ),
  ),
)
```

---

## 5. AppModal - Standardized Modal/Dialog

### Design Specs
- Background: White
- Border Radius: 20px
- Padding: 20px
- Max Width: 90% of screen
- Background Dim: `rgba(0, 0, 0, 0.5)`
- Centered on screen
- Keyboard-aware (adjusts when keyboard opens)

### Implementation

```dart
// lib/src/components/app_modal.dart
import 'package:flutter/material.dart';

class AppModal {
  static Future<T?> show<T>({
    required BuildContext context,
    required Widget child,
    bool isDismissible = true,
    bool useRootNavigator = true,
  }) {
    return showDialog<T>(
      context: context,
      barrierDismissible: isDismissible,
      useRootNavigator: useRootNavigator,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: child,
          ),
        ),
      ),
    );
  }

  static Future<T?> showBottomSheet<T>({
    required BuildContext context,
    required Widget child,
    bool isDismissible = true,
    bool enableDrag = true,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: child,
          ),
        ),
      ),
    );
  }
}
```

### Usage Examples

```dart
// Center modal
AppModal.show(
  context: context,
  child: Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text('Confirm Action'),
      SizedBox(height: 16),
      AppButton(
        label: 'Confirm',
        onPressed: () => Navigator.pop(context, true),
      ),
    ],
  ),
)

// Bottom sheet
AppModal.showBottomSheet(
  context: context,
  child: Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text('Select Option'),
      ListTile(title: Text('Option 1')),
      ListTile(title: Text('Option 2')),
    ],
  ),
)

// Non-dismissible modal
AppModal.show(
  context: context,
  isDismissible: false,
  child: LoadingIndicator(),
)
```

