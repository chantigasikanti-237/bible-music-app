import 'package:flutter/material.dart';

class AdaptiveBreakpoints {
  const AdaptiveBreakpoints._();

  static const double compact = 600;
  static const double largeScreen = 768;
  static const double medium = 840;
  static const double expanded = 1200;
}

enum AdaptiveWidthSize {
  compact,
  medium,
  expanded,
}

class AdaptiveLayoutInfo {
  const AdaptiveLayoutInfo({
    required this.constraints,
    required this.orientation,
  });

  final BoxConstraints constraints;
  final Orientation orientation;

  double get maxWidth => constraints.maxWidth;
  double get maxHeight => constraints.maxHeight;

  AdaptiveWidthSize get widthSize {
    if (maxWidth >= AdaptiveBreakpoints.expanded) {
      return AdaptiveWidthSize.expanded;
    }
    if (maxWidth >= AdaptiveBreakpoints.medium) {
      return AdaptiveWidthSize.medium;
    }
    return AdaptiveWidthSize.compact;
  }

  bool get isCompact => widthSize == AdaptiveWidthSize.compact;
  bool get isMedium => widthSize == AdaptiveWidthSize.medium;
  bool get isExpanded => widthSize == AdaptiveWidthSize.expanded;
  bool get isPhone => maxWidth < AdaptiveBreakpoints.largeScreen;
  bool get isLargeScreen => !isPhone;
  bool get isLandscape => orientation == Orientation.landscape;
  bool get isTablet => isLargeScreen;
  bool get useSideNavigation => isLargeScreen;
  bool get useTwoPane => isLandscape || isTablet;

  double get horizontalPadding {
    if (isExpanded) {
      return 32;
    }
    if (isMedium) {
      return 24;
    }
    return 16;
  }

  double get verticalPadding => isCompact ? 12 : 16;
  double get paneSpacing => useTwoPane ? (isTablet ? 24 : 16) : 12;

  int get splitPrimaryFlex => isExpanded ? 5 : 6;
  int get splitSecondaryFlex => isExpanded ? 4 : 5;

  int get gridColumns {
    if (isExpanded) {
      return 4;
    }
    if (isMedium || isLandscape) {
      return 2;
    }
    return 1;
  }

  EdgeInsets get pagePadding => EdgeInsets.fromLTRB(
        horizontalPadding,
        verticalPadding,
        horizontalPadding,
        24,
      );

  double get maxContentWidth => isExpanded ? 1440 : double.infinity;
}

typedef AdaptiveLayoutWidgetBuilder = Widget Function(
  BuildContext context,
  AdaptiveLayoutInfo layout,
);

class ConstraintLayout extends StatelessWidget {
  const ConstraintLayout({
    super.key,
    required this.builder,
  });

  final AdaptiveLayoutWidgetBuilder builder;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final mediaQuery = MediaQuery.of(context);
        return builder(
          context,
          AdaptiveLayoutInfo(
            constraints: constraints,
            orientation: mediaQuery.orientation,
          ),
        );
      },
    );
  }
}

class AdaptiveScaffold extends StatelessWidget {
  const AdaptiveScaffold({
    super.key,
    required this.bodyBuilder,
    this.appBar,
    this.backgroundColor,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.safeAreaTop,
    this.safeAreaBottom = true,
    this.constrainBody = true,
  });

  final PreferredSizeWidget? appBar;
  final Color? backgroundColor;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;
  final AdaptiveLayoutWidgetBuilder bodyBuilder;
  final bool? safeAreaTop;
  final bool safeAreaBottom;
  final bool constrainBody;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: appBar,
      bottomNavigationBar: bottomNavigationBar,
      floatingActionButton: floatingActionButton,
      body: SafeArea(
        top: safeAreaTop ?? appBar == null,
        bottom: safeAreaBottom,
        child: ConstraintLayout(
          builder: (BuildContext context, AdaptiveLayoutInfo layout) {
            final child = bodyBuilder(context, layout);
            if (!constrainBody || !layout.maxContentWidth.isFinite) {
              return child;
            }
            return Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: layout.maxContentWidth),
                child: child,
              ),
            );
          },
        ),
      ),
    );
  }
}
