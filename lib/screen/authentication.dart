import 'dart:io';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:logger/logger.dart';

import '../api/api_request_token.dart';
import '../utility/utility.dart';

class Authentication extends StatefulWidget
{
    const Authentication({Key? key}) : super(key: key);

    @override
    State<Authentication> createState() => _AuthenticationState();
}

class _AuthenticationState extends State<Authentication>
{
    final Logger _logger = Logger();

    @override
    void initState()
    {
        super.initState();
        if (Platform.isAndroid == true) {
            WebView.platform = SurfaceAndroidWebView();
        }
    }

    @override
    Widget build(BuildContext context)
    {
        Map<String, String> params = ModalRoute.of(context)!.settings.arguments as Map<String, String>;
        return Scaffold(
            appBar: null,
            body: WebView(
                initialUrl: "https://api.twitter.com/oauth/authorize?oauth_token=${params['oauth_token']}",
                javascriptMode: JavascriptMode.unrestricted,
                onPageFinished: (String url) {
                    _logger.e(url);
                }
            ),
        );
    }

}
