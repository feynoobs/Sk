import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:logger/logger.dart';

import 'common.dart';
import '../database/db.dart';
import '../api/api_common.dart';
import '../api/api_request_token.dart';
import '../api/api_access_token.dart';
import '../api/api_users_show.dart';
import '../api/api_statuses_home_timeline.dart';
import '../utility/imager.dart';
import '../utility/utility.dart';

class HomeTimeline extends StatefulWidget
{
    const HomeTimeline({Key? key}) : super(key: key);

    @override
    State<HomeTimeline> createState() => _HomeTimelineState();
}

class _HomeTimelineState extends State<HomeTimeline>
{
    final Logger _logger = Logger();
    final List<Widget> _tweets = [];
    bool _locked = false;
    final ScrollController _scrollController = ScrollController();

    Future<int> _getHomeTimeline([final String? type]) async
    {
        _logger.v('_favBox(${type})');

        int reflashed = 0;
        if (_locked == false) {
            _locked = true;
            final SharedPreferences prefs = await SharedPreferences.getInstance();
            final int my = prefs.getInt('my') ?? 0;

            final Database database = await DB.getInstance();
            final List<Map<String, Object?>> user = await database.rawQuery('SELECT oauth_token, oauth_token_secret FROM t_users WHERE my = ?', [my.toString()]);
            if (user.isNotEmpty == true) {
                Map<String, String> requestData = {
                    'oauth_token': user[0]['oauth_token'] as String,
                    'oauth_token_secret': user[0]['oauth_token_secret'] as String,
                    'count': 200.toString(),
                    'exclude_replies': false.toString(),
                    'contributor_details': false.toString(),
                    'include_rts': true.toString(),
                    'tweet_mode': 'extended'
                };
                if (type != null) {
                    switch (type) {
                        case 'next':
                            final List<Map<String, Object?>>  tweets = await database.rawQuery('SELECT MAX(tweet_id) as max_id FROM r_home_tweets WHERE my = ?', [my.toString()]);
                            if (tweets[0]['max_id'] != null) {
                                requestData['since_id'] = tweets[0]['max_id'].toString();
                            }
                            break;
                        case 'prev':
                            final List<Map<String, Object?>>  tweets = await database.rawQuery('SELECT MIN(tweet_id) as min_id FROM r_home_tweets WHERE my = ?', [my.toString()]);
                            if (tweets[0]['min_id'] != null) {
                                requestData['max_id'] = ((tweets[0]['min_id'] as int) - 1).toString();
                            }
                            break;
                    }
                }
                final String tweetJsonString = await ApiStatusesHomeTimeline().start(requestData);
                final List<dynamic> tweetJsonObject = json.decode(tweetJsonString);
                reflashed = tweetJsonObject.length;
                final List<Map<String, Object?>> tweetDatas = [];
                final List<Map<String, Object?>> rDatas = [];
                for (int i = 0; i < tweetJsonObject.length; ++i) {
                    Map<String, Object?> data = {};
                    data['tweet_id'] = tweetJsonObject[i]['id'];
                    data['user_id'] = tweetJsonObject[i]['user']['id'];
                    data['data'] = json.encode(tweetJsonObject[i]);
                    data['reply_tweet_id'] = tweetJsonObject[i]['in_reply_to_user_id'];
                    tweetDatas.add(data);

                    Map<String, Object?> rdata = {};
                    rdata['tweet_id'] = tweetJsonObject[i]['id'];
                    rdata['my'] = my;
                    rDatas.add(rdata);
                }
                if (tweetDatas.isNotEmpty == true) {
                    await database.transaction((Transaction txn) async {
                        Batch batch = txn.batch();
                        DB.insert(batch, 't_tweets', tweetDatas);
                        DB.insert(batch, 'r_home_tweets', rDatas);
                        await batch.commit();
                    });
                }
            }
            _locked = false;
        }

        return reflashed;
    }

    Future<void> _reflashHomeTimeline(final String type) async
    {
        _logger.v('_reflashHomeTimeline()');

        int reflashed = await _getHomeTimeline(type);
        if (reflashed > 0) {
            _displayHomeTimeline(type);
        }
    }

    Row _favBox(final Map<String, Object?> tweetObject)
    {
        _logger.v('_favBox(${tweetObject})');
        Row r = Row(
            children: <Widget>[
                Container(
                    width: 16,
                    height: 16,
                    decoration: const BoxDecoration(
                        image: DecorationImage(
                            image: AssetImage('assets/images/tweet_favorite.png'),
                            fit: BoxFit.scaleDown
                        )
                    )
                ),
                Text(Utility.shrinkPosts(tweetObject['retweet_count'] as int))
            ]
        );

        if (tweetObject['favorited'] == true) {
            r = Row(
                children: <Widget>[
                    Container(
                        width: 16,
                        height: 16,
                        decoration: const BoxDecoration(
                            image: DecorationImage(
                                image: AssetImage('assets/images/tweet_favorited.png'),
                                fit: BoxFit.scaleDown
                            )
                        )
                    ),
                    Text(Utility.shrinkPosts(tweetObject['retweet_count'] as int))
                ]
            );
        }

        return r;
    }

    Row _rtBox(final Map<String, Object?> tweetObject)
    {
        _logger.v('_rtBox(${tweetObject})');
        Row r = Row(
            children: <Widget>[
                Container(
                    width: 16,
                    height: 16,
                    decoration: const BoxDecoration(
                        image: DecorationImage(
                            image: AssetImage('assets/images/tweet_retweet.png'),
                            fit: BoxFit.scaleDown
                        )
                    )
                ),
                Text(Utility.shrinkPosts(tweetObject['retweet_count'] as int))
            ]
        );

        if (tweetObject['retweeted'] == true) {
            r = Row(
                children: <Widget>[
                    Container(
                        width: 16,
                        height: 16,
                        decoration: const BoxDecoration(
                            image: DecorationImage(
                                image: AssetImage('assets/images/tweet_retweeted.png'),
                                fit: BoxFit.scaleDown
                            )
                        )
                    ),
                    Text(Utility.shrinkPosts(tweetObject['retweet_count'] as int))
                ]
            );
        }

        return r;
    }

    Container? _createTweetContainer(final Map<String, Object?> tweetObject, final Imager imager)
    {
        _logger.e(tweetObject);
        final Map<String, Object?> userObject = tweetObject['user'] as Map<String, Object?>;
        final String? path = imager.loadImage(userObject['profile_image_url_https'] as String);
        Container? ret;

        if (path != null) {
            ret =  Container(
                key: ValueKey((tweetObject['id'] as int)),
                padding: const EdgeInsets.only(top: 2, bottom: 2),
                decoration: const BoxDecoration(
                    border: Border(
                        bottom: BorderSide(
                            color: Colors.grey,
                            width: 0.2
                        ),
                    ),
                ),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                        ClipOval(
                            child: Image.file(File(path))
                        ),
                        Flexible(
                            child: Container(
                                margin: const EdgeInsets.only(left: 4),
                                child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: <Widget>[
                                        Row(
                                            children: <Widget>[
                                                Container(
                                                    constraints: BoxConstraints(minWidth: 0, maxWidth: MediaQuery.of(context).size.width * 0.6),
                                                    child: RichText(
                                                        overflow: TextOverflow.ellipsis,
                                                        text: TextSpan(
                                                            children: <InlineSpan>[
                                                                TextSpan(text: userObject['name'] as String, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
                                                                TextSpan(text: '@' + (userObject['screen_name'] as String), style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.black))
                                                            ],
                                                        )
                                                    )
                                                ),
                                                const Text('･'),
                                                Text(Utility.createFuzzyDateTime(tweetObject['created_at'] as String)),
                                                const Spacer(),
                                                Container(
                                                    width: 16,
                                                    height: 16,
                                                    decoration: const BoxDecoration(
                                                        image: DecorationImage(
                                                            image: AssetImage('assets/images/other.png'),
                                                            fit: BoxFit.scaleDown
                                                        )
                                                    )
                                                )
                                            ]
                                        ),
                                        Text(tweetObject['full_text'] as String, overflow: TextOverflow.clip),
                                        Row(
                                            children: <Widget>[
                                                Row(
                                                    children: <Widget>[
                                                        Container(
                                                            width: 16,
                                                            height: 16,
                                                            decoration: const BoxDecoration(
                                                                image: DecorationImage(
                                                                    image: AssetImage('assets/images/tweet_reply.png'),
                                                                    fit: BoxFit.scaleDown
                                                                )
                                                            )
                                                        ),
                                                        Text(''),
                                                    ]
                                                ),
                                                const Spacer(),
                                                _rtBox(tweetObject),
                                                const Spacer(),
                                                _favBox(tweetObject),
                                                const Spacer(),
                                                Container(
                                                    width: 16,
                                                    height: 16,
                                                    decoration: const BoxDecoration(
                                                        image: DecorationImage(
                                                            image: AssetImage('assets/images/tweet_share.png'),
                                                            fit: BoxFit.scaleDown
                                                        )
                                                    )
                                                ),
                                                const Spacer(),
                                            ]
                                        )
                                    ]
                                )
                            )
                        )
                    ]
                )
            );
        }

        return ret;
    }

    Future<void> _displayHomeTimeline([final String? type]) async
    {
        _logger.v('_displayHomeTimeline()');

        final SharedPreferences prefs = await SharedPreferences.getInstance();
        final int my = prefs.getInt('my') ?? 0;
        final Imager imager = Imager();

        final Database database = await DB.getInstance();
        final List<Map<String, dynamic>> tweets = await database.rawQuery(
            '''
            SELECT tt.*
            FROM t_tweets tt
            INNER JOIN r_home_tweets rht ON tt.tweet_id = rht.tweet_id
            WHERE my = ?
            ORDER BY tt.tweet_id DESC
            ''', [my.toString()]);
        // 先に画像を保存しておく
        await imager.initialization();
        for (int i = 0; i < tweets.length; ++i) {
            final Map<String, Object?> tweetObject =  json.decode(tweets[i]['data']) as Map<String, Object?>;
            final Map<String, Object?> userObject = tweetObject['user'] as Map<String, Object?>;
            await imager.saveImage(userObject['profile_image_url_https'] as String);
        }

        setState(() {
            for (int i = 0; i < tweets.length; ++i) {
                final Map<String, Object?> tweetObject =  json.decode(tweets[i]['data']) as Map<String, Object?>;
                final Container? container = _createTweetContainer(tweetObject, imager);
                if (container != null) {
                    if (type == 'next') {
                        _scrollController.jumpTo(100);
                        if (_tweets.isNotEmpty == true) {
                            final int value = (_tweets[0].key as ValueKey).value;
                            if (value < tweets[i]['tweet_id']) {
                                _tweets.insert(0, container);
                            }
                            else {
                                break;
                            }
                        }
                        else {
                            _tweets.add(container);
                        }
                    }
                    else {
                        if (_tweets.isNotEmpty == true) {
                            final int value = (_tweets[_tweets.length - 1].key as ValueKey).value;
                            if (value > tweets[i]['tweet_id']) {
                                _tweets.add(container);
                            }
                            else {
                                break;
                            }
                        }
                        else {
                            _tweets.add(container);
                        }
                    }
                }
            }
        });
    }

    Future<void> _entry() async
    {
        _logger.v('_entry()');

        final SharedPreferences prefs = await SharedPreferences.getInstance();
        int my = prefs.getInt('my') ?? 0;

        final Database database = await DB.getInstance();
        final List<Map<String, Object?>> users = await database.rawQuery('SELECT oauth_token, oauth_token_secret FROM t_users WHERE my = ?', [my.toString()]);
        if (users.isEmpty == true) {
            final String query = await ApiRequestToken().start({});
            final Map<String, String> params = Utility.splitQuery(query);
            final dynamic callback = await Navigator.pushNamed(context, 'authentication', arguments: params);
            if (callback != null) {
                final String query2 = (callback as String).replaceAll('${ApiCommon.CALLBACK_URL}?', '');
                final Map<String, String> params2 = Utility.splitQuery(query2);
                // 認証拒否された場合は処理しない
                // 拒否されたばあい「denied」が付与されるので否定
                if (params2.containsKey('denied') == false) {
                    params2['oauth_token_secret'] = params['oauth_token_secret']!;
                    final String query3 = await ApiAccessToken().start(params2);
                    final Map<String, String> params3 = Utility.splitQuery(query3);
                    final Map<String, String> userData = {'oauth_token': params3['oauth_token']!, 'oauth_token_secret': params3['oauth_token_secret']!, 'user_id': params3['user_id']!};
                    final String userJson = await ApiUsersShow().start(userData);
                    ++my;
                    await database.transaction((Transaction txn) async {
                        final Batch batch = txn.batch();
                        DB.insert(batch, 't_users', [{'user_id': params3['user_id'], 'oauth_token': params3['oauth_token'], 'oauth_token_secret': params3['oauth_token_secret'], 'my': my.toString(), 'data': userJson}]);
                        await batch.commit();
                    });
                    await prefs.setInt('my', my);
                    await _getHomeTimeline();
                }
            }
        }
        _displayHomeTimeline();
    }

    @override
    void initState()
    {
        super.initState();
        _logger.v('initState()');
        _entry();
    }

    @override
    Widget build(BuildContext context)
    {
        _logger.v('build(${context})');

         return Scaffold(
            appBar: const EmptyAppBar(),
            body: NotificationListener<ScrollNotification> (
                child: Scrollbar(
                    child:  ListView.builder(
                        controller: _scrollController,
                        shrinkWrap: true,
                        itemCount: _tweets.length,
                        itemBuilder: (final BuildContext _, final int index) {
                            return _tweets[index];
                        },
                    ),
                ),
                onNotification: (final ScrollNotification notification) {
                    if (notification is OverscrollNotification) {
                        if (notification.overscroll >= 0.0) {
                            _reflashHomeTimeline('prev');
                        }
                        else {
                            _reflashHomeTimeline('next');
                        }
                    }
                    return true;
                }
            ),
            floatingActionButton: FloatingActionButton(
                onPressed: () async {
                    setState(() {

                    });
                    /*
                    Database database = await DB.getInstance();
                    await database.rawDelete('DELETE FROM t_users');
                    await database.rawDelete('DELETE FROM t_tweets');
                    await database.rawDelete('DELETE FROM r_home_tweets');
                    _logger.d('remove... done');
                    */
                },
                child: const Icon(Icons.add)
            )
        );
    }
}
