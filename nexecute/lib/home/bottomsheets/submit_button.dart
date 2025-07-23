import 'package:flutter/material.dart';

class SubmitButton extends StatelessWidget {
  final VoidCallback onPressed;
  final bool isEditing;

  const SubmitButton({
    super.key,
    required this.onPressed,
    required this.isEditing,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        child: isEditing ? const Text('Update') : const Text('Save'),
      ),
    );
  }
}