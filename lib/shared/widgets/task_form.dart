import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/app_typography.dart';
import '../models/action_outcome.dart';
import 'action_result_dialog.dart';

export '../models/action_outcome.dart';

Future<ActionOutcome?> showTaskForm(BuildContext context, TaskForm form) =>
    Navigator.of(context).push<ActionOutcome>(
      MaterialPageRoute(builder: (_) => form, fullscreenDialog: true),
    );

/// Shared task surface. Data remains in the mounted form until a confirmed
/// result, a durable local save, or an explicit discard.
class TaskForm extends StatefulWidget {
  const TaskForm({
    required this.title,
    required this.submitLabel,
    required this.builder,
    required this.onSubmit,
    this.contextLabel,
    this.controllers = const [],
    this.validate,
    this.shouldAdvance,
    this.advanceLabel,
    this.onAdvance,
    this.canGoBack,
    this.onStepBack,
    this.reviewBuilder,
    this.needsReview,
    this.canSubmit,
    this.onReconcile,
    this.initiallyDirty = false,
    super.key,
  });

  final String title;
  final String submitLabel;
  final String? contextLabel;
  final Widget Function(BuildContext, TaskFormState) builder;
  final Future<ActionOutcome> Function() onSubmit;
  final List<TextEditingController> controllers;
  final String? Function()? validate;
  final bool Function()? shouldAdvance;
  final String Function()? advanceLabel;
  final VoidCallback? onAdvance;
  final bool Function()? canGoBack;
  final ValueChanged<bool>? onStepBack;
  final Widget Function()? reviewBuilder;
  final bool Function()? needsReview;
  final bool Function()? canSubmit;
  final Future<ActionOutcome> Function()? onReconcile;
  final bool initiallyDirty;

  @override
  State<TaskForm> createState() => TaskFormState();
}

class TaskFormState extends State<TaskForm> {
  final _formKey = GlobalKey<FormState>();
  bool _dirty = false;
  bool _busy = false;
  bool _review = false;
  bool _allowPop = false;
  bool _uncertain = false;
  bool _takingLonger = false;
  String? _busyMessage;
  Timer? _slowTimer;
  String? _error;

  bool get isReviewing => _review;

  void changed() {
    if (mounted) {
      setState(() {
        _dirty = true;
        _review = false;
      });
    }
  }

  void showError(String message) {
    if (mounted) setState(() => _error = message);
  }

  void _startBusy(String message) {
    _slowTimer?.cancel();
    setState(() {
      _busy = true;
      _busyMessage = message;
      _takingLonger = false;
    });
    _slowTimer = Timer(const Duration(seconds: 10), () {
      if (mounted && _busy) setState(() => _takingLonger = true);
    });
  }

  void _stopBusy() {
    _slowTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _busyMessage = null;
      _takingLonger = false;
    });
  }

  @override
  void initState() {
    super.initState();
    _dirty = widget.initiallyDirty;
    for (final controller in widget.controllers) {
      controller.addListener(changed);
    }
  }

  @override
  void dispose() {
    _slowTimer?.cancel();
    for (final controller in widget.controllers) {
      controller.removeListener(changed);
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _leave([ActionOutcome? outcome, bool showResult = false]) async {
    if (_busy) return;
    if (outcome == null && _dirty) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Discard changes?'),
          content: const Text('Discard the changes you have not saved?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Keep editing')),
            TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Discard changes')),
          ],
        ),
      );
      if (discard != true || !mounted) return;
    }
    final rootNavigator = Navigator.of(context, rootNavigator: true);
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Navigator.of(context).pop(outcome);
        if (showResult && outcome != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!rootNavigator.mounted) return;
            final message = outcome.status == ActionStatus.savedLocally
                ? outcome.message ?? 'Saved on this phone. Waiting to sync.'
                : outcome.message ?? 'Changes saved successfully.';
            showActionResult(rootNavigator.context, message: message);
          });
        }
      }
    });
  }

  void _navigateBack() {
    if (_busy) return;
    final canGoBack = widget.canGoBack?.call() ?? false;
    if (_review) {
      setState(() {
        _review = false;
        _error = null;
      });
      widget.onStepBack?.call(true);
    } else if (canGoBack && widget.onStepBack != null) {
      setState(() => _error = null);
      widget.onStepBack!(false);
    } else {
      _leave();
    }
  }

  Future<void> _submit() async {
    if (_busy || _uncertain) return;
    if (widget.canSubmit?.call() == false) {
      showError(
          'Your access to this action has changed. Your input is still here.');
      return;
    }
    if (!_review) {
      final valid = _formKey.currentState!.validate();
      if (!valid) {
        // Follow the visual order, including fields below the fold.
        bool found = false;
        void focusInvalid(Element element) {
          if (found) return;
          if (element is StatefulElement && element.state is FormFieldState) {
            final state = element.state as FormFieldState;
            if (state.hasError) {
              found = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!element.mounted) return;
                Scrollable.ensureVisible(element,
                    duration: const Duration(milliseconds: 180));
                void focusInput(Element child) {
                  if (child.widget is EditableText) {
                    (child.widget as EditableText).focusNode.requestFocus();
                  } else {
                    child.visitChildren(focusInput);
                  }
                }

                element.visitChildren(focusInput);
              });
              return;
            }
          }
          element.visitChildren(focusInvalid);
        }

        (_formKey.currentContext! as Element).visitChildren(focusInvalid);
        return;
      }
      final error = widget.validate?.call();
      if (error != null) {
        showError(error);
        return;
      }
      if (widget.shouldAdvance?.call() == true) {
        FocusScope.of(context).unfocus();
        widget.onAdvance?.call();
        setState(() => _error = null);
        return;
      }
      if (widget.reviewBuilder != null && widget.needsReview?.call() != false) {
        FocusScope.of(context).unfocus();
        setState(() {
          _review = true;
          _error = null;
        });
        return;
      }
    }
    setState(() => _error = null);
    _startBusy('Saving ${widget.title.toLowerCase()}…');
    ActionOutcome result;
    try {
      result = await widget.onSubmit();
    } catch (_) {
      result = const ActionOutcome.unknown(
        'The result could not be confirmed. Check the record before submitting again.',
      );
    }
    if (!mounted) return;
    _stopBusy();
    if (result.canClose) {
      await _leave(result, true);
    } else {
      setState(() {
        _error = result.message;
        _uncertain = result.status == ActionStatus.uncertain;
        _review = result.status == ActionStatus.verifiedAbsent;
        if (_review) _dirty = true;
      });
      if (result.status == ActionStatus.verifiedAbsent &&
          widget.reviewBuilder == null) {
        setState(() => _review = false);
      }
      if (result.message != null) {
        await showActionResult(context,
            message: result.message!, success: false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return PopScope(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _navigateBack();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
              tooltip: 'Close',
              onPressed: _busy ? null : _leave,
              icon: const Icon(Icons.close)),
          title: Text(widget.title),
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Stack(children: [
                Column(children: [
                  Expanded(
                      child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Form(
                      key: _formKey,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (widget.contextLabel != null) ...[
                              Text(widget.contextLabel!,
                                  style: AppTypography.small),
                              const SizedBox(height: 8),
                            ],
                            if (_review) ...[
                              Text('Review before saving',
                                  style: AppTypography.sectionHeading),
                              const SizedBox(height: 16),
                              widget.reviewBuilder!(),
                            ],
                            // Keep field State and image selection alive while reviewing.
                            Offstage(
                                key: const ValueKey('task-fields'),
                                offstage: _review,
                                child: AbsorbPointer(
                                    absorbing: _busy,
                                    child: widget.builder(context, this))),
                          ]),
                    ),
                  )),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_error != null) ...[
                            Semantics(
                                liveRegion: true,
                                child: Text(_error!,
                                    style: TextStyle(color: colors.error))),
                            if (_uncertain && widget.onReconcile != null)
                              TextButton(
                                  onPressed: _busy
                                      ? null
                                      : () async {
                                          _startBusy(
                                              'Checking latest records…');
                                          try {
                                            final result =
                                                await widget.onReconcile!();
                                            if (!mounted) return;
                                            if (result.canClose) {
                                              _stopBusy();
                                              await _leave(result, true);
                                              return;
                                            }
                                            setState(() {
                                              _busy = false;
                                              _busyMessage = null;
                                              _takingLonger = false;
                                              _uncertain = result.status !=
                                                  ActionStatus.verifiedAbsent;
                                              _review = result.status ==
                                                      ActionStatus
                                                          .verifiedAbsent &&
                                                  widget.reviewBuilder != null;
                                              _dirty = _dirty ||
                                                  result.status ==
                                                      ActionStatus
                                                          .verifiedAbsent;
                                              _error = result.message;
                                            });
                                            if (result.message != null &&
                                                context.mounted) {
                                              await showActionResult(context,
                                                  message: result.message!,
                                                  success: result.status ==
                                                      ActionStatus
                                                          .verifiedAbsent);
                                            }
                                            return;
                                          } catch (_) {
                                            if (context.mounted) {
                                              setState(() => _error =
                                                  'Could not check the latest records. Your entry is still here. Try again when connected.');
                                              await showActionResult(context,
                                                  message: _error!,
                                                  success: false);
                                            }
                                          } finally {
                                            _stopBusy();
                                          }
                                        },
                                  child: const Text('Check latest records')),
                            const SizedBox(height: 12),
                          ],
                          SizedBox(
                            height: 52,
                            child: FilledButton(
                              onPressed: _busy || _uncertain ? null : _submit,
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  _busy
                                      ? 'Saving…'
                                      : widget.shouldAdvance?.call() == true
                                          ? widget.advanceLabel?.call() ??
                                              'Continue'
                                          : !_review &&
                                                  widget.reviewBuilder !=
                                                      null &&
                                                  widget.needsReview?.call() !=
                                                      false
                                              ? 'Review details'
                                              : widget.submitLabel,
                                  maxLines: 1,
                                  softWrap: false,
                                ),
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: _busy ? null : _navigateBack,
                            child: Text(_review
                                ? widget.onStepBack == null
                                    ? 'Edit details'
                                    : 'Back'
                                : (widget.canGoBack?.call() ?? false)
                                    ? 'Back'
                                    : 'Cancel'),
                          ),
                        ]),
                  ),
                ]),
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
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class TaskFields extends StatelessWidget {
  const TaskFields({required this.children, super.key});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i < children.length - 1) const SizedBox(height: 16),
          ]
        ],
      );
}

class ReviewDetails extends StatelessWidget {
  const ReviewDetails({required this.values, this.consequence, super.key});
  final Map<String, String> values;
  final String? consequence;
  @override
  Widget build(BuildContext context) => TaskFields(children: [
        for (final entry in values.entries)
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(entry.key, style: AppTypography.small),
            const SizedBox(height: 4),
            Text(entry.value, style: AppTypography.body),
          ]),
        if (consequence != null) Text(consequence!, style: AppTypography.body),
      ]);
}

Future<void> showReadOnlyPage(
        BuildContext context, String title, Widget child) =>
    Navigator.of(context).push<void>(MaterialPageRoute(
        builder: (_) => Scaffold(
              appBar: AppBar(title: Text(title)),
              body: SafeArea(
                  child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16), child: child)),
            )));
