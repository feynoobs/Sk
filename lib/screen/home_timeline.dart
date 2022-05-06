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
                                                _logger.e(json);
                                                return database.rawInsert(
                                                    'INSERT INTO t_users(user_id, oauth_token, oauth_token_secret, my, data, created_at, updated_at) VALUES(?, ?, ?, ?, ?, ?, ?)',
                                                    [authData['user_id'], authData['oauth_token'], authData['oauth_token_secret'], (my + 1).toString(), json, Utility.now(), Utility.now()]
                                                );
                                            })
                                            .then((int status) {
                                                if (status != 0) {
                                                    prefs.setInt('my', my + 1)
                                                        .then((bool retult) {
                                                            _logger.e('OKKKKK!!!!');
                                                        });
                                                }
                                            });
                                    }
                                }
                            });
                        });
                }
                else {
                    Map<String, String> requestData = {
                        'oauth_token': user[0]['oauth_token'] as String,
                        'oauth_token_secret': user[0]['oauth_token_secret'] as String,
                        'count': 200.toString(),
                        'exclude_replies': false.toString(),
                        'contributor_details': false.toString(),
                        'include_rts': true.toString(),
                        'tweet_mode': 'extended'
                    };
                    ApiStatusesHomeTimeline().start(requestData)
                        .then((json) => _logger.e(json));
                }
            });
    }

    @override
    Widget build(BuildContext context)
    {
         return Scaffold(
             appBar: const EmptyAppBar(),
             floatingActionButton: FloatingActionButton(
                 onPressed: () => null,
                 child: const Icon(Icons.add)
             )
         );
    }
}
