import 'dart:async';

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:logger/logger.dart';

class DB
{
    static final Logger _logger = Logger();

    static Future<Database>? _instance;

    static Future<Database> getInstance() async
    {
        _logger.v('getInstance()');
        _instance ??= openDatabase(
            join(await getDatabasesPath(), 'sk.db'),
            version: 1,
            onCreate: ((Database db, int version) {
                db.execute(
                    '''
                        CREATE TABLE t_users(
                            id INTEGER PRIMARY KEY AUTOINCREMENT,

                            user_id INTEGER NOT NULL,               -- ユーザーID
                            oauth_token TEXT DEFAULT NULL,          -- Twitter認証してもらう.NULLなら自分以外
                            oauth_token_secret TEXT DEFAULT NULL,   -- Twitter認証してもらう.NULLなら自分以外
                            my INTEGER DEFAULT NULL,                -- 自分の場合シーケンシャルな番号.他人ならNULL

                            data JSON NOT NULL                      -- ダウンロードされたJSONデータ
                        )
                    '''
                );
                db.execute(
                    '''
                        CREATE UNIQUE INDEX t_users_unique_user_id ON t_users (user_id)
                    '''
                );
                db.execute(
                    '''
                        CREATE UNIQUE INDEX t_users_unique_my ON t_users (my)
                    '''
                );
                db.execute(
                    '''
                        CREATE TABLE t_tweets(
                            id INTEGER PRIMARY KEY AUTOINCREMENT,

                            tweet_id INTEGER NOT NULL,              -- ツィートID
                            reply_tweet_id INTEGER DEFAULT NULL,    -- リプライの場合付与されるオリジナルツィートID
                            user_id INTEGER NOT NULL,               -- ユーザーID

                            data JSON NOT NULL,                     -- ダウンロードされたJSONデータ
                            ogp_card_type INTEGER DEFAULT NULL,     -- OGP CARD SIZE NULL:OPGなし/1:small/2:large
                            ogp_card_desc TEXT DEFAULT NULL,        -- OGP description NULL:OPGなし/NULL以外:ディスクリプション
                            ogp_image_file TEXT DEFAULT NULL        -- OGP image url NULL:イメージなし/NULL以外:画像URL
                        )
                    '''
                );
                db.execute(
                    '''
                        CREATE UNIQUE INDEX t_tweets_unique_tweet_id ON t_tweets (tweet_id)
                    '''
                );
                db.execute(
                    '''
                        CREATE INDEX t_tweets_index_reply_tweet_id ON t_tweets (reply_tweet_id)
                    '''
                );
                db.execute(
                    '''
                        CREATE INDEX t_tweets_index_user_id ON t_tweets (user_id)
                    '''
                );
                db.execute(
                    '''
                        CREATE TABLE r_home_tweets(
                            id INTEGER PRIMARY KEY AUTOINCREMENT,
                            tweet_id INTEGER NOT NULL,              -- ツィートID
                            my INTEGER NOT NULL                     -- シーケンシャルな番号
                        )
                    '''
                );
                db.execute(
                    '''
                        CREATE UNIQUE INDEX r_home_tweets_unique_my_tweet_id ON r_home_tweets (my, tweet_id)
                    '''
                );
            })
        );

        return _instance!;
    }

    static Future<int> insert(Transaction txn, String table, List<Map<String, Object?>> datas)
    {
        Completer<int> computer = Completer<int>();
        List<String?> binding = [];

        String query = 'INSERT INTO ${table}(';
        datas[0].forEach((key, value) {
            query += '${key},';
        });
        query = query.substring(0, query.length - 1);
        query += ')VALUES';
        datas.forEach((Map<String, Object?> element) {
            query += '(';
            element.forEach((key1, value1) {
                query += '?,';
                if (value1 == null) {
                    binding.add(null);
                }
                else {
                    binding.add(value1.toString());
                }
            });
            query = query.substring(0, query.length - 1);
            query += '),';
        });
        query = query.substring(0, query.length - 1);

        txn.rawInsert(query, binding)
        .then((int status) {
            return computer.complete(status);
        });

        return computer.future;
    }
}
