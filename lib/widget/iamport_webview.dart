import 'dart:async';

import 'package:flutter/material.dart';
import '../model/iamport_url.dart';
import 'package:iamport_webview_flutter/iamport_webview_flutter.dart';

enum ActionType { auth, payment }

class IamportWebView extends StatefulWidget {
  static final Color primaryColor = Color(0xff344e81);
  static final String html = '''
    <html>
      <head>
        <meta http-equiv="content-type" content="text/html; charset=utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">

        <script type="text/javascript" src="https://code.jquery.com/jquery-latest.min.js" ></script>
        <script type="text/javascript" src="https://cdn.iamport.kr/js/iamport.payment-1.2.0.js"></script>
      </head>
      <body></body>
    </html>
  ''';

  final ActionType type;
  final PreferredSizeWidget? appBar;
  final Widget? initialChild;
  final ValueSetter<WebViewController> executeJS;
  final ValueSetter<Map<String, String>> useQueryData;
  final Function isPaymentOver;
  final Function customPGAction;

  IamportWebView({
    required this.type,
    this.appBar,
    this.initialChild,
    required this.executeJS,
    required this.useQueryData,
    required this.isPaymentOver,
    required this.customPGAction,
  });

  @override
  _IamportWebViewState createState() => _IamportWebViewState();
}

class _IamportWebViewState extends State<IamportWebView> {
  late WebViewController _webViewController;
  StreamSubscription? _sub;
  int _idx = 1;

  @override
  void dispose() {
    super.dispose();
    if (_sub != null) _sub!.cancel();
  }

  @override
  Widget build(BuildContext context) {
    String? typeText;
    if (widget.type == ActionType.auth) {
      typeText = '본인인증';
    } else if (widget.type == ActionType.payment) {
      typeText = '결제';
    }

    return Scaffold(
      appBar: widget.appBar ??
          AppBar(
            title: Text('Ggumim 아임포트 $typeText'),
            backgroundColor: IamportWebView.primaryColor,
          ),
      body: IndexedStack(
        index: _idx,
        children: [
          WebView(
            initialUrl:
                Uri.dataFromString(IamportWebView.html, mimeType: 'text/html')
                    .toString(),
            javascriptMode: JavascriptMode.unrestricted,
            onWebViewCreated: (controller) {
              this._webViewController = controller;
              if (widget.type == ActionType.payment) {
                // 스마일페이, 나이스 실시간 계좌이체
                _sub = widget.customPGAction(this._webViewController);
              }
              // 웹뷰 로딩 완료시에 화면 전환
              setState(() {
                _idx = 0;
              });
            },
            onPageFinished: (String url) {
              // 페이지 로딩 완료시 IMP 코드 실행
              widget.executeJS(this._webViewController);
            },
            navigationDelegate: (request) async {
              // print("url: " + request.url);
              if (widget.isPaymentOver(request.url)) {
                String decodedUrl = Uri.decodeComponent(request.url);
                widget.useQueryData(Uri.parse(decodedUrl).queryParameters);

                return NavigationDecision.prevent;
              }

              final iamportUrl = IamportUrl(request.url);
              if (iamportUrl.isAppLink()) {
                // print("appLink: " + iamportUrl.appUrl!);
                // 앱 실행 로직을 iamport_url 모듈로 이동
                iamportUrl.launchApp();
                return NavigationDecision.prevent;
              }

              return NavigationDecision.navigate;
            },
          ),
          widget.initialChild ??
              Container(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset('assets/images/iamport-logo.png'),
                      Container(
                        padding: EdgeInsets.fromLTRB(0.0, 30.0, 0.0, 0.0),
                        child: Text('잠시만 기다려주세요...',
                            style: TextStyle(fontSize: 20.0)),
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }
}
