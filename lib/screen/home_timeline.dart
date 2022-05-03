import 'package:flutter/material.dart';
import 'package:logger/logger.dart';

import '../api/api_request_token.dart';

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
        Map<String, String> params = {};
        ApiRequestToken api = ApiRequestToken();
        api.start(params).then((value) => _logger.i('OK'));
    }

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
