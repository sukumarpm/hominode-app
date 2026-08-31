// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:flutter/material.dart';

// import 'pages/login_page.dart';
// import 'pages/role_homes.dart';
// import 'session/web_session.dart';
// import 'session/web_session_resolver.dart';
// import 'theme/web_design_system.dart';

// class HominodeWebApp extends StatelessWidget {
//   const HominodeWebApp({super.key});

//   @override
//   Widget build(BuildContext context) => MaterialApp(
//     title: 'Hominode',
//     debugShowCheckedModeBanner: false,
//     theme: ThemeData(
//       colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1558D6)),
//       scaffoldBackgroundColor: WebDesign.background,
//       useMaterial3: true,
//       fontFamily: 'Arial',
//       cardTheme: CardThemeData(
//         elevation: 0,
//         margin: EdgeInsets.zero,
//         color: Colors.white,
//         shape: RoundedRectangleBorder(
//           side: const BorderSide(color: WebDesign.border),
//           borderRadius: BorderRadius.circular(WebDesign.radius),
//         ),
//       ),
//     ),
//     initialRoute: _initialPath(),
//     onGenerateRoute: (settings) => MaterialPageRoute(
//       settings: settings,
//       builder: (_) => WebAuthGuard(requestedPath: settings.name ?? '/'),
//     ),
//   );

//   static String _initialPath() {
//     final path = Uri.base.path;
//     return path.isEmpty ? '/' : path;
//   }
// }

// class WebAuthGuard extends StatefulWidget {
//   const WebAuthGuard({super.key, required this.requestedPath});
//   final String requestedPath;

//   @override
//   State<WebAuthGuard> createState() => _WebAuthGuardState();
// }

// class _WebAuthGuardState extends State<WebAuthGuard> {
//   late final WebSessionResolver _resolver;
//   WebSession? _session;
//   String? _error;
//   bool _loading = true;

//   @override
//   void initState() {
//     super.initState();
//     _resolver = WebSessionResolver(
//       FirestoreWebProfileStore(),
//       LocalTenantSelectionStore(),
//     );
//     _restore();
//   }

//   Future<void> _restore() async {
//     final user = FirebaseAuth.instance.currentUser;
//     if (user == null) {
//       if (mounted) setState(() => _loading = false);
//       return;
//     }
//     try {
//       final session = await _resolver.resolve(user.uid);
//       if (mounted) {
//         setState(() {
//           _session = session;
//           _loading = false;
//           _error = null;
//         });
//       }
//     } on SessionResolutionException catch (error) {
//       await FirebaseAuth.instance.signOut();
//       if (mounted) {
//         setState(() {
//           _loading = false;
//           _error = error.message;
//         });
//       }
//     }
//   }

//   Future<void> _selectTenant(String id) async {
//     final current = _session!;
//     final next = await _resolver.selectAdminTenant(current, id);
//     if (mounted) setState(() => _session = next);
//   }

//   @override
//   Widget build(BuildContext context) {
//     if (_loading) {
//       return const Scaffold(body: Center(child: CircularProgressIndicator()));
//     }
//     if (_session == null) {
//       return LoginPage(error: _error, onAuthenticated: _restore);
//     }
//     if (_session!.needsTenantSelection) {
//       return TenantSelectionPage(
//         session: _session!,
//         onSelect: _selectTenant,
//         onLogout: _logout,
//       );
//     }
//     final safePath = WebAuthGuardStatePolicy.guardedPath(
//       widget.requestedPath,
//       _session!,
//     );
//     return switch (_session!.role) {
//       WebRole.superAdmin => SuperAdminWebHome(
//         initialPath: safePath,
//         onLogout: _logout,
//       ),
//       WebRole.admin => AdminWebHome(
//         session: _session!,
//         onSelectTenant: _selectTenant,
//         onLogout: _logout,
//       ),
//       WebRole.resident => ResidentWebHome(
//         session: _session!,
//         onLogout: _logout,
//       ),
//     };
//   }

//   Future<void> _logout() async {
//     await FirebaseAuth.instance.signOut();
//     if (mounted) {
//       setState(() {
//         _session = null;
//         _error = null;
//       });
//     }
//   }
// }

// abstract final class WebAuthGuardStatePolicy {
//   static String guardedPath(String requested, WebSession session) {
//     if (requested == '/' ||
//         requested == '/login' ||
//         requested == session.canonicalPath) {
//       return session.canonicalPath;
//     }
//     if (session.role == WebRole.superAdmin &&
//         (requested == '/super-admin/communities' ||
//             requested == '/super-admin/admins')) {
//       return requested;
//     }
//     if (requested.startsWith('/${session.activeTenant?.slug ?? '__none__'}')) {
//       return session.canonicalPath;
//     }
//     return session.canonicalPath;
//   }
// }
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'pages/login_page.dart';
import 'pages/role_homes.dart';
import 'session/web_session.dart';
import 'session/web_session_resolver.dart';
import 'theme/web_design_system.dart';

class HominodeWebApp extends StatelessWidget {
  const HominodeWebApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hominode',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1558D6)),
        scaffoldBackgroundColor: WebDesign.background,
        useMaterial3: true,
        fontFamily: 'Arial',
        cardTheme: CardThemeData(
          elevation: 0,
          margin: EdgeInsets.zero,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            side: const BorderSide(color: WebDesign.border),
            borderRadius: BorderRadius.circular(WebDesign.radius),
          ),
        ),
      ),
      initialRoute: _initialPath(),
      onGenerateRoute: (settings) {
        final requestedPath = settings.name ?? '/';

        return MaterialPageRoute(
          settings: settings,
          builder: (_) => WebAuthGuard(requestedPath: requestedPath),
        );
      },
    );
  }

  static String _initialPath() {
    final path = Uri.base.path;
    return path.isEmpty ? '/' : path;
  }
}

class WebAuthGuard extends StatefulWidget {
  const WebAuthGuard({super.key, required this.requestedPath});

  final String requestedPath;

  @override
  State<WebAuthGuard> createState() => _WebAuthGuardState();
}

class _WebAuthGuardState extends State<WebAuthGuard> {
  late final WebSessionResolver _resolver;

  WebSession? _session;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();

    _resolver = WebSessionResolver(
      FirestoreWebProfileStore(),
      LocalTenantSelectionStore(),
    );

    _restore();
  }

  Future<void> _restore() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      if (mounted) {
        setState(() {
          _loading = false;
          _session = null;
        });
      }
      return;
    }

    try {
      final session = await _resolver.resolve(user.uid);

      if (!mounted) return;

      setState(() {
        _session = session;
        _loading = false;
        _error = null;
      });
    } on SessionResolutionException catch (error) {
      await FirebaseAuth.instance.signOut();

      if (!mounted) return;

      setState(() {
        _loading = false;
        _session = null;
        _error = error.message;
      });
    }
  }

  Future<void> _selectTenant(String id) async {
    final current = _session;
    if (current == null) return;

    final next = await _resolver.selectAdminTenant(current, id);

    if (!mounted) return;

    setState(() {
      _session = next;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_session == null) {
      return LoginPage(error: _error, onAuthenticated: _restore);
    }

    if (_session!.needsTenantSelection) {
      return TenantSelectionPage(
        session: _session!,
        onSelect: _selectTenant,
        onLogout: _logout,
      );
    }

    final safePath = WebAuthGuardStatePolicy.guardedPath(
      widget.requestedPath,
      _session!,
    );

    switch (_session!.role) {
      case WebRole.superAdmin:
        return SuperAdminWebHome(
          initialPath: safePath,
          onNavigate: _navigate,
          onLogout: _logout,
        );

      case WebRole.admin:
        return AdminWebHome(
          session: _session!,
          onSelectTenant: _selectTenant,
          onNavigate: _navigate,
          onLogout: _logout,
        );

      case WebRole.resident:
        return ResidentWebHome(
          session: _session!,
          onNavigate: _navigate,
          onLogout: _logout,
        );
    }
  }

  void _navigate(String path) {
    final current = ModalRoute.of(context)?.settings.name;

    if (current == path) return;

    Navigator.of(context).pushReplacementNamed(path);
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();

    if (!mounted) return;

    setState(() {
      _session = null;
      _error = null;
    });

    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
  }
}

abstract final class WebAuthGuardStatePolicy {
  static String guardedPath(String requested, WebSession session) {
    if (requested == '/' ||
        requested == '/login' ||
        requested == session.canonicalPath) {
      return session.canonicalPath;
    }

    switch (session.role) {
      case WebRole.superAdmin:
        if (requested == '/super-admin' ||
            requested == '/super-admin/communities' ||
            requested == '/super-admin/admins' ||
            requested == '/super-admin/platform-overview') {
          return requested;
        }
        return '/super-admin';

      case WebRole.admin:
        const adminPaths = {
          '/admin',
          '/admin/community',
          '/admin/buildings',
          '/admin/residents',
          '/admin/visitors',
          '/admin/complaints',
          '/admin/amenities',
          '/admin/billing',
          '/admin/events',
          '/admin/reports',
          '/admin/settings',
        };
        if (adminPaths.contains(requested)) return requested;

        final slug = session.activeTenant?.slug;

        if (slug != null && slug.isNotEmpty && requested.startsWith('/$slug')) {
          return '/admin';
        }

        return '/admin';

      case WebRole.resident:
        if (requested == '/resident') {
          return '/resident';
        }

        final slug = session.activeTenant?.slug;

        if (slug != null && slug.isNotEmpty && requested.startsWith('/$slug')) {
          return '/resident';
        }

        return '/resident';
    }
  }
}
