import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gh_trend/gh_trend.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class TrendingRepos extends StatelessWidget {
  const TrendingRepos({
    Key? key,
    required this.trendingRepos,
  }) : super(key: key);

  final List<GithubRepoItem> trendingRepos;

  @override
  Widget build(BuildContext context) {
    if (trendingRepos.isEmpty) {
      return const Center(
        child: CircularProgressIndicator.adaptive(),
      );
    } else {
      return ListView.builder(
        itemCount: trendingRepos.length,
        itemBuilder: (context, index) {
          return ListTile(
            title: Text(trendingRepos[index].repoName),
          );
        },
      );
    }
  }
}
