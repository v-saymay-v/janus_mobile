import 'dart:io';
import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
//import 'package:webview_cookie_manager/webview_cookie_manager.dart';

class MyWebView extends StatefulWidget {
  const MyWebView({Key key, this.fileName, this.fileUrl, this.cookie}): super(key: key);

  final String fileUrl;
  final String cookie;
  final String fileName;

  @override
  MyWebViewState createState() => MyWebViewState();
}

class MyWebViewState extends State<MyWebView> {
  //final Completer<WebViewController> _controller = Completer<WebViewController>();
  //WebViewController _webViewController;
  //Future ssoRequestFuture;
  //WebviewCookieManager cookieManager = WebviewCookieManager();

  @override
  void initState() {
    super.initState();
    // Enable hybrid composition.
    if (Platform.isAndroid) WebView.platform = SurfaceAndroidWebView();
    //this.ssoRequestFuture = makeGetRequest();
    setCookie();
  }

  @override
  Widget build(BuildContext context) {
    //_controller.future.then((controller) {
    //  _webViewController = controller;
    //  _webViewController.loadUrl(widget.fileUrl/*, headers: {"Cookie": widget.cookie}*/);
    //});
    return WebView(
      initialUrl: widget.fileUrl,
      //debuggingEnabled: true,
      //javascriptMode: JavascriptMode.unrestricted,
      //onWebViewCreated: (WebViewController webViewController) {
        //setSession(webViewController);
        //_controller.complete(webViewController);
        //webViewController.loadUrl(widget.fileUrl, headers: {"Cookie": widget.cookie});
      //},
      //onPageFinished: (String value) {
      //  setSession(_webViewController);
      //},
    );
  }

  setCookie() async {
    var pairs = widget.cookie.split('; ');
    var cookie1 = pairs[0].split('=');
    var cookie2 = pairs[1].split('=');
    //await cookieManager.setCookies([
    //  Cookie(cookie1[0], cookie1[1]),
    //  Cookie(cookie2[0], cookie2[1]),
    //]);
  }
  /*
  Widget build(BuildContext context) {
    return FutureBuilder<http.Response>(
        future: this.ssoRequestFuture,
        builder: (context, snapshot) {
          switch (snapshot.connectionState) {
            case ConnectionState.none:
              return Text('Not connected');
            case ConnectionState.active:
            case ConnectionState.waiting:
              return Text('waiting');
            case ConnectionState.done:
              //var cookieStr = snapshot.data.headers['set-cookie'];
              //List<String> cookies = cookieStr.split(","); // I am not interested n the first cookie
              //Cookie ssoCookie = Cookie.fromSetCookieValue(cookies[1]);
              Map<String, String> header = {'Cookie': widget.cookie};
              // clear cookies was a suggestion ??
              CookieManager cookieManager = CookieManager();
              cookieManager.clearCookies();

              return Scaffold(
                body: Builder(builder: (BuildContext context) {
                  _controller.future.then((controller) {
                    _webViewController = controller;
                    _webViewController.loadUrl(widget.fileUrl, headers: header);
                  });

                  return WebView(
                    debuggingEnabled: true,
                    javascriptMode: JavascriptMode.unrestricted,
                    onWebViewCreated: (WebViewController webViewController) {
                      _controller.complete(webViewController);
                    },
                    gestureNavigationEnabled: true,
                  );
                }),
              );
            default:
              return Text('Default');
          }
        }
    );
  }

  void setSession(WebViewController webViewController) async {
    if (Platform.isIOS) {
      await webViewController.evaluateJavascript("document.cookie = '"+widget.cookie+"'");
    } else {
      await webViewController.evaluateJavascript('document.cookie = "'+widget.cookie+'; path=/"');
    }
  }
  */
}
