import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:zpevnik/constants.dart';
import 'package:zpevnik/providers/tags_provider.dart';
import 'package:zpevnik/screens/filters/section.dart';

class FiltersWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.all(kDefaultPadding),
        child: Consumer<TagsProvider>(
          builder: (context, provider, _) => ListView.builder(
            itemCount: provider.sections.length,
            itemBuilder: (context, index) => FiltersSection(
              title: provider.sections[index].title,
              tags: provider.sections[index].tags,
            ),
          ),
        ),
      );
}
