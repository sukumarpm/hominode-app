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
import 'tenant/web_host.dart';
import 'tenant/web_surface_access_policy.dart';
import 'theme/web_design_system.dart';

class HominodeWebApp extends StatefulWidget {
  const HominodeWebApp({super.key});

  @override
  State<HominodeWebApp> createState() => _HominodeWebAppState();
}

class _HominodeWebAppState extends State<HominodeWebApp> {
  late final Future<WebHostContext> _hostContext = _resolveHostContext();

  Future<WebHostContext> _resolveHostContext() async {
    final uri = Uri.base;
    return WebHostResolver().resolve(uri);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<WebHostContext>(
      future: _hostContext,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _BootstrapLoadingView();
        }
        if (snapshot.hasError) {
          final message = snapshot.error is WebHostResolutionException
              ? (snapshot.error! as WebHostResolutionException).message
              : 'This community is currently unavailable.';
          return _publicApp(_PublicBoundary(message: message));
        }

        final hostContext = snapshot.data;
        if (hostContext == null) {
          return _publicApp(
            const _PublicBoundary(
              message: 'This community is currently unavailable.',
            ),
          );
        }
        final community = hostContext.community;
        if (hostContext.classification.surface ==
                WebSurface.residentCommunity &&
            (community == null || community.slug.isEmpty)) {
          return _publicApp(
            const _PublicBoundary(
              message: 'This community is currently unavailable.',
            ),
          );
        }
        switch (hostContext.classification.surface) {
          case WebSurface.marketing:
            return _publicApp(
              const _PublicBoundary(
                title: 'Hominode',
                message: 'Community living, connected.',
              ),
            );
          case WebSurface.invalid:
            return _publicApp(
              const _PublicBoundary(message: 'Community not found.'),
            );
          case WebSurface.admin:
          case WebSurface.residentCommunity:
          case WebSurface.localDevelopment:
            return _protectedApp(hostContext);
        }
      },
    );
  }

  MaterialApp _protectedApp(WebHostContext hostContext) {
    Route<dynamic> routeFor(RouteSettings settings) {
      final externalPath = settings.name ?? '/';
      final internalPath = hostContext.internalPathFor(externalPath);

      if (internalPath == WebHostContext.invalidResidentPath) {
        return MaterialPageRoute(
          settings: RouteSettings(
            name: externalPath,
            arguments: settings.arguments,
          ),
          builder: (_) => const _PublicBoundary(
            message: 'This community is currently unavailable.',
          ),
        );
      }

      return MaterialPageRoute(
        settings: RouteSettings(
          name: externalPath,
          arguments: settings.arguments,
        ),
        builder: (_) => WebHostScope(
          hostContext: hostContext,
          child: WebAuthGuard(
            requestedPath: internalPath,
            hostContext: hostContext,
          ),
        ),
      );
    }

    final theme = _theme();
    final initialPath = _initialPath();
    final safeInitialRoute = initialPath.isEmpty ? '/' : initialPath;

    return MaterialApp(
      key: const ValueKey('protected-app'),
      title: 'Hominode',
      debugShowCheckedModeBanner: false,
      theme: theme,
      initialRoute: safeInitialRoute,
      onGenerateRoute: routeFor,
      onGenerateInitialRoutes: (initialRoute) => [
        routeFor(RouteSettings(name: initialRoute)),
      ],
    );
  }

  MaterialApp _publicApp(Widget home) => MaterialApp(
    key: const ValueKey('public-app'),
    title: 'Hominode',
    debugShowCheckedModeBanner: false,
    theme: _theme(),
    home: home,
  );

  ThemeData _theme() => ThemeData(
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
  );

  static String _initialPath() {
    final path = Uri.base.path;
    return path.isEmpty ? '/' : path;
  }
}

class _BootstrapLoadingView extends StatelessWidget {
  const _BootstrapLoadingView();

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}

class _PublicBoundary extends StatelessWidget {
  const _PublicBoundary({this.title = 'Hominode', required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    ),
  );
}

class WebAuthGuard extends StatefulWidget {
  const WebAuthGuard({
    super.key,
    required this.requestedPath,
    required this.hostContext,
  });

  final String requestedPath;
  final WebHostContext hostContext;

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
    final User? user = FirebaseAuth.instance.currentUser;

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
      final expectedCommunityId = widget.hostContext.isResidentSurface
          ? widget.hostContext.community?.communityId
          : null;
      final session = await _resolver.resolve(
        user.uid,
        expectedResidentCommunityId: expectedCommunityId,
      );
      _requireSurfaceAccess(session);

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

  void _requireSurfaceAccess(WebSession session) {
    final reason = WebSurfaceAccessPolicy.denialReason(
      widget.hostContext,
      session,
    );
    if (reason != null) throw SessionResolutionException(reason);
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
          currentPath: safePath,
          onNavigate: _navigate,
          onLogout: _logout,
        );
    }
  }

  void _navigate(String path) {
    final externalPath = widget.hostContext.externalPathFor(path);
    final current = ModalRoute.of(context)?.settings.name;

    if (current == externalPath) return;

    Navigator.of(context).pushReplacementNamed(externalPath);
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();

    if (!mounted) return;

    setState(() {
      _session = null;
      _error = null;
    });

    final loginPath = widget.hostContext.externalPathFor('/login');
    Navigator.of(context).pushNamedAndRemoveUntil(loginPath, (route) => false);
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
        if (residentRoutePaths.contains(requested)) return requested;

        final slug = session.activeTenant?.slug;

        if (slug != null && slug.isNotEmpty && requested.startsWith('/$slug')) {
          return '/resident';
        }

        return '/resident';
    }
  }
}
