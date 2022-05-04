import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DB
{
    static Future<Database>? _instance;

    static Future<Database> getInstance() async
    {
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

                            data JSON NOT NULL,                     -- ダウンロードされたJSONデータ

                            created_at TEXT NOT NULL,
                            updated_at TEXT NOT NULL
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
                        CREATE TABLE t_time_lines(
                            id INTEGER PRIMARY KEY AUTOINCREMENT,

                            tweet_id INTEGER NOT NULL,              -- ツィートID
                            reply_tweet_id INTEGER DEFAULT NULL,    -- リプライの場合付与されるオリジナルツィートID
                            user_id INTEGER NOT NULL,               -- ユーザーID

                            data JSON NOT NULL,                     -- ダウンロードされたJSONデータ
                            ogp_card_type INTEGER DEFAULT NULL,     -- OGP CARD SIZE NULL:OPGなし/1:small/2:large
                            ogp_card_desc TEXT DEFAULT NULL,        -- OGP description NULL:OPGなし/NULL以外:ディスクリプション
                            ogp_image_url TEXT DEFAULT NULL,        -- OGP image url NULL:イメージなし/NULL以外:画像URL

                            created_at TEXT NOT NULL,
                            updated_at TEXT NOT NULL
                        )
                    '''
                );
                db.execute(
                    '''
                        CREATE UNIQUE INDEX t_time_lines_unique_tweet_id ON t_time_lines (tweet_id)
                    '''
                );
                db.execute(
                    '''
                        CREATE INDEX t_time_lines_index_reply_tweet_id ON t_time_lines (reply_tweet_id)
                    '''
                );
                db.execute(
                    '''
                        CREATE INDEX t_time_lines_index_user_id ON t_time_lines (user_id)
                    '''
                );
                db.execute(
                    '''
                        CREATE TABLE r_home_tweets(
                            id INTEGER PRIMARY KEY AUTOINCREMENT,
                            tweet_id INTEGER NOT NULL,              -- ツィートID
                            my INTEGER NOT NULL,                    -- シーケンシャルな番号
                            created_at TEXT NOT NULL,
                            updated_at TEXT NOT NULL
                        )
                    '''
                );
                db.execute(
                    '''
                        CREATE UNIQUE INDEX r_home_tweets_unique_my_tweet_id ON r_home_tweets (my, tweet_id)
                    '''
                );
                db.execute(
                    '''
                        CREATE TABLE t_tweet_actions(
                            id INTEGER PRIMARY KEY AUTOINCREMENT,
                            type INTEGER NOT NULL DEFAULT 1,        -- 1:いいね/2:RT
                            tweet_id INTEGER NOT NULL,              -- ツィートID
                            my INTEGER NOT NULL,                    -- シーケンシャルなユーザー番号
                            created_at TEXT NOT NULL,
                            updated_at TEXT NOT NULL
                        )
                    '''
                );
                db.execute(
                    '''
                        CREATE UNIQUE INDEX t_tweet_actions_unique_my_tweet_id ON t_tweet_actions (my, tweet_id)
                    '''
                );
            })
        );

        return _instance!;
    }
}
