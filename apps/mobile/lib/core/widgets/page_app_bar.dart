import 'package:flutter/material.dart';

/// An arrow-free page header with a textual, guarded exit.
///
/// Expanded text puts actions below the title so cancellation never overflows.
/// [preserveTitleSize] keeps content titles at their normal font size (callers
/// supply wrapping/ellipsis) and moves actions below them on narrow windows.
PreferredSizeWidget pageAppBar(
  BuildContext context, {
  Widget? title,
  List<Widget>? actions,
  VoidCallback? onClose,
  String? closeLabel,
  Key closeKey = const Key('page-close'),
  bool automaticallyImplyClose = true,
  bool preserveTitleSize = false,
}) {
  final implied =
      automaticallyImplyClose &&
      !PageAppBarScope.suppressesClose(context) &&
      (ModalRoute.of(context)?.canPop ?? false);
  final buttons = <Widget>[
    ...?actions,
    if (onClose != null || implied)
      TextButton(
        key: closeKey,
        // maybePop honors PopScope and the router's existing onExit guard.
        // Explicit flow callbacks retain cancellation/return semantics.
        onPressed: onClose ?? () => Navigator.of(context).maybePop(),
        child: Text(
          closeLabel ?? MaterialLocalizations.of(context).closeButtonTooltip,
        ),
      ),
  ];
  final largeText = MediaQuery.textScalerOf(context).scale(14) > 20;
  final expanded =
      buttons.length > 1 &&
      buttons.any((button) => button is ButtonStyleButton) &&
      MediaQuery.sizeOf(context).width < 480 &&
      (preserveTitleSize || largeText);
  final actionHeight = preserveTitleSize && !largeText ? 56.0 : 112.0;
  return AppBar(
    automaticallyImplyLeading: false,
    // Composite titles (avatars/Expanded rows) need bounded toolbar constraints.
    title: title is Text && !preserveTitleSize
        ? FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: title,
          )
        : title,
    actions: expanded ? null : buttons,
    bottom: expanded
        ? PreferredSize(
            preferredSize: Size.fromHeight(actionHeight),
            child: SizedBox(
              height: actionHeight,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: Wrap(
                    alignment: WrapAlignment.end,
                    runSpacing: 4,
                    children: buttons,
                  ),
                ),
              ),
            ),
          )
        : null,
  );
}

/// Embedded tutorial surfaces do not own the tutorial route's Close action.
class PageAppBarScope extends InheritedWidget {
  const PageAppBarScope({required super.child, super.key});

  static bool suppressesClose(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PageAppBarScope>() != null;

  @override
  bool updateShouldNotify(PageAppBarScope oldWidget) => false;
}
