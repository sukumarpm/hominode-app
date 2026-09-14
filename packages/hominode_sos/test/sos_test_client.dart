import 'dart:async';
import 'package:hominode_sos/hominode_sos.dart';

class TestSosClient implements SosClient {
  final updates = StreamController<SosAlert?>.broadcast();
  final lists = StreamController<List<SosAlert>>.broadcast();
  SosAlert? current;
  List<SosAlert> alerts = [];
  String? activeAlertId;
  Object? triggerError;
  Completer<void>? triggerWait;
  Completer<void>? actionWait;
  int triggers = 0;
  int actions = 0;
  Map<String, dynamic>? lastLocation;
  final requestIds = <String>[];
  final watchedCommunities = <String>[];

  SosAlert alert(String status) => SosAlert('alert', {'communityId': 'community', 'communityName': 'Community', 'residentName': 'Resident',
    'buildingName': 'Villa Cluster', 'unitLabel': 'Villa-03', 'status': status, 'triggeredAt': DateTime.now(), 'locationAvailable': false});
  void emit(String status) {current = alert(status); updates.add(current);}
  @override
  Future<SosContext> context() async => SosContext(communityId: 'community', residentUid: 'resident', activeAlertId: activeAlertId);
  @override
  Future<String> trigger(String requestId, Map<String, dynamic>? location) async {
    triggers++; requestIds.add(requestId); lastLocation = location;
    if (triggerWait != null) await triggerWait!.future;
    if (triggerError != null) throw triggerError!;
    emit('triggered'); return 'alert';
  }
  @override
  Future<void> transition(String communityId, String alertId, String action, {String? note}) async {
    actions++; if (actionWait != null) await actionWait!.future;
    emit({'acknowledge': 'acknowledged', 'respond': 'responding', 'resolve': 'resolved', 'cancel': 'cancelled'}[action]!);
  }
  @override
  Stream<SosAlert?> watchAlert(String communityId, String alertId) => Stream.multi((sink) {
    watchedCommunities.add(communityId); sink.add(current);
    final subscription = updates.stream.listen(sink.add, onError: sink.addError);
    sink.onCancel = subscription.cancel;
  });
  @override
  Stream<List<SosAlert>> watchAlerts(String communityId, {bool active = true, String? residentUid}) => Stream.multi((sink) {
    watchedCommunities.add(communityId); sink.add(alerts.where((a) => a.active == active).toList());
    final subscription = lists.stream.listen((value) => sink.add(value.where((a) => a.active == active).toList()));
    sink.onCancel = subscription.cancel;
  });
  Future<void> dispose() async {await updates.close(); await lists.close();}
}
