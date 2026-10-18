import 'dart:async';

import 'package:flutter/material.dart';
import '../../core/theme/app_typography.dart';
import '../models/action_outcome.dart';
import 'action_result_dialog.dart';

Future<ActionOutcome?> showActionConfirmation(
  BuildContext context, {
  required String title,
  required String message,
  required String actionLabel,
  required Future<ActionOutcome> Function() onConfirm,
  Future<ActionOutcome> Function()? onReconcile,
  bool destructive = false,
}) =>
    showDialog<ActionOutcome>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ActionConfirmation(
          title: title,
          message: message,
          actionLabel: actionLabel,
          onConfirm: onConfirm,
          onReconcile: onReconcile,
          destructive: destructive),
    );

class _ActionConfirmation extends StatefulWidget {
  const _ActionConfirmation(
      {required this.title,
      required this.message,
      required this.actionLabel,
      required this.onConfirm,
      required this.destructive,
      this.onReconcile});
  final String title, message, actionLabel;
  final bool destructive;
  final Future<ActionOutcome> Function() onConfirm;
  final Future<ActionOutcome> Function()? onReconcile;
  @override
  State<_ActionConfirmation> createState() => _ActionConfirmationState();
}

class _ActionConfirmationState extends State<_ActionConfirmation> {
  bool _busy = false;
  bool _takingLonger = false;
  String? _busyMessage;
  Timer? _slowTimer;
  bool _uncertain = false;
  String? _error;

  void _startBusy(String message) {
    setState(() {
      _busy = true;
      _busyMessage = message;
      _takingLonger = false;
    });
    _slowTimer?.cancel();
    _slowTimer = Timer(const Duration(seconds: 10), () {
      if (mounted && _busy) setState(() => _takingLonger = true);
    });
  }

  @override
  void dispose() {
    _slowTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: !_busy,
        child: Stack(
          children: [
            AlertDialog(
              title: Text(widget.title),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.message),
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          _error!,
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error),
                        ),
                      ),
                      if (_uncertain && widget.onReconcile != null)
                        TextButton(
                          onPressed: _busy
                              ? null
                              : () async {
                                  _startBusy('Checking latest records…');
                                  ActionOutcome result;
                                  try {
                                    result = await widget.onReconcile!();
                                  } catch (_) {
                                    result = const ActionOutcome.unknown(
                                        'Could not check the latest record. Try again when connected.');
                                  }
                                  if (!context.mounted) return;
                                  _slowTimer?.cancel();
                                  setState(() {
                                    _busy = false;
                                    _busyMessage = null;
                                    _uncertain =
                                        result.status == ActionStatus.uncertain;
                                    _error = result.message;
                                  });
                                  if (result.canClose) {
                                    final rootNavigator = Navigator.of(context,
                                        rootNavigator: true);
                                    WidgetsBinding.instance
                                        .addPostFrameCallback((_) {
                                      if (!mounted) return;
                                      Navigator.pop(context, result);
                                      WidgetsBinding.instance
                                          .addPostFrameCallback((_) {
                                        if (!rootNavigator.mounted) return;
                                        showActionResult(
                                          rootNavigator.context,
                                          message: result.message ??
                                              'Existing transaction confirmed; no duplicate was sent.',
                                        );
                                      });
                                    });
                                  }
                                },
                          child: const Text('Check latest records'),
                        ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: _busy ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  style: widget.destructive
                      ? FilledButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.error,
                          foregroundColor:
                              Theme.of(context).colorScheme.onError,
                        )
                      : null,
                  onPressed: _busy || _uncertain
                      ? null
                      : () async {
                          _startBusy(widget.actionLabel);
                          setState(() => _error = null);
                          ActionOutcome result;
                          try {
                            result = await widget.onConfirm();
                          } catch (_) {
                            result = const ActionOutcome.unknown(
                                'The result could not be confirmed. Check the record before trying again.');
                          }
                          if (!context.mounted) return;
                          _slowTimer?.cancel();
                          setState(() {
                            _busy = false;
                            _busyMessage = null;
                          });
                          if (result.canClose) {
                            final rootNavigator =
                                Navigator.of(context, rootNavigator: true);
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (!mounted) return;
                              Navigator.pop(context, result);
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (!rootNavigator.mounted) return;
                                final message = result.status ==
                                        ActionStatus.savedLocally
                                    ? result.message ??
                                        'Saved on this phone. Waiting to sync.'
                                    : result.message ??
                                        '${widget.actionLabel} completed successfully.';
                                showActionResult(rootNavigator.context,
                                    message: message);
                              });
                            });
                          } else {
                            setState(() {
                              _error = result.message;
                              _uncertain =
                                  result.status == ActionStatus.uncertain;
                            });
                            if (result.message != null && context.mounted) {
                              await showActionResult(context,
                                  message: result.message!, success: false);
                            }
                          }
                        },
                  child: Text(_busy ? 'Saving…' : widget.actionLabel),
                ),
              ],
            ),
            if (_busy)
              Positioned.fill(
                child: ColoredBox(
                  color: Colors.black.withValues(alpha: 0.28),
                  child: Center(
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CircularProgressIndicator(),
                            const SizedBox(height: 14),
                            Semantics(
                              liveRegion: true,
                              label: _takingLonger
                                  ? 'This is taking longer than usual. Please wait.'
                                  : _busyMessage ?? 'Working…',
                              child: Text(
                                _takingLonger
                                    ? 'This is taking longer than usual. Please wait.'
                                    : _busyMessage ?? 'Working…',
                                textAlign: TextAlign.center,
                                style: AppTypography.body,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
}
