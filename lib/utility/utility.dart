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
}
