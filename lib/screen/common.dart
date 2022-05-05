import 'package:flutter/material.dart';

class EmptyAppBar extends StatelessWidget implements PreferredSizeWidget
{
    const EmptyAppBar({Key? key}) : super(key: key);

    @override
    Widget build(BuildContext context)
    {
        return AppBar(
            elevation: 0,
            title: null,
        );
    }

    @override
    Size get preferredSize => const Size.fromHeight(0.0);
}
