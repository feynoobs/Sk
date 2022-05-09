import 'package:intl/intl.dart';

class Utility
{
    static Map<String, String> splitQuery(String query)
    {
        Map<String, String> ret = {};

        query.split('&').forEach((one) {
            List<String> chop = one.split('=');
            ret[chop[0]] = chop[1];
        });

        return ret;
    }

    static String now()
    {
        return DateTime.now().toString();
    }

    static String createFuzzyDateTime(String dateTime)
    {
        late String ret;
        int now = (DateTime.now().millisecondsSinceEpoch / 1000).floor();

        DateTime input = DateFormat('EEE MMM dd HH:mm:ss Z yyyy').parse(dateTime);
        int postTime =  (input.millisecondsSinceEpoch / 1000).floor();
        int timeDiff = now - postTime;

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
            ret = DateFormat('MM月dd年').format(input);
        }
        else {
            ret = DateFormat('yyyy年MM月dd年').format(input);
        }

        return ret;
    }
}
