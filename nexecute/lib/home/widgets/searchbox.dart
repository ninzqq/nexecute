import 'package:flutter/material.dart';

class SearchBox extends StatelessWidget {
  final ValueChanged<String>? onChanged;
  final String hintText;
  final TextEditingController? controller;

  const SearchBox({
    super.key,
    this.onChanged,
    this.hintText = 'Filter...',
    this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(5.0),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hintText,
          prefixIcon: Icon(Icons.search),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.0)),
          contentPadding: EdgeInsets.symmetric(vertical: 0, horizontal: 16),
        ),
      ),
    );
  }
}
