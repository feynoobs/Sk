import 'package:intl/intl.dart';
import 'package:logger/logger.dart';

class Utility
{
    static final Logger _logger = Logger();

    static Map<String, String> splitQuery(String query)
    {
        _logger.v('splitQuery(${query})');
        final Map<String, String> ret = {};

        query.split('&').forEach((one) {
            List<String> chop = one.split('=');
            ret[chop[0]] = chop[1];
        });

        return ret;
    }

    static String shrinkPosts(int posts)
    {
        _logger.v('shrinkPosts(${posts})');
        String text = '';
        if (posts > 0) {
            NumberFormat formatter = NumberFormat('#,###');
            text = formatter.format(posts);
        }

        return text;
    }

    static String now()
    {
        _logger.v('now()');
        return DateTime.now().toString();
    }

    static String createFuzzyDateTime(String dateTime)
    {
        _logger.v('createFuzzyDateTime(${dateTime})');
        late final String ret;
        final int now = (DateTime.now().millisecondsSinceEpoch / 1000).floor();

        DateTime input = DateFormat('EEE MMM dd HH:mm:ss yyyy').parse(dateTime.replaceAll('+0000 ', '')).add(const Duration(hours: 9));
        final int postTime =  (input.millisecondsSinceEpoch / 1000).floor();
        final int timeDiff = now - postTime;

        if (timeDiff < 60) {
            ret = '${timeDiff}秒';
        }
        else if (timeDiff < 3600) {
            int minute = (timeDiff / 60).floor();
            ret = '${minute}分';
        }
        else if (timeDiff < 86400) {
            int hour = (timeDiff / (60 * 60)).floor();
            ret = '${hour}時間';
        }
        else if (timeDiff < 604800) {
            int day = (timeDiff / (60 * 60 * 24)).floor();
            ret = '${day}日';
        }
        else if (timeDiff < 31536000) {
            ret = DateFormat('MM月dd日').format(input);
        }
        else {
            ret = DateFormat('yyyy年MM月dd日').format(input);
        }

        return ret;
    }
}
