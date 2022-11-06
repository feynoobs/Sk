import 'api_common.dart';

class ApiStatusesRetweet extends ApiCommon
{
    ApiStatusesRetweet(final int id) : super('https://api.twitter.com/1.1/statuses/retweet/${id}.json', 'POST');

    @override
    Future<String> start(final Map<String, String> params)
    {
        final Map<String, String> fixedToken = {'oauth_token': params['oauth_token']!, 'oauth_token_secret': params['oauth_token_secret']!};
        params.remove('oauth_token');
        params.remove('oauth_token_secret');

        return startMain(params, fixedToken);
    }
}
