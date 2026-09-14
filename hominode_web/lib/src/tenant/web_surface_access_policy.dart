import '../session/web_session.dart';
import 'web_host.dart';

class WebSurfaceAccessPolicy {
  const WebSurfaceAccessPolicy._();

  static String? denialReason(WebHostContext host, WebSession session) {
    final surface = host.classification.surface;
    if (surface == WebSurface.admin && session.role == WebRole.resident) {
      return 'Resident accounts must use their community website.';
    }
    if (host.isResidentSurface) {
      final community = host.community;
      if (session.role != WebRole.resident ||
          community == null ||
          session.activeTenant?.communityId != community.communityId ||
          session.activeTenant?.slug != community.slug) {
        return 'This account cannot access the community selected by the hostname.';
      }
    }
    if (surface == WebSurface.localDevelopment &&
        session.role == WebRole.resident &&
        host.community == null) {
      return 'Local Resident Web requires HOMINODE_DEV_COMMUNITY_SLUG.';
    }
    return null;
  }
}
