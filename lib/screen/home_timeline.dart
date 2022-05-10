import 'dart:async';
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

    Future<void> _getNextPrevTimeline()
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
                int my = prefs.getInt('my') ?? 0;
                database.rawQuery('SELECT MIN(tweet_id) as min_id FROM r_home_tweets WHERE my = ?', [my.toString()])
                .then((List<Map<String, Object?>> tweets) {
                    Map<String, String> requestData = {
                        'oauth_token': user[0]['oauth_token'] as String,
                        'oauth_token_secret': user[0]['oauth_token_secret'] as String,
                        'count': 10.toString(),
                        'exclude_replies': false.toString(),
                        'contributor_details': false.toString(),
                        'include_rts': true.toString(),
                        'tweet_mode': 'extended'
                    };
                    if (tweets[0]['min_id'] != null) {
                        int min = int.parse(tweets[0]['min_id'] as String);
                        requestData['max_id'] = (min - 1).toString();
                    }
                    ApiStatusesHomeTimeline().start(requestData)
                    .then((String jsonString) {
                        List<dynamic> jsonObject = json.decode(jsonString);
                        List<Map<String, Object?>> datas = [];
                        for (int i = 0; i < jsonObject.length; ++i) {
                            Map<String, Object?> data = {};
                            data['tweet_id'] = jsonObject[i]['id'];
                            data['user_id'] = jsonObject[i]['user']['id'];
                            data['data'] = json.encode(jsonObject[i]);
                            data['reply_tweet_id'] = jsonObject[i]['in_reply_to_user_id'];
                            datas.add(data);
                        }
                        database.transaction((Transaction txn) {
                            Completer<void> txnComputer = Completer<void>();
                            DB.insert(txn, 't_tweets', datas)
                            .then((int status1) {
                                if (status1 != 0) {
                                    List<Map<String, Object?>> datas = [];
                                    for (int i = 0; i < jsonObject.length; ++i) {
                                        Map<String, Object?> data = {};
                                        data['tweet_id'] = jsonObject[i]['id'];
                                        data['my'] = prefs.getInt('my') ?? 0;
                                        datas.add(data);
                                    }
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

                        return computer.complete();
                    });
                });
            }
        });

        return computer.future;
    }

    Future<void> _getNextHomeTimeline()
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
                int my = prefs.getInt('my') ?? 0;
                database.rawQuery('SELECT MAX(tweet_id) as max_id FROM r_home_tweets WHERE my = ?', [my.toString()])
                .then((List<Map<String, Object?>> tweets) {
                    Map<String, String> requestData = {
                        'oauth_token': user[0]['oauth_token'] as String,
                        'oauth_token_secret': user[0]['oauth_token_secret'] as String,
                        'count': 10.toString(),
                        'exclude_replies': false.toString(),
                        'contributor_details': false.toString(),
                        'include_rts': true.toString(),
                        'tweet_mode': 'extended'
                    };
                    if (tweets[0]['max_id'] != null) {
                        requestData['since_id'] = tweets[0]['max_id'].toString();
                    }
                    ApiStatusesHomeTimeline().start(requestData)
                    .then((String jsonString) {
                        List<dynamic> jsonObject = json.decode(jsonString);
                        List<Map<String, Object?>> datas = [];
                        for (int i = 0; i < jsonObject.length; ++i) {
                            Map<String, Object?> data = {};
                            data['tweet_id'] = jsonObject[i]['id'];
                            data['user_id'] = jsonObject[i]['user']['id'];
                            data['data'] = json.encode(jsonObject[i]);
                            data['reply_tweet_id'] = jsonObject[i]['in_reply_to_user_id'];
                            datas.add(data);
                        }
                        database.transaction((Transaction txn) {
                            Completer<void> txnComputer = Completer<void>();
                            DB.insert(txn, 't_tweets', datas)
                            .then((int status1) {
                                if (status1 != 0) {
                                    List<Map<String, Object?>> datas = [];
                                    for (int i = 0; i < jsonObject.length; ++i) {
                                        Map<String, Object?> data = {};
                                        data['tweet_id'] = jsonObject[i]['id'];
                                        data['my'] = prefs.getInt('my') ?? 0;
                                        datas.add(data);
                                    }
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

                        return computer.complete();
                    });
                });
            }
        });

        return computer.future;
    }

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
                    'count': 10.toString(),
                    'exclude_replies': false.toString(),
                    'contributor_details': false.toString(),
                    'include_rts': true.toString(),
                    'tweet_mode': 'extended'
                };
                ApiStatusesHomeTimeline().start(requestData)
                .then((String jsonString) {
                    List<dynamic> jsonObject = json.decode(jsonString);
                    List<Map<String, Object?>> datas = [];
                    for (int i = 0; i < jsonObject.length; ++i) {
                        Map<String, Object?> data = {};
                        data['tweet_id'] = jsonObject[i]['id'];
                        data['user_id'] = jsonObject[i]['user']['id'];
                        data['data'] = json.encode(jsonObject[i]);
                        data['reply_tweet_id'] = jsonObject[i]['in_reply_to_user_id'];
                        datas.add(data);
                    }
                    database.transaction((Transaction txn) {
                        Completer<void> txnComputer = Completer<void>();
                        DB.insert(txn, 't_tweets', datas)
                        .then((int status1) {
                            if (status1 != 0) {
                                List<Map<String, Object?>> datas = [];
                                for (int i = 0; i < jsonObject.length; ++i) {
                                    Map<String, Object?> data = {};
                                    data['tweet_id'] = jsonObject[i]['id'];
                                    data['my'] = prefs.getInt('my') ?? 0;
                                    datas.add(data);
                                }
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
                    return computer.complete();
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
                SELECT tt.*
                FROM t_tweets tt
                INNER JOIN r_home_tweets rht ON tt.tweet_id = rht.tweet_id
                WHERE my = ?
                ORDER BY tt.tweet_id DESC
                ''', [my.toString()]);
        })
        .then((List<Map<String, dynamic>> tweets) {
            setState(() {
                for (int i = 0; i < tweets.length; ++i) {
                    _logger.e(tweets[i]);
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
        });
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
