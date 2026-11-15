import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// Gives the existing legal gate a fresh State for each authenticated UID.
/// Late acceptance callbacks remain attached to the disposed account's gate.
class ResidentLegalSessionGate extends StatefulWidget {
  const ResidentLegalSessionGate({super.key, required this.child, this.auth});
  final Widget child;
  final FirebaseAuth? auth;

  @override
  State<ResidentLegalSessionGate> createState() =>
      _ResidentLegalSessionGateState();
}

class _ResidentLegalSessionGateState extends State<ResidentLegalSessionGate> {
  late final FirebaseAuth _auth = widget.auth ?? FirebaseAuth.instance;
  late final Stream<User?> _changes = _auth.authStateChanges();

  @override
  Widget build(BuildContext context) => StreamBuilder<User?>(
    stream: _changes,
    initialData: _auth.currentUser,
    builder: (context, snapshot) {
      final uid = snapshot.data?.uid;
      if (snapshot.hasError || uid == null || uid != _auth.currentUser?.uid) {
        return Scaffold(
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Please sign in again to continue.'),
                TextButton(
                  onPressed: () => Navigator.of(
                    context,
                  ).pushNamedAndRemoveUntil('/login', (_) => false),
                  child: const Text('Sign in'),
                ),
              ],
            ),
          ),
        );
      }
      return KeyedSubtree(key: ValueKey(uid), child: widget.child);
    },
  );
}
