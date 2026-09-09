import 'package:flutter/material.dart';

/// A compact progress indicator that can be placed inline or inside a Center.
class LoadingIndicator extends StatelessWidget {
  const LoadingIndicator({super.key, this.size = 32, this.semanticsLabel})
    : assert(size > 0);

  final double size;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CircularProgressIndicator(
        strokeWidth: 3,
        color: Theme.of(context).colorScheme.primary,
        semanticsLabel: semanticsLabel,
      ),
    );
  }
}
