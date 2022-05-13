import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';

class Imager
{
    final Logger _logger = Logger();
    Directory? _cacheDirectory;

    Future<void> initialization() async
    {
        _logger.v('initialization()');
        _cacheDirectory = await getTemporaryDirectory();
    }


    Future<void> saveImage(final String url) async
    {
        _logger.v('saveImage(${url})');
        if (_cacheDirectory != null) {
            final Uri uri = Uri.parse(url);
            final path = '/${uri.host}${uri.path.substring(0, uri.path.lastIndexOf('/') + 1)}';
            final file = uri.path.substring(uri.path.lastIndexOf('/') + 1);
            final Directory dirObject = Directory(_cacheDirectory!.path + path);
            final File fileObject = File(dirObject.path + file);

            if (fileObject.existsSync() != true) {
                await dirObject.create(recursive: true);
                final http.Response response = await http.get(uri);
                fileObject.writeAsBytesSync(response.bodyBytes);
            }
        }
    }

    String? loadImage(final String url)
    {
        _logger.v('loadImage(${url})');
        String? ret;
        if (_cacheDirectory != null) {
            final Uri uri = Uri.parse(url);
            final path = '/${uri.host}${uri.path.substring(0, uri.path.lastIndexOf('/') + 1)}';
            final file = uri.path.substring(uri.path.lastIndexOf('/') + 1);
            final Directory dirObject = Directory(_cacheDirectory!.path + path);
            final File fileObject = File(dirObject.path + file);

            if (fileObject.existsSync() == true) {
                ret = fileObject.path;
            }
        }

        return ret;
    }
}
