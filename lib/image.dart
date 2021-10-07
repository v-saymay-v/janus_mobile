import 'package:flutter/material.dart';

class ImagePage extends StatefulWidget {
  const ImagePage({Key key, this.imageName, this.imageUrl, this.cookie}): super(key: key);

  final String imageUrl;
  final String cookie;
  final String imageName;

  @override
  _ImagePageState createState() => _ImagePageState();
}

class _ImagePageState extends State<ImagePage> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Image.network(
          widget.imageUrl, headers: {"Cookie": widget.cookie}, fit: BoxFit.fitWidth,),
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}
