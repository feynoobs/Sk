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

    Future<String?> start(final Map<String, String> params);

    Future<String?> startMain(final Map<String, String> params, [final Map<String, String>? fixedToken])
    {
        _logger.v('startMain(${params}, ${fixedToken})');
        final Completer<String?> computer = Completer<String?>();
        final Map<String, String> headerParams = {
            'oauth_consumer_key': _API_KEY,
            'oauth_nonce': DateTime.now().toUtc().millisecondsSinceEpoch.toString(),
            'oauth_signature_method': 'HMAC-SHA1',
            'oauth_timestamp': (DateTime.now().toUtc().millisecondsSinceEpoch / 1000).floor().toString(),
            'oauth_version': '1.0',
        };
        String signatureKey = Uri.encodeFull(_API_SECRET) + '&';
        if (fixedToken == null) {
            params.forEach((final String key, final String value) {
                if (key == 'oauth_token_secret') {
                    signatureKey += Uri.encodeComponent(value);
                }
                else {
                    headerParams[key] = value;
                }
            });
        }
        else {
            headerParams['oauth_token'] = fixedToken['oauth_token']!;
            signatureKey += Uri.encodeComponent(fixedToken['oauth_token_secret']!);
            headerParams.addAll(params);
        }

        final Map<String, String> sortParams = SplayTreeMap.from(headerParams, (final String a, final String b) => a.compareTo(b));
        String query = '';
        sortParams.forEach((final String key, final String value) {
            query += '${key}=${Uri.encodeComponent(value)}&';
        });
        query = Uri.encodeComponent(query.substring(0, query.length - 1));
        final String encodeUrl = Uri.encodeComponent(_entryPoint);
        final String signatureData = '${_method}&${encodeUrl}&${query}';
        sortParams['oauth_signature'] = base64.encode(Hmac(sha1, utf8.encode(signatureKey)).convert(utf8.encode(signatureData)).bytes);

        String header = '';
        sortParams.forEach((final String key, final String value) {
            header += '${key}=${Uri.encodeComponent(value)},';
        });
        header = header.substring(0, header.length - 1);

        final Uri url = Uri.parse(_entryPoint);
        if (_method == 'GET') {
            final Uri requstUrl = Uri.https(url.host, url.path, params);
            http.get(requstUrl, headers: {
                'Authorization': 'OAuth ${header}',
            })
            .then((final http.Response response) {
                String? r = response.body;
                if (response.statusCode != 200) {
                    r = null;
                }
                computer.complete(r);
            });
        }
        else {
            final Uri requstUrl = Uri.https(url.host, url.path);
            http.post(requstUrl, body: params, headers: {
                'Authorization': 'OAuth ${header}',
            })
            .then((final http.Response response) {
                String? r = response.body;
                if (response.statusCode != 200) {
                    r = null;
                }
                computer.complete(r);
            });
        }

        return computer.future;
    }
}
