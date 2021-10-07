import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_filereader/flutter_filereader.dart';
import 'package:http/http.dart' as http;
import 'package:random_string/random_string.dart';
import 'package:path_provider/path_provider.dart';

import 'globals.dart' as globals;

class PdfPage extends StatefulWidget {
  const PdfPage({Key key, this.filePath, this.fileName}): super(key: key);

  final String filePath;
  final String fileName;

  @override
  _PdfPageState createState() => _PdfPageState();
}

class _PdfPageState extends State<PdfPage> {
  //String filePath = "images/full_image.png";
  //Directory dir;

  @override
  void initState() {
    super.initState();
  }

  /*
  Future<bool>readFileURL() async {
    var uri = Uri.parse(widget.fileUrl);
    http.Response response = await http.get(uri, headers: {'Cookie': widget.cookie});
    if (response.statusCode != 200) {
      await globals.showPopupDialog(context: context, title: 'エラー', content: 'ファイルを読み込めませんでした', cancel: '閉じる');
      return false;
    }
    var fileName = randomAlpha(8);
    if (defaultTargetPlatform == TargetPlatform.android) {
      dir = await Directory((await getExternalStorageDirectory()).path+'/janusmobile/temp').create(recursive: true);
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      dir = await Directory((await getApplicationDocumentsDirectory()).path+'/janusmobile/temp').create(recursive: true);
    }
    var fp = "${dir.path}/$fileName";
    File file = File(fp);
    if (await File(fp).exists()) {
      await file.delete();
    }
    await file.create(recursive: true);
    await file.writeAsBytes(response.bodyBytes.buffer.asUint8List(), flush: true);
    setState(() {
      filePath = fp;
    });
    return true;
  }
   */

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.fileName),
      ),
      body: FileReaderView(
        filePath: widget.filePath,
        loadingWidget: const CircularProgressIndicator(),
        unSupportFileWidget: AlertDialog(
          title: Text('エラー'),
          content: Text('未対応のファイル形式です'),
          actions: <Widget>[
            TextButton(
              child: Text('閉じる'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    if (File(widget.filePath).existsSync()) {
      File(widget.filePath).deleteSync(recursive: true);
    }
    //if (Directory(dir.path).existsSync())
    //  dir.deleteSync(recursive: true);
    super.dispose();
  }
}
