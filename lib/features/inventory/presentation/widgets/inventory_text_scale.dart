import 'package:flutter/material.dart';

class InventoryTextScale extends StatelessWidget {
  const InventoryTextScale({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    return MediaQuery(
      data: mediaQuery.copyWith(
        textScaler: _InventoryTextScaler(mediaQuery.textScaler),
      ),
      child: child,
    );
  }
}

class _InventoryTextScaler extends TextScaler {
  const _InventoryTextScaler(this.parent);

  final TextScaler parent;

  @override
  double scale(double fontSize) => parent.scale(fontSize * 1.1);

  // TextScaler retains this member for backward compatibility.
  @override
  double get textScaleFactor =>
      parent.textScaleFactor * 1.1; // ignore: deprecated_member_use

  @override
  bool operator ==(Object other) =>
      other is _InventoryTextScaler && other.parent == parent;

  @override
  int get hashCode => Object.hash(parent, 1.1);
}
