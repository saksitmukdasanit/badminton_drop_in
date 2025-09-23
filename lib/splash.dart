import 'dart:async';
import 'package:flutter/material.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  SplashPageState createState() => SplashPageState();
}

class SplashPageState extends State<SplashPage> {
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

  @override
  Widget build(BuildContext context) {
    return _buildSplash();
  }

  _callRead() async {
    // futureModel = postDio('${server_we_build}m/splash/read', {});
  }

  _callTimer(time) async {
    var _duration = Duration(seconds: time);
    return Timer(_duration, _callNavigatorPage);
  }

  _callNavigatorPage() async {
    // Navigator.of(context).pushAndRemoveUntil(
    //   MaterialPageRoute(builder: (context) => MenuBarPage()),
    //   (Route<dynamic> route) => false,
    // );
  }

  _buildSplash() {
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
              //if no splash from service is return array length 0
              _callTimer(
                (snapshot.data.length > 0
                        ? int.parse(snapshot.data[0]['timeOut']) / 1000
                        : 0)
                    .round(),
              );

              return snapshot.data.length > 0
                  ? Center(
                      child: Image.network(
                        snapshot.data[0]['imageUrl'],
                        fit: BoxFit.fill,
                        height: double.infinity,
                        width: double.infinity,
                      ),
                    )
                  : Container();
            } else if (snapshot.hasError) {
              _callTimer(0);
              return Container();
            } else {
              return Center(child: Container());
            }
          },
        ),
      ),
    );
  }
}
