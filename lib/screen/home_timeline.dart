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

    Future<void> _getHomeTimeline([String? type]) async
    {
        final SharedPreferences prefs = await SharedPreferences.getInstance();
        final int my = prefs.getInt('my') ?? 0;

        final Database database = await DB.getInstance();
        final List<Map<String, Object?>> user = await database.rawQuery('SELECT oauth_token, oauth_token_secret FROM t_users WHERE my = ?', [my.toString()]);
        if (user.isNotEmpty == true) {
            Map<String, String> requestData = {
                'oauth_token': user[0]['oauth_token'] as String,
                'oauth_token_secret': user[0]['oauth_token_secret'] as String,
                'count': 10.toString(),
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
            List<Map<String, Object?>> tweetDatas = [];
            List<Map<String, Object?>> rDatas = [];
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
            await database.transaction((Transaction txn) async {
                await DB.insert(txn, 't_tweets', tweetDatas);
                await DB.insert(txn, 'r_home_tweets', rDatas);
            });
        }
    }

    Future<void> _displayHomeTimeline() async
    {
        final SharedPreferences prefs = await SharedPreferences.getInstance();
        final int my = prefs.getInt('my') ?? 0;

        final Database database = await DB.getInstance();
        final List<Map<String, dynamic>> tweets = await database.rawQuery(
            '''
            SELECT tt.*
            FROM t_tweets tt
            INNER JOIN r_home_tweets rht ON tt.tweet_id = rht.tweet_id
            WHERE my = ?
            ORDER BY tt.tweet_id DESC
            ''', [my.toString()]);
        setState(() {
            for (int i = 0; i < tweets.length; ++i) {
                Map<String, Object?> tweetObject =  json.decode(tweets[i]['data']) as Map<String, Object?>;
                Map<String, Object?> userObject = tweetObject['user'] as Map<String, Object?>;
                Imager.load(userObject['profile_image_url_https'] as String, (String path) {
                    _tweets.add(
                        Card(
                            child: Row(
                                children: [
                                    Image.file(File(path)),
                                    Column(
                                        children: <Widget>[
                                            Row(
                                                children: [
                                                    RichText(
                                                        overflow: TextOverflow.ellipsis,
                                                        text: TextSpan(
                                                            children: <InlineSpan>[
                                                                TextSpan(text: userObject['name'] as String, style: const TextStyle(color: Colors.black)),
                                                                TextSpan(text: '@' + (userObject['screen_name'] as String), style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.black))
                                                            ],
                                                        )
                                                    ),
                                                    Text(Utility.createFuzzyDateTime(tweetObject['created_at'] as String))
                                                ]
                                            ),
                                            Text(tweetObject['full_text'] as String)
                                        ]
                                    )
                                ]
                            )
                        )
                    );
                });
            }
        });
    }

    Future<void> _entry() async
    {
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
                        await DB.insert(txn, 't_users', [{'user_id': params3['user_id'], 'oauth_token': params3['oauth_token'], 'oauth_token_secret': params3['oauth_token_secret'], 'my': my.toString(), 'data': userJson}]);
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
        _logger.v('[START]initState()');
        super.initState();
        _entry();
        _logger.v('[END]initState()');
    }

    @override
    Widget build(BuildContext context)
    {
        _logger.v('build(${context})');

         return Scaffold(
            appBar: const EmptyAppBar(),
            body: NotificationListener<ScrollNotification> (
                child: ListView.builder(
                    itemCount: _tweets.length,
                    itemBuilder: (context, index) {
                        return _tweets[index];
                    },
                ),
                onNotification: (ScrollNotification notification) {
                    if (notification is OverscrollNotification) {
                        _logger.e(notification);
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
                    await database.rawDelete('DELETE FROM t_tweet_actions');
                    _logger.d('remove... done');
                },
                child: const Icon(Icons.add)
            )
        );
    }
}
