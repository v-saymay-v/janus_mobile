import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
//import 'package:flutter_qr_reader/qrcode_reader_view.dart';
import 'qrcode_reader_view.dart';

import 'globals.dart' as globals;

class ScanViewDemo extends StatefulWidget {
  ScanViewDemo({Key key, this.onScanCb}) : super(key: key);
  final Future Function(String) onScanCb;

  @override
  _ScanViewDemoState createState() => new _ScanViewDemoState();
}

class _ScanViewDemoState extends State<ScanViewDemo> {
  GlobalKey<QrcodeReaderViewState> _key = GlobalKey();

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return new Scaffold(
      body: QrcodeReaderView(
        key: _key,
        onScan: onScan,
        headerWidget: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0.0,
        ),
      ),
    );
  }

  Future onScan(String data) async {
    widget.onScanCb(data);
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    super.dispose();
  }
}
