import 'package:flutter/material.dart';
import 'package:lamsa_app/core/strings.dart';
import 'package:lamsa_app/core/widgets/placeholder_screen.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const PlaceholderScreen(title: Strings.favorites);
}
