import 'package:flutter/material.dart';

/// Global RouteObserver — ลงทะเบียนกับ GoRouter ใน `main.dart`
/// แล้ว subscribe จาก StatefulWidget ที่ต้องการรู้ตัวเองตอนถูก push ทับ/กลับมาใหม่
final RouteObserver<ModalRoute<void>> appRouteObserver =
    RouteObserver<ModalRoute<void>>();
