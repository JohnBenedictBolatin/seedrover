import 'package:flutter/material.dart';
import '../models/action_outcome.dart';

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
  bool _uncertain = false;
  String? _error;
  @override
  Widget build(BuildContext context) => PopScope(
        canPop: !_busy,
        child: AlertDialog(
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
                      child: Text(_error!,
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error))),
                  if (_uncertain && widget.onReconcile != null)
                    TextButton(
                        onPressed: _busy
                            ? null
                            : () async {
                                setState(() => _busy = true);
                                ActionOutcome result;
                                try {
                                  result = await widget.onReconcile!();
                                } catch (_) {
                                  result = const ActionOutcome.unknown(
                                      'Could not check the latest record. Try again when connected.');
                                }
                                if (!mounted) return;
                                setState(() {
                                  _busy = false;
                                  _uncertain =
                                      result.status == ActionStatus.uncertain;
                                  _error = result.message;
                                });
                                if (result.canClose)
                                  WidgetsBinding.instance
                                      .addPostFrameCallback((_) {
                                    if (mounted) Navigator.pop(context, result);
                                  });
                              },
                        child: const Text('Check latest records')),
                ],
              ])),
          actions: [
            TextButton(
                onPressed: _busy ? null : () => Navigator.pop(context),
                child: const Text('Cancel')),
            FilledButton(
              style: widget.destructive
                  ? FilledButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.error,
                      foregroundColor: Theme.of(context).colorScheme.onError)
                  : null,
              onPressed: _busy || _uncertain
                  ? null
                  : () async {
                      setState(() {
                        _busy = true;
                        _error = null;
                      });
                      ActionOutcome result;
                      try {
                        result = await widget.onConfirm();
                      } catch (_) {
                        result = const ActionOutcome.unknown(
                            'The result could not be confirmed. Check the record before trying again.');
                      }
                      if (!mounted) return;
                      setState(() => _busy = false);
                      if (result.canClose) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) Navigator.pop(context, result);
                        });
                      } else {
                        setState(() {
                          _error = result.message;
                          _uncertain = result.status == ActionStatus.uncertain;
                        });
                      }
                    },
              child: Text(_busy ? 'Saving…' : widget.actionLabel),
            ),
          ],
        ),
      );
}
