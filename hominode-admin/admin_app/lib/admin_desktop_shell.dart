import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'desktop/admin_desktop_design.dart';
import 'navigation/admin_module_destinations.dart';
import 'navigation/admin_module_routes.dart';
import 'notifications_screen.dart';
import 'services/admin_tenant_context.dart';

const double adminDesktopBreakpoint = 1024;

class AdminDesktopShell extends StatefulWidget {
  AdminDesktopShell({
    super.key,
    List<AdminModuleDestination>? destinations,
    this.initialModule = AdminModuleId.dashboard,
  }) : destinations = destinations ?? adminModuleDestinations;

  final List<AdminModuleDestination> destinations;
  final AdminModuleId initialModule;

  @override
  State<AdminDesktopShell> createState() => _AdminDesktopShellState();
}

class _AdminDesktopShellState extends State<AdminDesktopShell> {
  late int _selectedIndex;
  bool _collapsed = false;

  @override
  void initState() {
    super.initState();
    _selectedIndex = _indexForModule(widget.initialModule);
  }

  int _indexForModule(AdminModuleId id) {
    final index = widget.destinations.indexWhere(
      (destination) => destination.id == id,
    );
    return index < 0 ? 0 : index;
  }

  void _selectModule(AdminModuleId id) {
    _navigateToIndex(_indexForModule(id));
  }

  void _navigateToIndex(int index) {
    if (index < 0 || index >= widget.destinations.length) return;
    final next = widget.destinations[index];
    final nextRoute = adminRoutePathForModule(next.id);
    final currentRoute = ModalRoute.of(context)?.settings.name;
    if (currentRoute == nextRoute) {
      if (_selectedIndex != index) {
        setState(() => _selectedIndex = index);
      }
      return;
    }
    try {
      Navigator.of(context).pushNamed(nextRoute);
    } catch (_) {
      if (_selectedIndex != index) {
        setState(() => _selectedIndex = index);
      }
    }
  }

  @override
  void didUpdateWidget(covariant AdminDesktopShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialModule != oldWidget.initialModule) {
      _selectedIndex = _indexForModule(widget.initialModule);
    }
    if (_selectedIndex >= widget.destinations.length || _selectedIndex < 0) {
      _selectedIndex = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.destinations.isEmpty) {
      return const Scaffold(body: Center(child: Text('No admin modules')));
    }

    final selected = widget.destinations[_selectedIndex];
    return Scaffold(
      backgroundColor: AdminDesktopDesign.background,
      body: Row(
        children: [
          SizedBox(
            width: _collapsed ? 76 : 224,
            child: _DesktopSidebar(
              destinations: widget.destinations,
              expanded: !_collapsed,
              selectedIndex: _selectedIndex,
              onSelected: _navigateToIndex,
            ),
          ),
          Expanded(
            child: Column(
              children: [
                _DesktopTopBar(
                  title: selected.label,
                  destinations: widget.destinations,
                  onSelected: _navigateToIndex,
                  onMenu: () => setState(() => _collapsed = !_collapsed),
                  onNotifications: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const NotificationsScreen(),
                    ),
                  ),
                  onProfile: () => _selectModule(AdminModuleId.profile),
                ),
                Expanded(
                  child: ColoredBox(
                    color: AdminDesktopDesign.background,
                    child: LayoutBuilder(
                      builder: (context, constraints) => ScreenUtilInit(
                        designSize: Size(
                          constraints.maxWidth,
                          constraints.maxHeight,
                        ),
                        minTextAdapt: true,
                        splitScreenMode: true,
                        builder: (context, _) => Theme(
                          data: adminDesktopTheme(context),
                          child: AdminDesktopShellScope(
                            onSelectModule: (moduleName) {
                              final index = widget.destinations.indexWhere(
                                (destination) =>
                                    destination.id.name == moduleName,
                              );
                              if (index >= 0) {
                                _navigateToIndex(index);
                              }
                            },
                            child: KeyedSubtree(
                              key: ValueKey(selected.id),
                              child: selected.builder(context),
                            ),
                          ),
                        ),
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
  }
}

class _DesktopSidebar extends StatelessWidget {
  const _DesktopSidebar({
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
    this.expanded = true,
  });

  final List<AdminModuleDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final bool expanded;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      gradient: AdminDesktopDesign.sidebarGradient,
    ),
    child: SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(12, 22, 12, expanded ? 20 : 10),
            child: Column(
              children: [
                Image.asset(
                  'assets/Admin_New.png',
                  width: expanded ? 84 : 42,
                  height: expanded ? 84 : 42,
                  fit: BoxFit.contain,
                  excludeFromSemantics: true,
                  errorBuilder: (_, _, _) => const Icon(
                    Icons.apartment_rounded,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
                if (expanded)
                  const Text(
                    'HOMINODE',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 14),
              itemCount: destinations.length,
              itemBuilder: (context, index) {
                final destination = destinations[index];
                final selected = index == selectedIndex;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Material(
                    color: selected
                        ? AdminDesktopDesign.primary
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    child: Tooltip(
                      message: destination.label,
                      child: ListTile(
                        selected: selected,
                        minTileHeight: 48,
                        minLeadingWidth: 24,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 13,
                        ),
                        leading: Icon(
                          destination.icon,
                          size: 19,
                          color: selected
                              ? Colors.white
                              : const Color(0xFF9DB0C3),
                        ),
                        title: expanded
                            ? Text(
                                destination.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: selected
                                      ? Colors.white
                                      : const Color(0xFFD0D9E2),
                                  fontSize: 13,
                                  fontWeight: selected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                ),
                              )
                            : null,
                        onTap: () => onSelected(index),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}

class _DesktopTopBar extends StatelessWidget {
  const _DesktopTopBar({
    required this.title,
    required this.onNotifications,
    required this.onProfile,
    required this.onMenu,
    required this.destinations,
    required this.onSelected,
  });

  final String title;
  final VoidCallback onNotifications;
  final VoidCallback onProfile;
  final VoidCallback onMenu;
  final List<AdminModuleDestination> destinations;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final tenant = AdminTenantContext.instance;
    final communityName = tenant.name?.trim();

    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE4EAF0))),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Toggle sidebar',
            onPressed: onMenu,
            icon: const Icon(Icons.menu_rounded),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SearchAnchor(
              builder: (context, controller) => SearchBar(
                controller: controller,
                hintText: 'Search community pages…',
                leading: const Icon(Icons.search, size: 20),
                elevation: const WidgetStatePropertyAll(0),
                backgroundColor: const WidgetStatePropertyAll(
                  AdminDesktopDesign.soft,
                ),
                constraints: const BoxConstraints(minHeight: 44),
                hintStyle: const WidgetStatePropertyAll(
                  TextStyle(fontSize: 12),
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
                        onSelected(i);
                      },
                    ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          _TopBarAction(
            tooltip: 'Notifications',
            icon: Icons.notifications_none_outlined,
            onPressed: onNotifications,
          ),
          const SizedBox(width: 8),
          Container(width: 1, height: 32, color: AdminDesktopDesign.border),
          const SizedBox(width: 14),
          const CircleAvatar(
            radius: 18,
            backgroundColor: AdminDesktopDesign.soft,
            child: Icon(
              Icons.apartment_outlined,
              size: 19,
              color: AdminDesktopDesign.primary,
            ),
          ),
          const SizedBox(width: 9),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 220),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  communityName == null || communityName.isEmpty
                      ? 'Admin workspace'
                      : communityName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AdminDesktopDesign.text,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Text(
                  'Administrator',
                  style: TextStyle(
                    color: AdminDesktopDesign.muted,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _TopBarAction(
            tooltip: 'Profile',
            icon: Icons.account_circle_outlined,
            onPressed: onProfile,
          ),
        ],
      ),
    );
  }
}

class _TopBarAction extends StatelessWidget {
  const _TopBarAction({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: IconButton(
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      style: IconButton.styleFrom(
        fixedSize: const Size.square(40),
        foregroundColor: AdminDesktopDesign.muted,
        backgroundColor: Colors.white,
        side: const BorderSide(color: AdminDesktopDesign.border),
      ),
    ),
  );
}
