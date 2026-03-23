import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'responsive_layout.dart';

class FeaturePageLayout extends StatelessWidget {
  const FeaturePageLayout({
    super.key,
    required this.title,
    required this.child,
    this.actions = const [],
    this.backgroundColor,
    this.expandBody = true,
    this.showTitleOnMobile = false,
    this.headerPadding = const EdgeInsets.fromLTRB(16, 16, 16, 12),
    this.bodySemanticLabel,
    this.disableComplexBodySemanticsOnWindows = true,
  });

  final String title;
  final Widget child;
  final List<Widget> actions;
  final Color? backgroundColor;
  final bool expandBody;
  final bool showTitleOnMobile;
  final EdgeInsetsGeometry headerPadding;
  final String? bodySemanticLabel;
  final bool disableComplexBodySemanticsOnWindows;

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveLayout.isMobile(context);
    final showTitle = showTitleOnMobile || !isMobile;
    final hasHeader = showTitle || actions.isNotEmpty;
    final shouldGuardBodySemantics =
        disableComplexBodySemanticsOnWindows &&
        !kIsWeb &&
        defaultTargetPlatform == TargetPlatform.windows;
    final body = shouldGuardBodySemantics
        ? Semantics(
            container: true,
            label: bodySemanticLabel ?? '$title 页面内容区域',
            child: ExcludeSemantics(child: child),
          )
        : child;

    return Material(
      color: backgroundColor ?? Theme.of(context).scaffoldBackgroundColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (hasHeader)
            Padding(
              padding: headerPadding,
              child: showTitle
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                        ),
                        if (actions.isNotEmpty) ...[
                          const SizedBox(width: 12),
                          Flexible(
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                alignment: WrapAlignment.end,
                                children: actions,
                              ),
                            ),
                          ),
                        ],
                      ],
                    )
                  : Align(
                      alignment: Alignment.centerRight,
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.end,
                        children: actions,
                      ),
                    ),
            ),
          if (expandBody) Expanded(child: body) else body,
        ],
      ),
    );
  }
}
