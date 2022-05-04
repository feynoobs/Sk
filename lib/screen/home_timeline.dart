import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:logger/logger.dart';

import '../database/db.dart';
import '../api/api_request_token.dart';
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

        late int my;
        SharedPreferences.getInstance()
            .then((SharedPreferences prefs) {
                my = prefs.getInt('my') ?? 0;
                return DB.getInstance();
            })
            .then((Database database) {
                return database.rawQuery('SELECT oauth_token, oauth_token_secret FROM t_users WHERE my = ?', [my.toString()]);
            })
            .then((List<Map<String, Object?>> user) {
                if (user.isEmpty == true) {
                    ApiRequestToken().start({})
                        .then((String query) {
                            Map<String, String> params = Utility.splitQuery(query);
                            Navigator.pushNamed(
                                context,
                                'authentication',
                                arguments: params
                            );
                        });
                }
            });
    }

    @override
    Widget build(BuildContext context)
    {
         return Scaffold(
             floatingActionButton: FloatingActionButton(
                 onPressed: () => null,
                 child: const Icon(Icons.add)
             )
         );
    }
}
