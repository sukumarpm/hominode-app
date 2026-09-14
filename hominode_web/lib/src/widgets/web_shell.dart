import 'package:flutter/material.dart';

import '../theme/web_design_system.dart';
import 'community_visuals.dart';

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
    this.onNavigate,
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
  final ValueChanged<String>? onNavigate;
  final int initialIndex;
  final String? profileName;
  final String? profileSubtitle;
  final Widget? trailing;

  @override
  State<HominodeWebShell> createState() => _HominodeWebShellState();
}

class _HominodeWebShellState extends State<HominodeWebShell> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late int index = _safeIndex(widget.initialIndex);
  bool _collapsed = false;

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
    if (mobile && _scaffoldKey.currentState?.isDrawerOpen == true) {
      _scaffoldKey.currentState!.closeDrawer();
    }
    final path = widget.destinations[value].path;
    if (path != null && widget.onNavigate != null) {
      widget.onNavigate!(path);
      return;
    }
    setState(() => index = value);
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      if (widget.palette.isCommunityRole) {
        return _communityShell(context, constraints);
      }
      final desktop = constraints.maxWidth >= 1024;
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
        key: _scaffoldKey,
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
            if (tablet) SizedBox(width: desktop ? 232 : 76, child: navigation),
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

  Widget _communityShell(BuildContext context, BoxConstraints constraints) {
    final mobile = constraints.maxWidth < 720;
    final expanded = constraints.maxWidth >= 1100 && !_collapsed;
    final palette = widget.palette;
    final navigation = _Navigation(
      destinations: widget.destinations,
      selected: index,
      expanded: mobile || expanded,
      palette: palette,
      roleLabel: widget.roleLabel,
      profileName: widget.profileName,
      profileSubtitle: widget.profileSubtitle,
      onLogout: widget.onLogout,
      onSelect: (value) => _select(value, mobile),
    );
    return WebRoleStyle(
      palette: palette,
      child: Theme(
        data: communityWebTheme(Theme.of(context), palette),
        child: Scaffold(
          key: _scaffoldKey,
          backgroundColor: palette.canvas,
          drawer: mobile ? Drawer(width: 264, child: navigation) : null,
          body: Row(
            children: [
              if (!mobile)
                SizedBox(width: expanded ? 224 : 76, child: navigation),
              Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: palette.isResident
                        ? null
                        : LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              const Color(0xFFD4E6FF),
                              palette.canvas,
                              const Color(0xFFE1EFFF),
                            ],
                          ),
                  ),
                  child: Column(
                    children: [
                      _CommunityToolbar(
                        palette: palette,
                        mobile: mobile,
                        destinations: widget.destinations,
                        trailing: widget.trailing,
                        profileName: widget.profileName ?? widget.roleLabel,
                        community: widget.profileSubtitle,
                        onSelect: (value) => _select(value, false),
                        onMenu: () {
                          if (mobile) {
                            _scaffoldKey.currentState?.openDrawer();
                          } else {
                            setState(() => _collapsed = !_collapsed);
                          }
                        },
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: EdgeInsets.all(mobile ? 12 : 20),
                          child: Align(
                            alignment: Alignment.topCenter,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 1680),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  if (index == 0) ...[
                                    CommunityWelcome(
                                      title: widget.title,
                                      subtitle: widget.subtitle,
                                      palette: palette,
                                      dashboard: true,
                                    ),
                                    if (palette.isResident)
                                      const SizedBox(height: 16),
                                  ],
                                  widget.destinations[index].content,
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CommunityToolbar extends StatelessWidget {
  const _CommunityToolbar({
    required this.palette,
    required this.mobile,
    required this.destinations,
    required this.onSelect,
    required this.onMenu,
    required this.profileName,
    this.community,
    this.trailing,
  });
  final RolePalette palette;
  final bool mobile;
  final List<WebDestination> destinations;
  final ValueChanged<int> onSelect;
  final VoidCallback onMenu;
  final String profileName;
  final String? community;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Container(
    height: 70,
    padding: EdgeInsets.symmetric(horizontal: mobile ? 6 : 18),
    color: Colors.white.withValues(alpha: .72),
    child: Row(
      children: [
        IconButton(
          tooltip: mobile ? 'Open navigation' : 'Toggle sidebar',
          onPressed: onMenu,
          icon: const Icon(Icons.menu_rounded),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: SearchAnchor(
                builder: (context, controller) => SearchBar(
                  controller: controller,
                  hintText: mobile ? 'Find a page' : 'Search community pages…',
                  leading: const Icon(Icons.search_rounded, size: 20),
                  elevation: const WidgetStatePropertyAll(0),
                  constraints: const BoxConstraints(minHeight: 44),
                  backgroundColor: const WidgetStatePropertyAll(Colors.white),
                  hintStyle: const WidgetStatePropertyAll(
                    TextStyle(fontSize: 12, color: WebDesign.muted),
                  ),
                  onTap: controller.openView,
                  onChanged: (_) => controller.openView(),
                ),
                suggestionsBuilder: (context, controller) => [
                  for (var i = 0; i < destinations.length; i++)
                    if (destinations[i].label.toLowerCase().contains(
                      controller.text.toLowerCase(),
                    ))
                      ListTile(
                        leading: Icon(destinations[i].icon),
                        title: Text(destinations[i].label),
                        onTap: () {
                          controller.closeView(null);
                          onSelect(i);
                        },
                      ),
                ],
              ),
            ),
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 12),
          SizedBox(width: mobile ? 110 : 210, child: trailing),
        ] else if (!mobile && community != null) ...[
          const SizedBox(width: 16),
          Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.apartment_outlined,
                  size: 20,
                  color: palette.primary,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    community!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
        if (!mobile) ...[
          const SizedBox(width: 18),
          Tooltip(
            message: profileName,
            child: CircleAvatar(
              radius: 19,
              backgroundColor: palette.primary,
              foregroundColor: Colors.white,
              child: Text(
                profileName.isEmpty
                    ? 'H'
                    : profileName.substring(0, 1).toUpperCase(),
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ),
        ],
      ],
    ),
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
    height: mobile ? 66 : 64,
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
    this.profileSubtitle,
  });

  final List<WebDestination> destinations;
  final int selected;
  final bool expanded;
  final RolePalette palette;
  final String roleLabel;
  final String? profileName;
  final String? profileSubtitle;
  final Future<void> Function() onLogout;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      gradient: palette.isCommunityRole ? palette.sidebar : palette.gradient,
    ),
    padding: const EdgeInsets.fromLTRB(9, 16, 9, 12),
    child: Column(
      children: [
        if (palette.isCommunityRole && expanded)
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 22),
            child: Column(
              children: [
                Image.asset(
                  palette.isResident
                      ? 'assets/images/hominode_resident.png'
                      : 'assets/images/hominode_admin.png',
                  width: 84,
                  height: 84,
                  fit: BoxFit.contain,
                  excludeFromSemantics: true,
                  errorBuilder: (_, _, _) => const Icon(
                    Icons.apartment_rounded,
                    color: Colors.white,
                    size: 64,
                  ),
                ),
                const Text(
                  'HOMINODE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
                if (palette.isResident)
                  const Padding(
                    padding: EdgeInsets.only(top: 5),
                    child: Text(
                      'Smart living. Better lives.',
                      style: TextStyle(color: Color(0xFFE7C58B), fontSize: 11),
                    ),
                  ),
              ],
            ),
          )
        else
          SizedBox(
            height: 48,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.hub_outlined, color: Colors.white, size: 25),
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
        if (expanded && !palette.isCommunityRole)
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
                visualDensity: VisualDensity(
                  vertical: palette.isCommunityRole ? 0 : -2,
                ),
                selected: itemIndex == selected,
                selectedTileColor: palette.isCommunityRole
                    ? palette.selection
                    : Colors.white.withValues(alpha: .14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(9),
                ),
                leading: Icon(
                  destination.icon,
                  color: palette.isCommunityRole && itemIndex == selected
                      ? palette.selectionText
                      : Colors.white,
                  size: palette.isCommunityRole ? 21 : 18,
                ),
                title: expanded
                    ? Text(
                        destination.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color:
                              palette.isCommunityRole && itemIndex == selected
                              ? palette.selectionText
                              : Colors.white,
                          fontSize: palette.isCommunityRole ? 13 : 11,
                          fontWeight: FontWeight.w600,
                        ),
                      )
                    : null,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: expanded ? 11 : 16,
                ),
                onTap: () => onSelect(itemIndex),
              );
              final styledTile = palette.isCommunityRole
                  ? Material(
                      color: itemIndex == selected
                          ? palette.selection
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      child: tile,
                    )
                  : tile;
              return Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: expanded
                    ? styledTile
                    : Tooltip(message: destination.label, child: styledTile),
              );
            },
          ),
        ),
        if (expanded && palette.isCommunityRole)
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 10),
            leading: CircleAvatar(
              backgroundColor: palette.soft,
              child: Icon(Icons.person_outline, color: palette.primary),
            ),
            title: Text(
              profileName ?? roleLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
            subtitle: Text(
              profileSubtitle ?? roleLabel,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white70, fontSize: 10),
            ),
          ),
        if (expanded && profileName != null && !palette.isCommunityRole)
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
