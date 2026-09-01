// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:flutter/material.dart';

// class LoginPage extends StatefulWidget {
//   const LoginPage({super.key, this.error, required this.onAuthenticated});
//   final String? error;
//   final Future<void> Function() onAuthenticated;
//   @override
//   State<LoginPage> createState() => _LoginPageState();
// }

// class _LoginPageState extends State<LoginPage> {
//   final _phone = TextEditingController();
//   final _code = TextEditingController();
//   ConfirmationResult? _confirmation;
//   String? _message;
//   bool _busy = false;

//   Future<void> _send() async {
//     setState(() {
//       _busy = true;
//       _message = null;
//     });
//     try {
//       _confirmation = await FirebaseAuth.instance.signInWithPhoneNumber(
//         _phone.text.trim(),
//       );
//       if (mounted) setState(() => _message = 'Verification code sent.');
//     } on FirebaseAuthException catch (error) {
//       if (mounted) {
//         setState(
//           () => _message = error.message ?? 'Phone verification failed.',
//         );
//       }
//     } finally {
//       if (mounted) setState(() => _busy = false);
//     }
//   }

//   Future<void> _verify() async {
//     if (_confirmation == null) return;
//     setState(() => _busy = true);
//     try {
//       await _confirmation!.confirm(_code.text.trim());
//       await widget.onAuthenticated();
//     } on FirebaseAuthException catch (error) {
//       if (mounted) {
//         setState(
//           () => _message = error.message ?? 'Invalid verification code.',
//         );
//       }
//     } finally {
//       if (mounted) setState(() => _busy = false);
//     }
//   }

//   @override
//   Widget build(BuildContext context) => Scaffold(
//     body: Center(
//       child: SingleChildScrollView(
//         padding: const EdgeInsets.all(24),
//         child: ConstrainedBox(
//           constraints: const BoxConstraints(maxWidth: 440),
//           child: Card(
//             child: Padding(
//               padding: const EdgeInsets.all(32),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.stretch,
//                 children: [
//                   Text(
//                     'Hominode',
//                     style: Theme.of(context).textTheme.headlineLarge?.copyWith(
//                       fontWeight: FontWeight.bold,
//                     ),
//                   ),
//                   const SizedBox(height: 8),
//                   const Text('Sign in with your registered phone number.'),
//                   const SizedBox(height: 24),
//                   TextField(
//                     controller: _phone,
//                     enabled: _confirmation == null,
//                     decoration: const InputDecoration(
//                       labelText: 'Phone number',
//                       hintText: '+919876543210',
//                       border: OutlineInputBorder(),
//                     ),
//                   ),
//                   if (_confirmation != null) ...[
//                     const SizedBox(height: 16),
//                     TextField(
//                       controller: _code,
//                       keyboardType: TextInputType.number,
//                       decoration: const InputDecoration(
//                         labelText: 'Verification code',
//                         border: OutlineInputBorder(),
//                       ),
//                     ),
//                   ],
//                   const SizedBox(height: 20),
//                   FilledButton(
//                     onPressed: _busy
//                         ? null
//                         : (_confirmation == null ? _send : _verify),
//                     child: Text(
//                       _confirmation == null
//                           ? 'Send code'
//                           : 'Verify and continue',
//                     ),
//                   ),
//                   if (widget.error != null || _message != null)
//                     Padding(
//                       padding: const EdgeInsets.only(top: 16),
//                       child: Text(
//                         _message ?? widget.error!,
//                         style: TextStyle(
//                           color: _message == 'Verification code sent.'
//                               ? Colors.green
//                               : Theme.of(context).colorScheme.error,
//                         ),
//                       ),
//                     ),
//                 ],
//               ),
//             ),
//           ),
//         ),
//       ),
//     ),
//   );
// }
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, this.error, required this.onAuthenticated});

  final String? error;
  final Future<void> Function() onAuthenticated;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _phone = TextEditingController();
  final _code = TextEditingController();

  ConfirmationResult? _confirmation;

  String? _message;
  bool _busy = false;

  @override
  void dispose() {
    _phone.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final phone = _phone.text.trim();

    if (phone.isEmpty) {
      setState(() {
        _message = 'Enter your registered phone number.';
      });
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _busy = true;
      _message = null;
    });

    try {
      final auth = FirebaseAuth.instance;

      if (kDebugMode) {
        await auth.setSettings(appVerificationDisabledForTesting: true);
      }

      final confirmation = await auth.signInWithPhoneNumber(phone);

      if (!mounted) return;

      setState(() {
        _confirmation = confirmation;
        _message = 'Verification code sent.';
      });
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;

      setState(() {
        _message = error.message ?? 'Phone verification failed.';
      });

      debugPrint('[WebPhoneAuth] code=${error.code} message=${error.message}');
    } catch (error, stackTrace) {
      if (!mounted) return;

      setState(() {
        _message = 'Unable to start phone verification.';
      });

      debugPrint('Phone verification error: $error');
      debugPrintStack(stackTrace: stackTrace);
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _verify() async {
    final confirmation = _confirmation;
    if (confirmation == null) return;

    final code = _code.text.trim();

    if (code.isEmpty) {
      setState(() {
        _message = 'Enter the verification code.';
      });
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _busy = true;
      _message = null;
    });

    try {
      await confirmation.confirm(code);

      if (!mounted) return;

      await widget.onAuthenticated();
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;

      setState(() {
        _message = error.message ?? 'Invalid verification code.';
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _message = 'Unable to complete sign in.';
      });

      debugPrint('OTP confirmation error: $error');
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  void _changeNumber() {
    setState(() {
      _confirmation = null;
      _code.clear();
      _message = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final codeSent = _confirmation != null;

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Hominode',
                      style: Theme.of(context).textTheme.headlineLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),

                    const Text('Sign in with your registered phone number.'),

                    const SizedBox(height: 24),

                    TextField(
                      controller: _phone,
                      enabled: !codeSent && !_busy,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.done,
                      decoration: const InputDecoration(
                        labelText: 'Phone number',
                        hintText: '+639XXXXXXXXX',
                        border: OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 16),

                    /*
                     * Firebase Web renders the explicit
                     * reCAPTCHA widget into this DOM ID.
                     *
                     * Add this element to web/index.html:
                     *
                     * <div id="recaptcha-container"></div>
                     */
                    if (codeSent) ...[
                      TextField(
                        controller: _code,
                        enabled: !_busy,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) {
                          if (!_busy) {
                            _verify();
                          }
                        },
                        decoration: const InputDecoration(
                          labelText: 'Verification code',
                          border: OutlineInputBorder(),
                        ),
                      ),

                      const SizedBox(height: 12),

                      TextButton(
                        onPressed: _busy ? null : _changeNumber,
                        child: const Text('Use another phone number'),
                      ),
                    ],

                    const SizedBox(height: 20),

                    FilledButton(
                      onPressed: _busy
                          ? null
                          : codeSent
                          ? _verify
                          : _send,
                      child: _busy
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              codeSent ? 'Verify and continue' : 'Send code',
                            ),
                    ),

                    if (widget.error != null || _message != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Text(
                          _message ?? widget.error!,
                          style: TextStyle(
                            color: _message == 'Verification code sent.'
                                ? Colors.green
                                : Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
