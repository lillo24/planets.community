import 'package:flutter/material.dart';

/// The heading scrolls with loaded entries at large text/keyboard sizes.
/// Each feature supplies its own typed row and deliberate destination.
class PublicMapEntryChooser extends StatelessWidget {
  const PublicMapEntryChooser({
    required this.count,
    required this.heading,
    required this.itemBuilder,
    this.footer,
    super.key,
  });
  final int count;
  final String heading;
  final IndexedWidgetBuilder itemBuilder;
  final Widget? footer;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SizedBox(
      height:
          (MediaQuery.sizeOf(context).height -
              MediaQuery.viewInsetsOf(context).bottom) *
          0.65,
      child: Column(
        children: [
          Expanded(
            child: ListView.builder(
              key: const Key('map-cluster-choices'),
              itemCount: count + 1,
              itemBuilder: (context, index) => index == 0
                  ? Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        heading,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    )
                  : itemBuilder(context, index - 1),
            ),
          ),
          ?footer,
        ],
      ),
    ),
  );
}
