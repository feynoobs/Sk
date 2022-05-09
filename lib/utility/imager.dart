import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';

class Imager
{
    static bool _running = false;
    static Map<String, List<Function(String)?>> _requests = {};
    static final Logger _logger = Logger();

    static Map<String, Object> _getPathObject(Uri uri, Directory asbDir)
    {
        final path = '/${uri.host}${uri.path.substring(0, uri.path.lastIndexOf('/') + 1)}';
        final file = uri.path.substring(uri.path.lastIndexOf('/') + 1);
        final Directory dirObject = Directory(asbDir.path + path);
        final File fileObject = File(dirObject.path + file);

        return {'directory': dirObject, 'file': fileObject};
    }

    static void _runner(Directory dir)
    {
        _running = true;
        _requests.forEach((String url, List<Function(String)?> callbacks) {
            final Uri uri = Uri.parse(url);
            final Map<String, Object> pathObject = _getPathObject(uri, dir);

            (pathObject['directory'] as Directory).create(recursive: true)
            .then((Directory _) {
                return http.get(uri);
            })
            .then((http.Response response) {
                (pathObject['file'] as File).writeAsBytesSync(response.bodyBytes);
                callbacks.forEach((Function(String)? f) {
                    if (f != null) {
                        f((pathObject['file'] as File).path);
                    }
                });
            });
        });
        _running = false;
    }

    static void save(String url)
    {
        getTemporaryDirectory()
        .then((Directory dir) {
            final Uri uri = Uri.parse(url);
            Map<String, Object> pathObject = _getPathObject(uri, dir);
            if ((pathObject['file'] as File).existsSync() == false) {
                if (_requests.containsKey(url) == false) {
                    _requests[url] = <Function(String)?>[null];
                }
                if (_running == false) {
                    _runner(dir);
                }
            }
        });
    }

    static void load(String url, Function(String) callback)
    {
        getTemporaryDirectory()
        .then((Directory dir) {
            final Uri uri = Uri.parse(url);
            Map<String, Object> pathObject = _getPathObject(uri, dir);
            if ((pathObject['file'] as File).existsSync() == true) {
                callback((pathObject['file'] as File).path);
            }
            else {
                if (_requests.containsKey(url) == true) {
                    _requests[url]?.add(callback);
                }
                else {
                    _requests[url] = <Function(String)>[callback];
                }
                if (_running == false) {
                    _runner(dir);
                }
            }
        });
    }
}
