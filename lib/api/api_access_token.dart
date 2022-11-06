import 'api_common.dart';

class ApiAccessToken extends ApiCommon
{
    ApiAccessToken() : super('https://api.twitter.com/oauth/access_token', 'POST');

    @override
    Future<String> start(final Map<String, String> params)
    {
        return startMain(params);
    }
}
