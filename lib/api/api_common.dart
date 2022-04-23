import 'dart:async';
import 'dart:collection';

import 'package:logger/logger.dart';

abstract class ApiCommon
{
    static const String _API_KEY = '2hSoAk98Pw9Vk6LNmXOO6hip6';
    static const String _API_SECRET = 't7jHT6dysIJvPVzWORgex8FuHW2orZUEul1JzUazgFoaJqnaGx';
    static const String CALLBACK_URL = 'twinida://';

    final Logger _logger = Logger();

    start(Map<String, String> params);
    finish(String result);

    Future<void> startMain(Map<String, String> params, Map<String, String>? fixedToken)
    {
        _logger.v('startMain(${params}, ${fixedToken})');
        Completer computer = Completer<void>();
        Map<String, String> headerParams = {
            'oauth_consumer_key': _API_KEY,
            'oauth_nonce': DateTime.now().toUtc().millisecondsSinceEpoch.toString(),
            'oauth_signature_method': 'MAC-SHA1',
            'oauth_timestamp': (DateTime.now().toUtc().millisecondsSinceEpoch / 1000).floor().toString(),
            'oauth_version': '1.0',
        };
        String signature = Uri.encodeFull(_API_SECRET) + '&';
        if (fixedToken == null) {
            headerParams['oauth_token'] = params['oauth_token']!;
            signature += Uri.encodeComponent(params['oauth_token_secret']!);
        }
        else {
            headerParams['oauth_token'] = fixedToken['oauth_token']!;
            signature += Uri.encodeComponent(fixedToken['oauth_token_secret']!);
            headerParams.addAll(params);
        }
        Map<String, String> sortParams = SplayTreeMap.from(headerParams, (String a, String b) => a.compareTo(b));
        String query = '';
        sortParams.forEach((key, value) {
            String v = Uri.encodeComponent(value);
            query += '${key}=${v}';
         });


        return computer.future;
    }
}
