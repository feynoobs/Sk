import 'api_common.dart';

class ApiRequestToken extends ApiCommon
{
    ApiRequestToken() : super('https://api.twitter.com/oauth/request_token', 'POST');

    @override
    Future<String> start(Map<String, String> params)
    {
        return startMain();
    }
}
