import 'api_common.dart';

class ApiStatusesHomeTimeline extends ApiCommon
{
    ApiStatusesHomeTimeline() : super('https://api.twitter.com/1.1/statuses/home_timeline.json', 'GET');

    @override
    Future<String> start(Map<String, String> params)
    {
        final Map<String, String> fixedToken = {'oauth_token': params['oauth_token']!, 'oauth_token_secret': params['oauth_token_secret']!};
        params.remove('oauth_token');
        params.remove('oauth_token_secret');

        return startMain(params, fixedToken);
    }
}
