// import 'package:flutter/material.dart';

// import '../theme/web_design_system.dart';

// class WebDestination {
//   const WebDestination(this.label, this.icon, this.content, {this.path});
//   final String label;
//   final IconData icon;
//   final Widget content;
//   final String? path;
// }

// class HominodeWebShell extends StatefulWidget {
//   const HominodeWebShell({
//     super.key,
//     required this.title,
//     required this.subtitle,
//     required this.roleLabel,
//     required this.palette,
//     required this.destinations,
//     required this.onLogout,
//     this.initialIndex = 0,
//     this.profileName,
//     this.profileSubtitle,
//     this.trailing,
//   });
//   final String title;
//   final String subtitle;
//   final String roleLabel;
//   final RolePalette palette;
//   final List<WebDestination> destinations;
//   final Future<void> Function() onLogout;
//   final int initialIndex;
//   final String? profileName;
//   final String? profileSubtitle;
//   final Widget? trailing;
//   @override
//   State<HominodeWebShell> createState() => _HominodeWebShellState();
// }

// class _HominodeWebShellState extends State<HominodeWebShell> {
//   late int index = widget.initialIndex.clamp(0, widget.destinations.length - 1);
//   void _select(int value, bool mobile) {
//     setState(() => index = value);
//     if (mobile) Navigator.pop(context);
//   }

//   @override
//   Widget build(BuildContext context) => LayoutBuilder(
//     builder: (context, constraints) {
//       final desktop = constraints.maxWidth >= 1100;
//       final tablet = constraints.maxWidth >= 720;
//       final mobile = !tablet;
//       final navigation = _Navigation(
//         destinations: widget.destinations,
//         selected: index,
//         expanded: desktop || mobile,
//         palette: widget.palette,
//         roleLabel: widget.roleLabel,
//         profileName: widget.profileName,
//         onLogout: widget.onLogout,
//         onSelect: (value) => _select(value, mobile),
//       );
//       return Scaffold(
//         backgroundColor: WebDesign.background,
//         drawer: mobile
//             ? Drawer(width: 260, child: SafeArea(child: navigation))
//             : null,
//         body: Row(
//           children: [
//             if (tablet) SizedBox(width: desktop ? 236 : 78, child: navigation),
//             Expanded(
//               child: Column(
//                 children: [
//                   Container(
//                     height: mobile ? 68 : 76,
//                     padding: EdgeInsets.symmetric(horizontal: mobile ? 12 : 24),
//                     decoration: BoxDecoration(
//                       gradient: mobile ? widget.palette.gradient : null,
//                       color: mobile ? null : Colors.white,
//                       border: mobile
//                           ? null
//                           : const Border(
//                               bottom: BorderSide(color: WebDesign.border),
//                             ),
//                     ),
//                     child: Row(
//                       children: [
//                         if (mobile)
//                           Builder(
//                             builder: (context) => IconButton(
//                               onPressed: () =>
//                                   Scaffold.of(context).openDrawer(),
//                               icon: const Icon(Icons.menu, color: Colors.white),
//                             ),
//                           ),
//                         Expanded(
//                           child: Column(
//                             mainAxisAlignment: MainAxisAlignment.center,
//                             crossAxisAlignment: CrossAxisAlignment.start,
//                             children: [
//                               Text(
//                                 widget.title,
//                                 maxLines: 1,
//                                 overflow: TextOverflow.ellipsis,
//                                 style: TextStyle(
//                                   color: mobile ? Colors.white : WebDesign.text,
//                                   fontSize: mobile ? 17 : 21,
//                                   fontWeight: FontWeight.w800,
//                                 ),
//                               ),
//                               if (!mobile)
//                                 Text(
//                                   widget.subtitle,
//                                   style: const TextStyle(
//                                     color: WebDesign.muted,
//                                     fontSize: 11,
//                                   ),
//                                 ),
//                             ],
//                           ),
//                         ),
//                         if (widget.trailing != null) widget.trailing!,
//                         if (!mobile) ...[
//                           const SizedBox(width: 14),
//                           CircleAvatar(
//                             radius: 17,
//                             backgroundColor: widget.palette.soft,
//                             child: Icon(
//                               Icons.person_outline,
//                               size: 18,
//                               color: widget.palette.primary,
//                             ),
//                           ),
//                           const SizedBox(width: 8),
//                           ConstrainedBox(
//                             constraints: const BoxConstraints(maxWidth: 150),
//                             child: Column(
//                               mainAxisAlignment: MainAxisAlignment.center,
//                               crossAxisAlignment: CrossAxisAlignment.start,
//                               children: [
//                                 Text(
//                                   widget.profileName ?? widget.roleLabel,
//                                   overflow: TextOverflow.ellipsis,
//                                   style: const TextStyle(
//                                     fontSize: 12,
//                                     fontWeight: FontWeight.w700,
//                                   ),
//                                 ),
//                                 if (widget.profileSubtitle != null)
//                                   Text(
//                                     widget.profileSubtitle!,
//                                     overflow: TextOverflow.ellipsis,
//                                     style: const TextStyle(
//                                       fontSize: 10,
//                                       color: WebDesign.muted,
//                                     ),
//                                   ),
//                               ],
//                             ),
//                           ),
//                         ],
//                       ],
//                     ),
//                   ),
//                   Expanded(
//                     child: SingleChildScrollView(
//                       padding: EdgeInsets.all(
//                         mobile ? 14 : WebDesign.pagePadding,
//                       ),
//                       child: widget.destinations[index].content,
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ],
//         ),
//       );
//     },
//   );
// }

// class _Navigation extends StatelessWidget {
//   const _Navigation({
//     required this.destinations,
//     required this.selected,
//     required this.expanded,
//     required this.palette,
//     required this.roleLabel,
//     required this.profileName,
//     required this.onLogout,
//     required this.onSelect,
//   });
//   final List<WebDestination> destinations;
//   final int selected;
//   final bool expanded;
//   final RolePalette palette;
//   final String roleLabel;
//   final String? profileName;
//   final Future<void> Function() onLogout;
//   final ValueChanged<int> onSelect;
//   @override
//   Widget build(BuildContext context) => Container(
//     decoration: BoxDecoration(gradient: palette.gradient),
//     padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 9),
//     child: Column(
//       children: [
//         SizedBox(
//           height: 52,
//           child: Row(
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: [
//               const Icon(
//                 Icons.apartment_rounded,
//                 color: Colors.white,
//                 size: 27,
//               ),
//               if (expanded) ...[
//                 const SizedBox(width: 9),
//                 const Text(
//                   'Hominode',
//                   style: TextStyle(
//                     color: Colors.white,
//                     fontWeight: FontWeight.w800,
//                     fontSize: 18,
//                   ),
//                 ),
//               ],
//             ],
//           ),
//         ),
//         if (expanded)
//           Padding(
//             padding: const EdgeInsets.only(bottom: 18),
//             child: Text(
//               roleLabel.toUpperCase(),
//               style: const TextStyle(
//                 color: Colors.white60,
//                 letterSpacing: 1.2,
//                 fontSize: 9,
//               ),
//             ),
//           ),
//         for (var i = 0; i < destinations.length; i++)
//           Padding(
//             padding: const EdgeInsets.only(bottom: 5),
//             child: ListTile(
//               dense: true,
//               selected: i == selected,
//               selectedTileColor: Colors.white.withValues(alpha: .13),
//               shape: RoundedRectangleBorder(
//                 borderRadius: BorderRadius.circular(9),
//               ),
//               leading: Icon(
//                 destinations[i].icon,
//                 color: Colors.white,
//                 size: 19,
//               ),
//               title: expanded
//                   ? Text(
//                       destinations[i].label,
//                       style: const TextStyle(color: Colors.white, fontSize: 12),
//                     )
//                   : null,
//               contentPadding: EdgeInsets.symmetric(
//                 horizontal: expanded ? 12 : 16,
//               ),
//               onTap: () => onSelect(i),
//             ),
//           ),
//         const Spacer(),
//         if (expanded && profileName != null)
//           Padding(
//             padding: const EdgeInsets.all(10),
//             child: Text(
//               profileName!,
//               maxLines: 1,
//               overflow: TextOverflow.ellipsis,
//               style: const TextStyle(color: Colors.white70, fontSize: 11),
//             ),
//           ),
//         ListTile(
//           dense: true,
//           leading: const Icon(Icons.logout, color: Colors.white, size: 19),
//           title: expanded
//               ? const Text(
//                   'Logout',
//                   style: TextStyle(color: Colors.white, fontSize: 12),
//                 )
//               : null,
//           contentPadding: EdgeInsets.symmetric(horizontal: expanded ? 12 : 16),
//           onTap: onLogout,
//         ),
//       ],
//     ),
//   );
// }
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
    if (nextIndex != index) {
      index = nextIndex;
    }
  }

  void _select(int value, bool mobile) {
    if (value < 0 || value >= widget.destinations.length) return;

    if (mobile && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }

    setState(() {
      index = value;
    });

    final path = widget.destinations[value].path;

    debugPrint(
      'WEB NAV: index=$value '
      'label=${widget.destinations[value].label} '
      'path=$path',
    );
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final desktop = constraints.maxWidth >= 1100;
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
            ? Drawer(width: 260, child: SafeArea(child: navigation))
            : null,
        body: Row(
          children: [
            if (tablet) SizedBox(width: desktop ? 236 : 78, child: navigation),
            Expanded(
              child: Column(
                children: [
                  Container(
                    height: mobile ? 68 : 76,
                    padding: EdgeInsets.symmetric(horizontal: mobile ? 12 : 24),
                    decoration: BoxDecoration(
                      gradient: mobile ? widget.palette.gradient : null,
                      color: mobile ? null : Colors.white,
                      border: mobile
                          ? null
                          : const Border(
                              bottom: BorderSide(color: WebDesign.border),
                            ),
                    ),
                    child: Row(
                      children: [
                        if (mobile)
                          Builder(
                            builder: (context) => IconButton(
                              onPressed: () =>
                                  Scaffold.of(context).openDrawer(),
                              icon: const Icon(Icons.menu, color: Colors.white),
                            ),
                          ),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: mobile ? Colors.white : WebDesign.text,
                                  fontSize: mobile ? 17 : 21,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              if (!mobile)
                                Text(
                                  widget.subtitle,
                                  style: const TextStyle(
                                    color: WebDesign.muted,
                                    fontSize: 11,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (widget.trailing != null) widget.trailing!,
                        if (!mobile) ...[
                          const SizedBox(width: 14),
                          CircleAvatar(
                            radius: 17,
                            backgroundColor: widget.palette.soft,
                            child: Icon(
                              Icons.person_outline,
                              size: 18,
                              color: widget.palette.primary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 150),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.profileName ?? widget.roleLabel,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                if (widget.profileSubtitle != null)
                                  Text(
                                    widget.profileSubtitle!,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: WebDesign.muted,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.all(
                        mobile ? 14 : WebDesign.pagePadding,
                      ),
                      child: widget.destinations[index].content,
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
    padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 9),
    child: Column(
      children: [
        SizedBox(
          height: 52,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.apartment_rounded,
                color: Colors.white,
                size: 27,
              ),
              if (expanded) ...[
                const SizedBox(width: 9),
                const Text(
                  'Hominode',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (expanded)
          Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: Text(
              roleLabel.toUpperCase(),
              style: const TextStyle(
                color: Colors.white60,
                letterSpacing: 1.2,
                fontSize: 9,
              ),
            ),
          ),
        for (var i = 0; i < destinations.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: ListTile(
              dense: true,
              selected: i == selected,
              selectedTileColor: Colors.white.withValues(alpha: .13),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(9),
              ),
              leading: Icon(
                destinations[i].icon,
                color: Colors.white,
                size: 19,
              ),
              title: expanded
                  ? Text(
                      destinations[i].label,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    )
                  : null,
              contentPadding: EdgeInsets.symmetric(
                horizontal: expanded ? 12 : 16,
              ),
              onTap: () => onSelect(i),
            ),
          ),
        const Spacer(),
        if (expanded && profileName != null)
          Padding(
            padding: const EdgeInsets.all(10),
            child: Text(
              profileName!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ),
        ListTile(
          dense: true,
          leading: const Icon(Icons.logout, color: Colors.white, size: 19),
          title: expanded
              ? const Text(
                  'Logout',
                  style: TextStyle(color: Colors.white, fontSize: 12),
                )
              : null,
          contentPadding: EdgeInsets.symmetric(horizontal: expanded ? 12 : 16),
          onTap: onLogout,
        ),
      ],
    ),
  );
}
