import 'package:flutter/material.dart';

class CreateReviewScreen extends StatelessWidget {
  final Function(int)? onReviewPosted;
  const CreateReviewScreen({Key? key, this.onReviewPosted}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text('CreateReviewScreen placeholder', style: TextStyle(color: Colors.white)),
    );
  }
}
