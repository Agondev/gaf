import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:timeago/timeago.dart';

final dioProvider = Provider<Dio>((red) => Dio());

Future<void> main() async {
  await dotenv.load(fileName: 'data.env');
  final container = ProviderContainer();

  final dioRequestHeaders = {
    'Accept': 'application/vnd.github.v3+json',
  };

  final ghAuthKey = dotenv.env['GH_SECRET_KEY2'];

  if (ghAuthKey != null) {
    dioRequestHeaders.putIfAbsent(
      'Authorization',
      () => 'token $ghAuthKey',
    );
  }

  container.read(dioProvider).options = BaseOptions(
    baseUrl: 'https://api.github.com/',
    headers: dioRequestHeaders,
    // validateStatus: (status) => status! < 500,
  );

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Flutter Demo',
        theme: ThemeData.dark(),
        home: const MyApp(),
      ),
    ),
  );
}

class MyApp extends HookConsumerWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final useMemoizerKeys = useState<List<Key>>([UniqueKey()]);
    final useUserLogin = useState<String>('rrousselGit');
    final useGetUserDetailsFuture = useFuture<Response>(
      useMemoized(
        () {
          print('userDetails ${useUserLogin.value}');
          return (ref
                  .watch(dioProvider)
                  .options
                  .headers
                  .containsKey('Authorization'))
              ? ref.watch(dioProvider).get('/user')
              : Future.value(
                  Response(
                    requestOptions: RequestOptions(path: ''),
                    data: {
                      'avatar_url':
                          'https://avatars.githubusercontent.com/in/15368?s=64&v=4',
                      'login': '${useUserLogin.value}',
                    },
                  ),
                );
        },
        useMemoizerKeys.value,
      ),
    );
    final useGetUserReceivedEventsFuture = useFuture<Response>(
      useMemoized(
        () {
          print('userEvents ${useUserLogin.value}');
          return ref
              .watch(dioProvider)
              .get('/users/${useUserLogin.value}/received_events');
        },
        useMemoizerKeys.value,
      ),
    );

    if (useGetUserReceivedEventsFuture.connectionState ==
            ConnectionState.waiting &&
        !useGetUserReceivedEventsFuture.hasData) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (useGetUserReceivedEventsFuture.hasError) {
      ref.watch(dioProvider).options.headers.remove('Authorization');
      useMemoizerKeys.value = [UniqueKey()];
      return Scaffold(
          body: Center(
              child: SingleChildScrollView(
                  child:
                      Text(useGetUserReceivedEventsFuture.error.toString()))));
    }

    if (useGetUserDetailsFuture.hasData) {
      useUserLogin.value = useGetUserDetailsFuture.data!.data['login'];
    }

    final avatar = CircleAvatar(
      radius: 40,
      backgroundImage: NetworkImage(
        useGetUserDetailsFuture.hasData
            ? useGetUserDetailsFuture.data!.data['avatar_url']
            : 'https://avatars.githubusercontent.com/in/15368?s=64&v=4',
      ),
    );

    return Scaffold(
      drawerEdgeDragWidth: 32,
      drawer: Drawer(
        child: Column(
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: Colors.teal.shade700,
              ),
              child: Center(
                child: avatar,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                children: [
                  // TODO make optional either username for only public data
                  // OR key for private as well
                  // AND add this as a separate option to track other users?
                  TextField(
                    decoration: const InputDecoration(hintText: 'Auth Key'),
                    obscureText: true,
                    onChanged: (val) {
                      try {
                        ref.watch(dioProvider).options.headers.update(
                              'Authorization',
                              (value) => 'token $val',
                              ifAbsent: () => 'token $val',
                            );
                        useMemoizerKeys.value = [UniqueKey()];
                      } catch (e) {
                        ref
                            .watch(dioProvider)
                            .options
                            .headers
                            .remove('Authorization');
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.all(10.0),
          child: Builder(
            builder: (context) => IconButton(
              icon: avatar,
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          ),
        ),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              // ignore: lines_longer_than_80_chars
              'Requests left: ${useGetUserReceivedEventsFuture.data!.headers.value('x-ratelimit-remaining')!}',
            ),
          ],
        ),
      ),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          CupertinoSliverRefreshControl(
            onRefresh: () {
              useMemoizerKeys.value = [UniqueKey()];
              return Future<void>.value(null);
            },
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, idx) {
                final datum = useGetUserReceivedEventsFuture.data!.data[idx];
                return Center(
                  child: Card(
                    color: datum['public']
                        ? Colors.green.shade800.withOpacity(.5)
                        : Colors.orange.shade800.withOpacity(.5),
                    child: ExpansionTile(
                      tilePadding: const EdgeInsets.symmetric(
                              vertical: 6, horizontal: 10) +
                          const EdgeInsets.only(left: 12, right: 4),
                      leading: Image.network(
                        datum['actor']['avatar_url'].toString(),
                        height: 36,
                      ),
                      title: RichText(
                        text: TextSpan(
                          children: [
                            const WidgetSpan(
                              child: Icon(Icons.chevron_right),
                              alignment: PlaceholderAlignment.bottom,
                            ),
                            WidgetSpan(
                              child: Icon(
                                datum['payload']['action'].toString() ==
                                        'started'
                                    ? Icons.star
                                    : Icons.help,
                              ),
                            ),
                            const WidgetSpan(
                              child: Icon(Icons.chevron_right),
                              alignment: PlaceholderAlignment.bottom,
                            ),
                            TextSpan(
                              text: datum['repo']['name'].toString().substring(
                                    0,
                                    datum['repo']['name']
                                        .toString()
                                        .indexOf('/'),
                                  ),
                            ),
                          ],
                        ),
                      ),
                      trailing: Text(
                        format(
                          DateTime.parse(
                            datum['created_at'],
                          ),
                        ),
                      ),
                      children: [
                        Card(
                          color: Colors.transparent,
                          child: ListTile(
                            leading: const Text('User'),
                            title: Text(
                              datum['actor']['display_login'].toString(),
                            ),
                          ),
                        ),
                        Card(
                          color: Colors.transparent,
                          child: ListTile(
                            leading: const Text('Repo'),
                            title: Text(
                              datum['repo']['name'].toString(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
              childCount:
                  (useGetUserReceivedEventsFuture.data!.data as List).length,
            ),
          ),
        ],
      ),
    );
  }
}
