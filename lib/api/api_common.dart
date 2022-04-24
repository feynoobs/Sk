import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';

abstract class ApiCommon
{
    static const String _API_KEY = '2hSoAk98Pw9Vk6LNmXOO6hip6';
    static const String _API_SECRET = 't7jHT6dysIJvPVzWORgex8FuHW2orZUEul1JzUazgFoaJqnaGx';
    static const String CALLBACK_URL = 'twinida://';

    final String _entryPoint;
    final String _method;

    final Logger _logger = Logger();

    ApiCommon(this._entryPoint, this._method);

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
        String signatureKey = Uri.encodeFull(_API_SECRET) + '&';
        if (fixedToken == null) {
            headerParams['oauth_token'] = params['oauth_token']!;
            signatureKey += Uri.encodeComponent(params['oauth_token_secret']!);
        }
        else {
            headerParams['oauth_token'] = fixedToken['oauth_token']!;
            signatureKey += Uri.encodeComponent(fixedToken['oauth_token_secret']!);
            headerParams.addAll(params);
        }
        Map<String, String> sortParams = SplayTreeMap.from(headerParams, (String a, String b) => a.compareTo(b));
        String query = '';
        sortParams.forEach((key, value) {
            value = Uri.encodeComponent(value);
            query += '${key}=${value}&';
        });
        query = Uri.encodeComponent(query.substring(0, query.length - 1));
        final String encodeUrl = Uri.encodeComponent(_entryPoint);
        final String signatureData = '${_method}&${encodeUrl}&${query}';
        sortParams['oauth_signature'] = base64.encode(Hmac(sha1, utf8.encode(signatureKey)).convert(utf8.encode(signatureData)).bytes);

        String header = '';
        sortParams.forEach((key, value) {
            value = Uri.encodeComponent(value);
            header += '${key}=${value},';
        });
        header = Uri.encodeComponent(header.substring(0, header.length - 1));

        final Uri url = Uri.parse(_entryPoint);
        if (_method == 'GET') {
            final Uri requstUrl = Uri.https(url.host, url.path, params);
            http.get(requstUrl, headers: {
                'Authorization': 'OAuth ${header}',
            })
            .then((http.Response response) => null);
        }
        else {
            final Uri requstUrl = Uri.https(url.host, url.path);
            String body = '';
            params.forEach((key, value) {
                body += '${key}=${value}&';
            });
            body = body.substring(0, body.length - 1);
            http.post(requstUrl, body: body, headers: {
                'Authorization': 'OAuth ${header}',
            })
            .then((http.Response response) => null);
        }

        return computer.future;
    }
}
