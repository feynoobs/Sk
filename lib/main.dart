import 'package:flutter/material.dart';

import 'screen/home_timeline.dart';
import 'screen/authentication.dart';

void main()
{
    runApp(
         MaterialApp(
            initialRoute: 'home_timeline',
            routes: <String, WidgetBuilder>{
                'home_timeline': (BuildContext context) => const HomeTimeline(),
                'authentication': (BuildContext context) => const Authentication()
            },
            theme: ThemeData(
                primarySwatch: Colors.blue
            ),
        )
    );
}
