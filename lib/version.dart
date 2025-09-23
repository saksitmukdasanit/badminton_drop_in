import 'dart:async';
import 'package:badminton/shared/api_provider.dart';
import 'package:badminton/splash.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

class VersionPage extends StatefulWidget {
  const VersionPage({super.key});

  @override
  VersionPageState createState() => VersionPageState();
}

class VersionPageState extends State<VersionPage> {
  late Future<dynamic> futureModel;

  @override
  void initState() {
    _callRead();
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  _callRead() {
    // if (Platform.isAndroid) {
    //   futureModel = postDio(versionReadApi, {'platform': 'Android'});
    // } else if (Platform.isIOS) {
    //   // print('version');
    //   futureModel = postDio(versionReadApi, {'platform': 'Ios'});
    // }
  }

  _callGoSplash() {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      // add your code here.
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => SplashPage()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          // ป้องกันการกด back
          // หรือ show dialog ก่อนปิด
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: FutureBuilder<dynamic>(
          future: futureModel,
          builder: (BuildContext context, AsyncSnapshot<dynamic> snapshot) {
            if (snapshot.hasData) {
              if (snapshot.data['isActive']) {
                if (versionNumber < snapshot.data['version']) {
                  // print('update');

                  return Center(
                    // child: Container(
                    //   color: Colors.white,
                    //   child: dialogVersion(
                    //     context,
                    //     title: snapshot.data['title'],
                    //     description: snapshot.data['description'],
                    //     isYesNo: !snapshot.data['isForce'],
                    //     callBack: (param) {
                    //       if (param) {
                    //         launch(snapshot.data['url']);
                    //       } else {
                    //         _callGoSplash();
                    //       }
                    //     },
                    //   ),
                    // ),
                  );
                } else {
                  _callGoSplash();
                }
              } else {
                _callGoSplash();
              }
              return Container();
            } else if (snapshot.hasError) {
              _callGoSplash();
              return Container();
            } else {
              return Container();
            }
          },
        ),
      ),
    );
  }
}
