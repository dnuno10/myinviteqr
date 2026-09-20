import 'package:flutter/material.dart';

bool isMobile(BuildContext c) => MediaQuery.sizeOf(c).width < 720;
bool isCompact(BuildContext c) => MediaQuery.sizeOf(c).width < 1100;
double pagePad(BuildContext c) => isMobile(c) ? 16 : 32;

/// Marks a child of [AdaptiveRow] that keeps a fixed width on wide layouts.
class Fixed extends StatelessWidget {
  final double width;
  final Widget child;
  const Fixed(this.width, this.child, {super.key});
  @override
  Widget build(BuildContext context) => SizedBox(width: width, child: child);
}

/// A row on wide screens that stacks vertically below [breakpoint]. No overflow at any width.
class AdaptiveRow extends StatelessWidget {
  final List<Widget> children;
  final List<int>? flex;
  final double gap;
  final double breakpoint;
  final CrossAxisAlignment crossAxisAlignment;
  const AdaptiveRow({
    super.key,
    required this.children,
    this.flex,
    this.gap = 18,
    this.breakpoint = 900,
    this.crossAxisAlignment = CrossAxisAlignment.start,
  });

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      if (c.maxWidth < breakpoint) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (int i = 0; i < children.length; i++) ...[
              if (i > 0) SizedBox(height: gap),
              children[i] is Fixed ? (children[i] as Fixed).child : children[i],
            ],
          ],
        );
      }
      return Row(
        crossAxisAlignment: crossAxisAlignment,
        children: [
          for (int i = 0; i < children.length; i++) ...[
            if (i > 0) SizedBox(width: gap),
            if (children[i] is Fixed)
              children[i]
            else
              Expanded(flex: flex?[i] ?? 1, child: children[i]),
          ],
        ],
      );
    },
  );
}

/// Scrollable, centered page body with responsive side padding.
class PageBody extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  const PageBody({
    super.key,
    required this.child,
    this.maxWidth = double.infinity,
  });
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    child: Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            pagePad(context),
            isMobile(context) ? 18 : 28,
            pagePad(context),
            32,
          ),
          child: child,
        ),
      ),
    ),
  );
}

/// Lays children in a grid whose column count adapts to the available width.
class AutoGrid extends StatelessWidget {
  final List<Widget> children;
  final double minTile;
  final double gap;
  const AutoGrid({
    super.key,
    required this.children,
    this.minTile = 300,
    this.gap = 16,
  });
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final cols = ((c.maxWidth + gap) / (minTile + gap)).floor().clamp(1, 6);
      final w = (c.maxWidth - gap * (cols - 1)) / cols;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [for (final ch in children) SizedBox(width: w, child: ch)],
      );
    },
  );
}
