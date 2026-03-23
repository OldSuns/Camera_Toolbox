import 'package:flutter/material.dart';

/// Exposes a stable summary node while hiding a complex child subtree from
/// platform accessibility trees.
class SemanticSummaryRegion extends StatelessWidget {
  const SemanticSummaryRegion({
    super.key,
    required this.label,
    required this.child,
  });

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: label,
      child: ExcludeSemantics(child: child),
    );
  }
}
