import 'package:flutter/material.dart';

class HomeTimeline extends StatefulWidget
{
    const HomeTimeline({Key? key}) : super(key: key);

    @override
    State<HomeTimeline> createState() => _HomeTimelineState();
}

class _HomeTimelineState extends State<HomeTimeline>
{
    @override
    Widget build(BuildContext context)
    {
         return Scaffold
         (
             floatingActionButton: FloatingActionButton(
                 onPressed: () => null,
                 child: const Icon(Icons.add)
             )
         );
    }
}
