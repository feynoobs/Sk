import 'api_common.dart';

class ApiFavoritesCreate extends ApiCommon
{
    ApiFavoritesCreate() : super('https://api.twitter.com/1.1/favorites/create.json', 'POST');

    @override
    Future<String> start(final Map<String, String> params)
    {
        final Map<String, String> fixedToken = {'oauth_token': params['oauth_token']!, 'oauth_token_secret': params['oauth_token_secret']!};
        params.remove('oauth_token');
        params.remove('oauth_token_secret');

        return startMain(params, fixedToken);
    }
}
