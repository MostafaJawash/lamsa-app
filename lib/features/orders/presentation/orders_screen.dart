import 'package:flutter/material.dart';
import 'package:lamsa_app/core/strings.dart';
import 'package:lamsa_app/core/widgets/placeholder_screen.dart';

class OrdersScreen extends StatelessWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const PlaceholderScreen(title: Strings.orders);
}
