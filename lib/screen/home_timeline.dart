import 'dart:async';
import 'dart:convert';

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

    Future<void> _getHomeTimeline()
    {
        Completer<void> computer = Completer<void>();
        late SharedPreferences prefs;
        late Database database;

        SharedPreferences.getInstance()
        .then((SharedPreferences p) {
            prefs = p;
            return DB.getInstance();
        })
        .then((Database db) {
            int my = prefs.getInt('my') ?? 0;
            database = db;
            return db.rawQuery('SELECT oauth_token, oauth_token_secret FROM t_users WHERE my = ?', [my.toString()]);
        })
        .then((List<Map<String, Object?>> user) {
            if (user.isNotEmpty == true) {
                Map<String, String> requestData = {
                    'oauth_token': user[0]['oauth_token'] as String,
                    'oauth_token_secret': user[0]['oauth_token_secret'] as String,
                    'count': 1.toString(),
                    'exclude_replies': false.toString(),
                    'contributor_details': false.toString(),
                    'include_rts': true.toString(),
                    'tweet_mode': 'extended'
                };
                ApiStatusesHomeTimeline().start(requestData)
                .then((String jsonString) {
                    List<dynamic> jsonObject = json.decode(jsonString);
                    List<Map<String, Object?>> datas = [];
                    jsonObject.forEach((element) {
                        Map<String, Object?> data = {};
                        data['tweet_id'] = element['id'];
                        data['user_id'] = element['user']['id'];
                        data['data'] = json.encode(element);
                        data['reply_tweet_id'] = element['in_reply_to_user_id'];
                        datas.add(data);
                    });
                    database.transaction((Transaction txn) {
                        Completer<void> txnComputer = Completer<void>();
                        DB.insert(txn, 't_time_lines', datas)
                        .then((int status1) {
                            if (status1 != 0) {
                                List<Map<String, Object?>> datas = [];
                                jsonObject.forEach((element) {
                                    Map<String, Object?> data = {};
                                    data['tweet_id'] = element['id'];
                                    data['my'] = prefs.getInt('my') ?? 0;
                                    datas.add(data);
                                });
                                DB.insert(txn, 'r_home_tweets', datas)
                                .then((int status2) {
                                    if (status2 != 0) {
                                        return txnComputer.complete();
                                    }
                                });
                            }
                        });

                        return txnComputer.future;
                    });
                });
            }
        });

        return computer.future;
    }

    void _displayHomeTimeline()
    {
        late SharedPreferences prefs;

        SharedPreferences.getInstance()
        .then((SharedPreferences p) {
            prefs = p;
            return DB.getInstance();
        })
        .then((Database database) {
            int my = prefs.getInt('my') ?? 0;
            return database.rawQuery('''
                SELECT ttl.*
                FROM t_time_lines ttl
                INNER JOIN r_home_tweets rht ON ttl.tweet_id = rht.tweet_id
                WHERE my = ?
                ORDER BY ttl.tweet_id DESC
                ''', [my.toString()]);
        })
        .then((List<Map<String, dynamic>> tweets) {
            setState(() {
                tweets.forEach((Map<String, dynamic> tweet) {
                    _logger.e(tweet);
                    _tweets.add(_memuItem(tweet['id'] as int, 0, tweet['data']));
                });
            });
        });
    }

    Widget _memuItem(int id, int myUserId, String jsonString)
    {
        Map<String, Object?> tweetObject = json.decode(jsonString);
        Map<String, Object?> userObject = tweetObject['user'] as Map<String, Object?>;
        _logger.e(tweetObject['created_at']);
        return Card(
            child: Column(
                children: <Widget>[
                    Row(
                        children: <Widget>[
                            Column(
                                children: <Widget>[
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
                            )
                        ]
                    )
                ],
            )
        );
    }

    @override
    void initState()
    {
        super.initState();

        late Database database;
        late SharedPreferences prefs;

        SharedPreferences.getInstance()
        .then((SharedPreferences p) {
            prefs = p;
            return DB.getInstance();
        })
        .then((Database db) {
            int my = prefs.getInt('my') ?? 0;
            database = db;
            return db.rawQuery('SELECT oauth_token, oauth_token_secret FROM t_users WHERE my = ?', [my.toString()]);
        })
        .then((List<Map<String, Object?>> user) {
            if (user.isEmpty == true) {
                late Map<String, String> authData;
                int my = prefs.getInt('my') ?? 0;

                ApiRequestToken().start({})
                .then((String query) {
                    Map<String, String> params = Utility.splitQuery(query);

                    return Navigator.pushNamed(
                        context,
                        'authentication',
                        arguments: params
                    )
                    .then((dynamic callback) {
                        // nullが帰ってくることがある
                        if (callback != null) {
                            String query2 = (callback as String).replaceAll('${ApiCommon.CALLBACK_URL}?', '');
                            Map<String, String> params2 = Utility.splitQuery(query2);
                            // 認証拒否された場合は処理しない
                            // 拒否されたばあい「denied」が付与されるので否定
                            if (params2.containsKey('denied') == false) {
                                params2['oauth_token_secret'] = params['oauth_token_secret']!;
                                _logger.e(params2);
                                ApiAccessToken().start(params2)
                                .then((String query3) {
                                    Map<String, String> params3 = Utility.splitQuery(query3);
                                    authData = params3;
                                    Map<String, String> userData = {'oauth_token': params3['oauth_token']!, 'oauth_token_secret': params3['oauth_token_secret']!, 'user_id': params3['user_id']!};

                                    return ApiUsersShow().start(userData);
                                })
                                .then((String json) {
                                    return database.rawInsert(
                                        'INSERT INTO t_users(user_id, oauth_token, oauth_token_secret, my, data) VALUES(?, ?, ?, ?, ?)',
                                        [authData['user_id'], authData['oauth_token'], authData['oauth_token_secret'], (my + 1).toString(), json]
                                    );
                                })
                                .then((int status) {
                                    if (status != 0) {
                                        prefs.setInt('my', my + 1)
                                        .then((bool retult) {
                                            if (retult == true) {
                                                _getHomeTimeline()
                                                .then((_) {
                                                    _displayHomeTimeline();
                                                });
                                            }
                                        });
                                    }
                                });
                            }
                        }
                    });
                });
            }
            else {
                _displayHomeTimeline();
            }
        });
    }

    @override
    Widget build(BuildContext context)
    {
         return Scaffold(
             appBar: const EmptyAppBar(),
             body: ListView(
                 children: _tweets,
             ),
             floatingActionButton: FloatingActionButton(
                 onPressed: () async {
                    Database database = await DB.getInstance();
                    await database.rawDelete('DELETE FROM t_users');
                    await database.rawDelete('DELETE FROM t_time_lines');
                    await database.rawDelete('DELETE FROM r_home_tweets');
                    await database.rawDelete('DELETE FROM t_tweet_actions');
                    _logger.d('remove... done');
                 },
                 child: const Icon(Icons.add)
             )
         );
    }
}
