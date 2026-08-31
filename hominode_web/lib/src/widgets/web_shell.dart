import 'package:flutter/material.dart';

import '../theme/web_design_system.dart';

class WebDestination {
  const WebDestination(this.label, this.icon, this.content, {this.path});

  final String label;
  final IconData icon;
  final Widget content;
  final String? path;
}

class HominodeWebShell extends StatefulWidget {
  const HominodeWebShell({
    super.key,
    required this.title,
    required this.subtitle,
    required this.roleLabel,
    required this.palette,
    required this.destinations,
    required this.onLogout,
    this.initialIndex = 0,
    this.profileName,
    this.profileSubtitle,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final String roleLabel;
  final RolePalette palette;
  final List<WebDestination> destinations;
  final Future<void> Function() onLogout;
  final int initialIndex;
  final String? profileName;
  final String? profileSubtitle;
  final Widget? trailing;

  @override
  State<HominodeWebShell> createState() => _HominodeWebShellState();
}

class _HominodeWebShellState extends State<HominodeWebShell> {
  late int index = _safeIndex(widget.initialIndex);

  int _safeIndex(int value) {
    if (widget.destinations.isEmpty) return 0;
    return value.clamp(0, widget.destinations.length - 1);
  }

  @override
  void didUpdateWidget(covariant HominodeWebShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextIndex = _safeIndex(widget.initialIndex);
    if (nextIndex != index) index = nextIndex;
  }

  void _select(int value, bool mobile) {
    if (value < 0 || value >= widget.destinations.length) return;
    if (mobile && Navigator.of(context).canPop()) Navigator.of(context).pop();
    setState(() => index = value);
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final desktop = constraints.maxWidth >= 1080;
      final tablet = constraints.maxWidth >= 720;
      final mobile = !tablet;
      final navigation = _Navigation(
        destinations: widget.destinations,
        selected: index,
        expanded: desktop || mobile,
        palette: widget.palette,
        roleLabel: widget.roleLabel,
        profileName: widget.profileName,
        onLogout: widget.onLogout,
        onSelect: (value) => _select(value, mobile),
      );

      return Scaffold(
        backgroundColor: WebDesign.background,
        drawer: mobile
            ? Drawer(
                width: 264,
                backgroundColor: Colors.transparent,
                child: SafeArea(child: navigation),
              )
            : null,
        body: Row(
          children: [
            if (tablet) SizedBox(width: desktop ? 224 : 76, child: navigation),
            Expanded(
              child: Column(
                children: [
                  _DashboardHeader(
                    title: widget.title,
                    subtitle: widget.subtitle,
                    roleLabel: widget.roleLabel,
                    profileName: widget.profileName,
                    profileSubtitle: widget.profileSubtitle,
                    palette: widget.palette,
                    mobile: mobile,
                    trailing: widget.trailing,
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.all(
                        mobile ? 12 : WebDesign.pagePadding,
                      ),
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1440),
                          child: widget.destinations[index].content,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({
    required this.title,
    required this.subtitle,
    required this.roleLabel,
    required this.profileName,
    required this.profileSubtitle,
    required this.palette,
    required this.mobile,
    required this.trailing,
  });

  final String title;
  final String subtitle;
  final String roleLabel;
  final String? profileName;
  final String? profileSubtitle;
  final RolePalette palette;
  final bool mobile;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Container(
    height: mobile ? 66 : 72,
    padding: EdgeInsets.symmetric(horizontal: mobile ? 8 : 22),
    decoration: BoxDecoration(
      gradient: mobile ? palette.gradient : null,
      color: mobile ? null : Colors.white,
      border: mobile
          ? null
          : const Border(bottom: BorderSide(color: WebDesign.border)),
    ),
    child: Row(
      children: [
        if (mobile)
          Builder(
            builder: (context) => IconButton(
              tooltip: 'Open navigation',
              onPressed: () => Scaffold.of(context).openDrawer(),
              icon: const Icon(Icons.menu_rounded, color: Colors.white),
            ),
          ),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: mobile ? Colors.white : WebDesign.text,
                  fontSize: mobile ? 16 : 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -.25,
                ),
              ),
              if (!mobile)
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: WebDesign.muted, fontSize: 10),
                ),
            ],
          ),
        ),
        if (trailing case final widget?)
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: mobile ? 118 : 220),
            child: IconTheme(
              data: IconThemeData(color: mobile ? Colors.white : null),
              child: widget,
            ),
          ),
        if (!mobile) ...[
          const SizedBox(width: 16),
          Container(width: 1, height: 32, color: WebDesign.border),
          const SizedBox(width: 16),
          CircleAvatar(
            radius: 17,
            backgroundColor: palette.soft,
            child: Icon(Icons.person_outline, size: 18, color: palette.primary),
          ),
          const SizedBox(width: 9),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 160),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profileName ?? roleLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: WebDesign.text,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (profileSubtitle case final text?)
                  Text(
                    text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: WebDesign.muted, fontSize: 9),
                  ),
              ],
            ),
          ),
        ],
      ],
    ),
  );
}

class _Navigation extends StatelessWidget {
  const _Navigation({
    required this.destinations,
    required this.selected,
    required this.expanded,
    required this.palette,
    required this.roleLabel,
    required this.profileName,
    required this.onLogout,
    required this.onSelect,
  });

  final List<WebDestination> destinations;
  final int selected;
  final bool expanded;
  final RolePalette palette;
  final String roleLabel;
  final String? profileName;
  final Future<void> Function() onLogout;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(gradient: palette.gradient),
    padding: const EdgeInsets.fromLTRB(9, 16, 9, 12),
    child: Column(
      children: [
        SizedBox(
          height: 48,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.apartment_rounded,
                color: Colors.white,
                size: 26,
              ),
              if (expanded) ...[
                const SizedBox(width: 9),
                const Text(
                  'HOMINODE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: .8,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (expanded)
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(11, 5, 11, 13),
              child: Text(
                roleLabel.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white60,
                  fontSize: 9,
                  letterSpacing: 1.1,
                ),
              ),
            ),
          ),
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.zero,
            itemCount: destinations.length,
            itemBuilder: (context, itemIndex) {
              final destination = destinations[itemIndex];
              final tile = ListTile(
                dense: true,
                visualDensity: const VisualDensity(vertical: -2),
                selected: itemIndex == selected,
                selectedTileColor: Colors.white.withValues(alpha: .14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(9),
                ),
                leading: Icon(destination.icon, color: Colors.white, size: 18),
                title: expanded
                    ? Text(
                        destination.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      )
                    : null,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: expanded ? 11 : 16,
                ),
                onTap: () => onSelect(itemIndex),
              );
              return Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: expanded
                    ? tile
                    : Tooltip(message: destination.label, child: tile),
              );
            },
          ),
        ),
        if (expanded && profileName != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(11, 8, 11, 4),
            child: Text(
              profileName!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white60, fontSize: 9),
            ),
          ),
        ListTile(
          dense: true,
          visualDensity: const VisualDensity(vertical: -2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
          leading: const Icon(
            Icons.logout_rounded,
            color: Colors.white,
            size: 18,
          ),
          title: expanded
              ? const Text(
                  'Logout',
                  style: TextStyle(color: Colors.white, fontSize: 11),
                )
              : null,
          contentPadding: EdgeInsets.symmetric(horizontal: expanded ? 11 : 16),
          onTap: onLogout,
        ),
      ],
    ),
  );
}
