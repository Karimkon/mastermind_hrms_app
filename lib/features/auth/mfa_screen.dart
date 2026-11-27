import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/providers/auth_provider.dart';

/// The six-digit code, entered or pasted.
///
/// Six boxes of one character each are the familiar shape, but each box was
/// capped at `maxLength: 1`, and the cap is applied to a paste as well as to
/// a keystroke: copying 482913 out of the authenticator and pasting it put a
/// 4 in the first box and threw the rest away. Everybody was retyping a code
/// they already had in the clipboard, against a thirty-second expiry.
///
/// A paste is now spread across the boxes from wherever it lands, so one
/// paste fills the row and submits, and typing behaves exactly as it did.
class MfaScreen extends ConsumerStatefulWidget {
  final String mfaToken;
  const MfaScreen({super.key, required this.mfaToken});

  @override
  ConsumerState<MfaScreen> createState() => _MfaScreenState();
}

class _MfaScreenState extends ConsumerState<MfaScreen> {
  final List<TextEditingController> _controllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  bool _loading = false;
  String? _error;

  String get _code => _controllers.map((c) => c.text).join();

  /// One box changed. The text may be a single typed digit, an empty box
  /// after a backspace, or an entire pasted code.
  void _onChanged(int i, String value) {
    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');

    if (digits.length > 1) {
      _spread(digits, from: i);
      return;
    }

    // A single character, which is all a box may hold. Anything else the
    // field is carrying (a stale digit a paste of one character replaced) is
    // normalised away here rather than left to be read back by _code.
    if (_controllers[i].text != digits) {
      _set(_controllers[i], digits);
    }

    if (digits.isNotEmpty && i < 5) {
      _focusNodes[i + 1].requestFocus();
    } else if (digits.isEmpty && i > 0) {
      _focusNodes[i - 1].requestFocus();
    }

    _verifyWhenComplete();
  }

  /// Lay a run of digits across the boxes, starting at [from].
  ///
  /// A paste into the middle of a half-typed code fills from that box on,
  /// which is what somebody correcting the tail of a code expects; a paste
  /// of all six into the first box fills the row.
  void _spread(String digits, {required int from}) {
    for (var n = 0; n < digits.length && from + n < 6; n++) {
      _set(_controllers[from + n], digits[n]);
    }

    final landed = (from + digits.length).clamp(0, 6);
    if (landed >= 6) {
      FocusScope.of(context).unfocus();
    } else {
      _focusNodes[landed].requestFocus();
    }

    setState(() {});
    _verifyWhenComplete();
  }

  /// Replace a box's contents and leave the caret after them, so a second
  /// keystroke does not land in front of the digit already there.
  void _set(TextEditingController controller, String text) {
    controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  void _verifyWhenComplete() {
    if (_code.length == 6 && !_loading) _verify();
  }

  Future<void> _verify() async {
    if (_code.length != 6) return;
    setState(() { _loading = true; _error = null; });
    try {
      await ref.read(authProvider.notifier).verifyMfa(widget.mfaToken, _code);
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
      for (final c in _controllers) {
        c.clear();
      }
      _focusNodes[0].requestFocus();
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final tight = width < 420;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Center(
          // A fixed 420pt card is wider than a 360pt handset, and a card that
          // cannot fit takes its contents off the edge of the screen with it.
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Container(
                padding: EdgeInsets.all(tight ? 24 : 40),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 40)],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: AppColors.infoLight,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.shield_rounded, color: AppColors.primary, size: 32),
                    ),
                    const SizedBox(height: 20),
                    const Text('Two-Factor Authentication', textAlign: TextAlign.center, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                    const SizedBox(height: 8),
                    const Text(
                      'Enter or paste the 6-digit code from\nyour authenticator app',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.5),
                    ),
                    const SizedBox(height: 32),

                    if (_error != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.errorLight,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, color: AppColors.error, size: 16),
                            const SizedBox(width: 8),
                            Expanded(child: Text(_error!, style: const TextStyle(color: AppColors.error, fontSize: 13))),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // 6 digit boxes
                    AutofillGroup(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(6, (i) {
                          return Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(right: i < 5 ? 8 : 0),
                              child: SizedBox(
                                height: 56,
                                child: TextField(
                                  controller: _controllers[i],
                                  focusNode: _focusNodes[i],
                                  textAlign: TextAlign.center,
                                  keyboardType: TextInputType.number,
                                  autofillHints: i == 0 ? const [AutofillHints.oneTimeCode] : null,
                                  // No maxLength: the cap is what swallowed a
                                  // pasted code. _onChanged keeps each box to
                                  // one digit and spreads the rest.
                                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                                  decoration: InputDecoration(
                                    counterText: '',
                                    contentPadding: EdgeInsets.zero,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: const BorderSide(color: AppColors.inputBorder),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: const BorderSide(color: AppColors.primary, width: 2),
                                    ),
                                  ),
                                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                  onChanged: (v) => _onChanged(i, v),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                    const SizedBox(height: 12),

                    TextButton.icon(
                      onPressed: _loading ? null : _pasteFromClipboard,
                      icon: const Icon(Icons.content_paste_rounded, size: 16),
                      label: const Text('Paste code', style: TextStyle(fontSize: 13)),
                    ),
                    const SizedBox(height: 16),

                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _verify,
                        child: _loading
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text('Verify Code', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
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

  /// Takes the code straight out of the clipboard, for the long-press menu
  /// that six one-character boxes make awkward to reach.
  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final digits = (data?.text ?? '').replaceAll(RegExp(r'[^0-9]'), '');

    if (digits.isEmpty) {
      if (mounted) setState(() => _error = 'There is no code in the clipboard to paste.');
      return;
    }

    for (final c in _controllers) {
      c.clear();
    }
    setState(() => _error = null);
    _spread(digits, from: 0);
  }
}
