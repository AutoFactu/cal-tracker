import 'package:flutter/material.dart';

class ContentFrame extends StatelessWidget {
  const ContentFrame({super.key, required this.title, required this.child, this.actions});

  final String title;
  final Widget child;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                title: Text(title),
                actions: actions,
              ),
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverToBoxAdapter(child: child),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
