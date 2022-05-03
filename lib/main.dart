import 'package:flutter/material.dart';
import 'screen/home_timeline.dart';

void main()
{
    runApp(
         MaterialApp(
            initialRoute: '/home_timeline',
            routes: <String, WidgetBuilder>{
                '/home_timeline':(BuildContext context) => const HomeTimeline()
            },
            theme: ThemeData(
                primarySwatch: Colors.blue
            ),
        )
    );
}
