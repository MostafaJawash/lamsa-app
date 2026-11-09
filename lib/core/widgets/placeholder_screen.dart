import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lamsa_app/core/strings.dart';
import 'package:lamsa_app/core/theme/spacing.dart';

/// Every not-yet-built screen: just its Arabic title (plus optional extras).
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({required this.title, this.children = const [], super.key});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final canPop = context.canPop();
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        automaticallyImplyLeading: false,
        leading: canPop
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: Strings.back,
                onPressed: context.pop,
              )
            : null,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(Spacing.pageGutter),
          children: [
            const SizedBox(height: Spacing.xl),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            ...children,
          ],
        ),
      ),
    );
  }
}
