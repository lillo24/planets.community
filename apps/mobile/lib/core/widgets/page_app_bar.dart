import 'package:flutter/material.dart';

/// Arrow-free page header. Pushed pages retain a textual, guarded exit.
/// Expanded text puts actions below the title so cancellation never overflows.
PreferredSizeWidget pageAppBar(
  BuildContext context, {
  Widget? title,
  List<Widget>? actions,
  VoidCallback? onClose,
  String? closeLabel,
  Key closeKey = const Key('page-close'),
  bool automaticallyImplyClose = true,
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
  final expanded =
      buttons.length > 1 &&
      buttons.any((button) => button is ButtonStyleButton) &&
      MediaQuery.sizeOf(context).width < 480 &&
      MediaQuery.textScalerOf(context).scale(14) > 20;
  return AppBar(
    automaticallyImplyLeading: false,
    // Composite titles (avatars/Expanded rows) need bounded toolbar constraints.
    title: title is Text
        ? FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: title,
          )
        : title,
    actions: expanded ? null : buttons,
    bottom: expanded
        ? PreferredSize(
            preferredSize: const Size.fromHeight(112),
            child: SizedBox(
              height: 112,
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
