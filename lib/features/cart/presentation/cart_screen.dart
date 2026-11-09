import 'package:flutter/material.dart';
import 'package:lamsa_app/core/strings.dart';
import 'package:lamsa_app/core/widgets/placeholder_screen.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const PlaceholderScreen(title: Strings.cart);
}
