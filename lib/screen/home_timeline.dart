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
import '../api/api_favorites_create.dart';
import '../api/api_favorites_destroy.dart';
import '../api/api_statuses_retweet.dart';
import '../api/api_statuses_unretweet.dart';
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
    List<Container> _tweets = [];
    bool _locked = false;

    Future<int> _getHomeTimeline([final String? type]) async
    {
        int reflashed = 0;
        if (_locked == false) {
            _locked = true;

            final Database database = await DB.getInstance();
            final Map<String, String>? token = await _getToken();
            if (token != null) {
                final SharedPreferences prefs = await SharedPreferences.getInstance();
                final int my = prefs.getInt('my') ?? 0;

                Map<String, String> requestData = {
                    'oauth_token': token['oauth_token']!,
                    'oauth_token_secret': token['oauth_token_secret']!,
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
                                requestData['max_id'] = tweets[0]['min_id'].toString();
                            }
                            break;
                    }
                }
                final String? tweetJsonString = await ApiStatusesHomeTimeline().start(requestData);
                if (tweetJsonString != null) {
                    final List<dynamic> tweetJsonObject = json.decode(tweetJsonString);
                    reflashed = tweetJsonObject.length;
                    database.transaction((final Transaction txn) async {
                        Batch batch = txn.batch();
                        for (int i = 0; i < tweetJsonObject.length; ++i) {
                            Map<String, Object?> data = {};
                            data['tweet_id'] = tweetJsonObject[i]['id'];
                            data['user_id'] = tweetJsonObject[i]['user']['id'];
                            data['data'] = json.encode(tweetJsonObject[i]);
                            data['reply_tweet_id'] = tweetJsonObject[i]['in_reply_to_user_id'];
                            batch.insert('t_tweets', data);

                            Map<String, Object?> rdata = {};
                            rdata['tweet_id'] = tweetJsonObject[i]['id'];
                            rdata['my'] = my;
                            batch.insert('r_home_tweets', rdata);
                        }
                        batch.commit();
                    });
                }
            }
            _locked = false;
        }

        return reflashed;
    }

    Future<void> _reflashHomeTimeline(final String type) async
    {
        int reflashed = await _getHomeTimeline(type);
        if (reflashed > 0) {
            _displayHomeTimeline(type);
        }
    }

    Future<void> _updateOne(final Database database, final String tweetJsonString) async
    {
        final Map<String, Object?> tweetJsonObject = json.decode(tweetJsonString);
        final Imager imager = Imager();
        await imager.initialization();
        database.transaction((final Transaction txn) async {
            Batch batch = txn.batch();
            final Map<String, Object?> data = {'data': tweetJsonString};
            batch.update('t_tweets', data, where: 'tweet_id = ?', whereArgs: [tweetJsonObject['id']]);
            batch.commit();
        });
        final Container? container = await _createTweetContainer(tweetJsonObject, imager);
        if (container != null) {
            for (int i = 0; i < _tweets.length; ++i) {
                _logger.v('${(_tweets[i].key as ValueKey).value}:${tweetJsonObject['id']}');
                if ((_tweets[i].key as ValueKey).value == tweetJsonObject['id']) {
                    _tweets[i] = container;
                }
            }
        }
    }

    Future<Map<String, String>?> _getToken() async
    {
        final SharedPreferences prefs = await SharedPreferences.getInstance();
        final int my = prefs.getInt('my') ?? 0;
        final Database database = await DB.getInstance();
        final List<Map<String, Object?>> user = await database.rawQuery('SELECT oauth_token, oauth_token_secret FROM t_users WHERE my = ?', [my.toString()]);
        Map<String, String>? result;
        if (user.isNotEmpty) {
            result = {'oauth_token': user[0]['oauth_token'] as String, 'oauth_token_secret': user[0]['oauth_token_secret'] as String};
        }

        return result;
    }

    Future<Row> _favBox(final Map<String, Object?> tweetObject) async
    {
        AssetImage image = const AssetImage('assets/images/tweet_favorite.png');
        Function() tap = () async {
            final Database database = await DB.getInstance();
            final Map<String, String>? token = await _getToken();
            if (token != null) {
                final Map<String, String> requestData = {
                    'oauth_token': token['oauth_token']!,
                    'oauth_token_secret': token['oauth_token_secret']!,
                    'id': tweetObject['id'].toString(),
                    'include_entities': true.toString(),
                    'tweet_mode': 'extended',
                };
                final String? tweetJsonString = await ApiFavoritesCreate().start(requestData);
                _logger.e(tweetJsonString);
                if (tweetJsonString != null) {
                    setState(() {
                        _updateOne(database, tweetJsonString);
                    });
                }
            }
        };
        if (tweetObject['favorited'] == true) {
            image = const AssetImage('assets/images/tweet_favorited.png');
            tap = () async {
                final Database database = await DB.getInstance();
                final Map<String, String>? token = await _getToken();
                if (token != null) {
                    final Map<String, String> requestData = {
                        'oauth_token': token['oauth_token']!,
                        'oauth_token_secret': token['oauth_token_secret']!,
                        'id': tweetObject['id'].toString(),
                        'include_entities': true.toString(),
                        'tweet_mode': 'extended',
                    };
                    final String? tweetJsonString = await ApiFavoritesDestroy().start(requestData);
                    if (tweetJsonString != null) {
                        setState(() {
                            _updateOne(database, tweetJsonString);
                        });
                    }
                }
            };
        }
        return Row(
            children: <Widget>[
                GestureDetector(
                    onTap: tap,
                    child: Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                            image: DecorationImage(
                                image: image,
                                fit: BoxFit.scaleDown
                            )
                        )
                    )
                ),
                Text(Utility.shrinkPosts(tweetObject['retweet_count'] as int))
            ]
        );
    }

    Future<Row> _rtBox(final Map<String, Object?> tweetObject) async
    {
        AssetImage image = const AssetImage('assets/images/tweet_retweet.png');
        Function() tap = () async {
            final Database database = await DB.getInstance();
            final Map<String, String>? token = await _getToken();
            if (token != null) {
                final Map<String, String> requestData = {
                    'oauth_token': token['oauth_token']!,
                    'oauth_token_secret': token['oauth_token_secret']!,
                    'include_entities': true.toString(),
                    'tweet_mode': 'extended',
                };
                final String? tweetJsonString = await ApiStatusesRetweet(int.parse(tweetObject['id'] as String)).start(requestData);
                if (tweetJsonString != null) {
                    setState(() {
                        _updateOne(database, tweetJsonString);
                    });
                }
            }
        };
        if (tweetObject['retweeted'] == true) {
            image = const AssetImage('assets/images/tweet_retweeted.png');
            tap = () async {
                final Database database = await DB.getInstance();
                final Map<String, String>? token = await _getToken();
                if (token != null) {
                    final Map<String, String> requestData = {
                        'oauth_token': token['oauth_token']!,
                        'oauth_token_secret': token['oauth_token_secret']!,
                        'include_entities': true.toString(),
                        'tweet_mode': 'extended',
                    };
                    final String? tweetJsonString = await ApiStatusesUnretweet(int.parse(tweetObject['id'] as String)).start(requestData);
                    if (tweetJsonString != null) {
                        setState(() {
                            _updateOne(database, tweetJsonString);
                        });
                    }
                }
            };
        }
        return Row(
            children: <Widget>[
                GestureDetector(
                    onTap: tap,
                    child: Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                            image: DecorationImage(
                                image: image,
                                fit: BoxFit.scaleDown
                            )
                        )
                    )
                ),
                Text(Utility.shrinkPosts(tweetObject['retweet_count'] as int))
            ]
        );
    }

    Future<Container?> _createTweetContainer(final Map<String, Object?> tweetObject, final Imager imager) async
    {
        final Map<String, Object?> userObject = tweetObject['user'] as Map<String, Object?>;
        final String? path = imager.loadImage(userObject['profile_image_url_https'] as String);
        Container? ret;

        if (path != null) {
            final Row fav = await _favBox(tweetObject);
            final Row rt = await _rtBox(tweetObject);
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
                                                    ]
                                                ),
                                                const Spacer(),
                                                rt,
                                                const Spacer(),
                                                fav,
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

    Future<void> _displayHomeTimeline(final String type) async
    {
        final SharedPreferences prefs = await SharedPreferences.getInstance();
        final int my = prefs.getInt('my') ?? 0;
        final Imager imager = Imager();

        final direction = (type == 'next' ? 'DESC' : 'ASC');
        final Database database = await DB.getInstance();
        final List<Map<String, dynamic>> tweets = await database.rawQuery(
            '''
            SELECT tt.*
            FROM t_tweets tt
            INNER JOIN r_home_tweets rht ON tt.tweet_id = rht.tweet_id
            WHERE my = ?
            ORDER BY tt.tweet_id ${direction}
            ''', [my.toString()]);
        // 先に画像を保存しておく
        await imager.initialization();
        for (int i = 0; i < tweets.length; ++i) {
            final Map<String, Object?> tweetObject =  json.decode(tweets[i]['data']) as Map<String, Object?>;
            final Map<String, Object?> userObject = tweetObject['user'] as Map<String, Object?>;
            await imager.saveImage(userObject['profile_image_url_https'] as String);
        }

        final List<Container> tmp = [];
        for (int i = 0; i < tweets.length; ++i) {
            final Map<String, Object?> tweetObject =  json.decode(tweets[i]['data']) as Map<String, Object?>;
            final Container? container = await _createTweetContainer(tweetObject, imager);
            if (container != null) {
                if (type == 'next') {
                    if (_tweets.isEmpty) {
                        tmp.add(container);
                    }
                    else {
                        final int value = (_tweets[0].key as ValueKey).value;
                        if (value < tweets[i]['tweet_id']) {
                            tmp.add(container);
                        }
                        else {
                            break;
                        }
                    }
                }
                else {
                    if (_tweets.isEmpty) {
                        tmp.insert(0, container);
                    }
                    else {
                        final int value = (_tweets[_tweets.length - 1].key as ValueKey).value;
                        if (value > tweets[i]['tweet_id']) {
                            tmp.insert(0, container);
                        }
                        else {
                            break;
                        }
                    }
                }
            }
        }
        if (type == 'next') {
            _tweets = tmp + _tweets;
        }
        else {
            _tweets = _tweets + tmp;
        }
        setState(() {
        });
    }

    Future<void> _entry() async
    {
        final SharedPreferences prefs = await SharedPreferences.getInstance();
        int my = prefs.getInt('my') ?? 0;

        final Database database = await DB.getInstance();
        final List<Map<String, Object?>> users = await database.rawQuery('SELECT oauth_token, oauth_token_secret FROM t_users WHERE my = ?', [my.toString()]);
        if (users.isEmpty == true) {
            final String? query = await ApiRequestToken().start({});
            if (query != null) {
                final Map<String, String> params = Utility.splitQuery(query);
                final dynamic callback = await Navigator.pushNamed(context, 'authentication', arguments: params);
                if (callback != null) {
                    final String query2 = (callback as String).replaceAll('${ApiCommon.CALLBACK_URL}?', '');
                    final Map<String, String> params2 = Utility.splitQuery(query2);
                    // 認証拒否された場合は処理しない
                    // 拒否されたばあい「denied」が付与されるので否定
                    if (params2.containsKey('denied') == false) {
                        params2['oauth_token_secret'] = params['oauth_token_secret']!;
                        final String? query3 = await ApiAccessToken().start(params2);
                        if (query3 != null) {
                            final Map<String, String> params3 = Utility.splitQuery(query3);
                            final Map<String, String> userData = {'oauth_token': params3['oauth_token']!, 'oauth_token_secret': params3['oauth_token_secret']!, 'user_id': params3['user_id']!};
                            final String? userJson = await ApiUsersShow().start(userData);
                            if (userJson != null) {
                                ++my;
                                database.transaction((Transaction txn) async {
                                    final Batch batch = txn.batch();
                                    batch.insert('t_users', {'user_id': params3['user_id'], 'oauth_token': params3['oauth_token'], 'oauth_token_secret': params3['oauth_token_secret'], 'my': my.toString(), 'data': userJson});
                                    batch.commit();
                                });
                                await prefs.setInt('my', my);
                                await _getHomeTimeline();
                            }
                        }
                    }
                }
            }
        }
        _displayHomeTimeline('next');
    }

    @override
    void initState()
    {
        super.initState();
        _entry();
    }

    @override
    Widget build(BuildContext context)
    {
        final ScrollController scrollController = ScrollController();

         return Scaffold(
            appBar: const EmptyAppBar(),
            body: NotificationListener<ScrollNotification> (
                child: RefreshIndicator(
                    onRefresh:  () async {},
                    child: Scrollbar(
                        child:  ListView.builder(
                            controller: scrollController,
                            shrinkWrap: true,
                            itemCount: _tweets.length,
                            itemBuilder: (final BuildContext _, final int index) {
                                return _tweets[index];
                            },
                        ),
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
                    Database database = await DB.getInstance();
                    await database.rawDelete('DELETE FROM t_users');
                    await database.rawDelete('DELETE FROM t_tweets');
                    await database.rawDelete('DELETE FROM r_home_tweets');
                    _logger.d('remove... done');
                    setState(() {
                    });
                },
                child: const Icon(Icons.add)
            )
        );
    }
}
