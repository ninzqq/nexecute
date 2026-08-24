import 'package:flutter/material.dart';

class SubmitButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool isEditing;
  final bool isLoading;

  const SubmitButton({
    super.key,
    required this.onPressed,
    required this.isEditing,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        child:
            isLoading
                ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                : isEditing
                ? const Text('Update')
                : const Text('Save'),
      ),
    );
  }
}
