import 'dart:async';
import 'dart:io';

import 'package:badminton/component/app_bar.dart';
import 'package:badminton/component/button.dart';
import 'package:badminton/component/dialog.dart';
import 'package:badminton/component/dropdown.dart';
import 'package:badminton/component/image_picker.dart';
import 'package:badminton/component/text_box.dart';
import 'package:badminton/shared/api_provider.dart';
import 'package:badminton/shared/function.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_places_flutter/google_places_flutter.dart';
import 'package:intl/intl.dart';

class AddGamePage extends StatefulWidget {
  final String code;
  final Object? extra; // รับข้อมูล extra (sessionData, initialDate)
  const AddGamePage({super.key, required this.code, this.extra});

  @override
  AddGamePageState createState() => AddGamePageState();
}

class AddGamePageState extends State<AddGamePage> {
  // --- ประกาศ Controllers ทั้งหมด ---
  final FocusNode _courtSearchFocusNode = FocusNode();
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _teamNameController;
  late final TextEditingController _dateController;
  late final TextEditingController _startTimeController;
  late final TextEditingController _endTimeController;
  late final TextEditingController _slotsController;
  late final TextEditingController _shuttlePriceController;
  late final TextEditingController _shuttleCostController;
  late final TextEditingController _courtPriceController;
  late final TextEditingController _courtTotalCostController;
  late final TextEditingController _openCourtsController;
  late final TextEditingController _notesController;

  // --- ตัวแปรสำหรับจัดการ State อื่นๆ ---
  String? _selectedGameType;
  String? _selectedQueueType;
  String? _selectedShuttleBrand;
  String? _selectedShuttleModel;
  int? _shuttleChargeMethod = 1; // 1 = เก็บเพิ่ม, 2 = บุฟเฟ่ต์
  final List<TextEditingController> _courtNumberControllers = [];

  final TextEditingController _courtSearchController = TextEditingController();
  // คุณอาจจะต้องสร้าง Model เพื่อเก็บข้อมูลสถานที่ที่สมบูรณ์กว่านี้
  Map<String, dynamic>? _selectedPlace;

  bool _isLoading = true;
  List<dynamic> _gameTypes = [];
  List<dynamic> _pairingMethods = [];
  List<dynamic> _shuttleBrands = [];
  List<dynamic> _shuttleModels = [];
  List<dynamic> _facilitiesFromApi = [];
  Map<String, bool> _facilities = {};

  final List<dynamic> _gameImages = [];

  @override
  void initState() {
    _teamNameController = TextEditingController();
    _dateController = TextEditingController();
    _startTimeController = TextEditingController();
    _endTimeController = TextEditingController();
    _slotsController = TextEditingController();
    _shuttlePriceController = TextEditingController();
    _shuttleCostController = TextEditingController();
    _courtPriceController = TextEditingController();
    _courtTotalCostController = TextEditingController();
    _openCourtsController = TextEditingController();
    _notesController = TextEditingController();
    _courtSearchFocusNode.addListener(_onCourtSearchFocusChange);
    super.initState();
    // ย้ายการเรียก API ไปหลัง build เฟรมแรก เพื่อความปลอดภัย
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchMasterData();
    });
  }

  @override
  void dispose() {
    // --- Dispose Controllers ทั้งหมด ---
    _teamNameController.dispose();
    _dateController.dispose();
    _startTimeController.dispose();
    _endTimeController.dispose();
    _slotsController.dispose();
    _shuttlePriceController.dispose();
    _shuttleCostController.dispose();
    _courtPriceController.dispose();
    _courtTotalCostController.dispose();
    _openCourtsController.dispose();
    _notesController.dispose();
    _courtSearchFocusNode.removeListener(_onCourtSearchFocusChange);
    _courtSearchFocusNode.dispose();
    for (final controller in _courtNumberControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _onCourtSearchFocusChange() {
    if (_courtSearchFocusNode.hasFocus) {
      // หน่วงเวลาเล็กน้อยเพื่อให้คีย์บอร์ดขึ้นมาก่อน
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted && _courtSearchFocusNode.context != null) {
          // สั่งให้เลื่อนหน้าจอเพื่อให้แน่ใจว่าช่องค้นหาสนามมองเห็นได้
          Scrollable.ensureVisible(
            _courtSearchFocusNode.context!,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            alignment: 0.1, // เลื่อนให้ช่องอยู่เหนือคีย์บอร์ดเล็กน้อย
          );
        }
      });
    }
  }

  Future<void> _fetchMasterData() async {
    try {
      // ใช้ Future.wait เพื่อเรียก API ทั้งหมดพร้อมกัน
      final responses = await Future.wait([
        ApiProvider().get('/Dropdowns/gametypes').catchError((_) => []),
        ApiProvider().get('/Dropdowns/pairingmethods').catchError((_) => []),
        ApiProvider().get('/Dropdowns/shuttlecockbrands').catchError((_) => []),
        ApiProvider().get('/Dropdowns/facilities').catchError((_) => []),
        // ถ้าเป็นการแก้ไข (code != 'new') ให้ดึงข้อมูลเกมมาด้วย
        if (widget.code != 'new')
          ApiProvider().get('/GameSessions/${widget.code}').catchError((_) => null),
      ]).timeout(const Duration(seconds: 10), onTimeout: () {
        throw TimeoutException('การเชื่อมต่อหมดเวลา');
      });


      // นำข้อมูล Master Data มาใส่ใน State
      if (!mounted) return;
      setState(() {
        _gameTypes = (responses[0] as List?) ?? [];
        _pairingMethods = (responses[1] as List?) ?? [];
        _shuttleBrands = (responses[2] as List?) ?? [];
        _facilitiesFromApi = (responses[3] as List?) ?? [];
        _facilities = {
          for (var item in _facilitiesFromApi)
            if (item['value'] != null) // ป้องกัน key เป็น null
              item['value']: false,
        };
      });

      // --- เตรียมข้อมูลที่จะนำมาแสดง (Game Data) ---
      dynamic rawGameData; // ใช้ dynamic เพื่อรับค่าก่อน ป้องกัน Cast Error

      // กรณี 1: แก้ไข (Edit) - ดึงจาก API
      if (widget.code != 'new' && responses.length > 4) {
        final responseData = responses[4];
        if (responseData is Map) {
          rawGameData = responseData['data'];
        }
      }
      // กรณี 2: สร้างใหม่จากประวัติ (New from History) - ดึงจาก extra
      else if (widget.code == 'new' && widget.extra != null) {
        // ใช้การตรวจสอบและ Cast แบบปลอดภัยป้องกัน Error
        if (widget.extra is Map) {
          // ดึงค่าออกมาตรงๆ โดยไม่ Cast เป็น Map<String, dynamic> ทันที
          rawGameData = (widget.extra as Map)['sessionData'];
        }
      }

      if (rawGameData != null && rawGameData is Map) {
        // แปลงเป็น Map<String, dynamic> อย่างปลอดภัย (ป้องกัน Type Error)
        final Map<String, dynamic> data = Map<String, dynamic>.from(rawGameData);
        
        final shuttlecockModelId = data['shuttlecockModelId']?.toString();

        // --- NEW: โหลดข้อมูลรุ่นลูกแบดแบบ Background (ไม่รอ await) ---
        // เพื่อป้องกันหน้าจอค้างถ้า API นี้ตอบช้า
        if (data['shuttlecockBrandId'] != null) {
          _callReadShuttlecockmodels(
            data['shuttlecockBrandId']?.toString(),
            initialModelId: shuttlecockModelId, // ส่ง ID ไปตั้งค่าทีหลัง
          );
        }

        if (!mounted) return;
        setState(() {
          _teamNameController.text = data['groupName'] ?? '';
          // _courtSearchController.text = data['courtName'] ?? '';

          // --- จัดการวันที่ (Date) ---
          // ถ้ามี initialDate ส่งมา (จาก Logic วันถัดไป) ให้ใช้ค่าใหม่
          if (widget.extra != null && widget.extra is Map) {
            final extraMap = widget.extra as Map;
            if (extraMap['initialDate'] != null && extraMap['initialDate'] is DateTime) {
              final DateTime initDate = extraMap['initialDate'];
              _dateController.text = DateFormat('dd/MM/yyyy').format(initDate);
            } else {
              _dateController.text = _formatDateForDisplay(data['sessionDate']);
            }
          } else {
            // ถ้าไม่มี ให้ใช้ค่าเดิมจาก sessionData (ต้องแปลง format)
            _dateController.text = _formatDateForDisplay(data['sessionDate']);
          }

          // --- จัดการเวลา (Time) ---
          // ตัดวินาทีออกถ้ามี (HH:mm:ss -> HH:mm)
          if (data['startTime'] != null) {
            _startTimeController.text =
                _formatTimeForDisplay(data['startTime']);
          }
          if (data['endTime'] != null) {
            _endTimeController.text =
                _formatTimeForDisplay(data['endTime']);
          }

          // --- Validate Dropdown Values ---
          // ตรวจสอบว่าค่าที่ได้มา มีอยู่ในรายการ Master Data หรือไม่ ถ้าไม่มีให้เป็น null
          _selectedGameType = data['gameTypeId']?.toString();
          if (!_checkItemExists(_gameTypes, _selectedGameType)) _selectedGameType = null;

          _slotsController.text =
              data['maxParticipants']?.toString() ?? '';
          
          _selectedQueueType = data['pairingMethodId']?.toString();
          if (!_checkItemExists(_pairingMethods, _selectedQueueType)) _selectedQueueType = null;

          _shuttleChargeMethod = data['costingMethod'];
          _shuttlePriceController.text =
              data['shuttlecockFeePerPerson']?.toString() ?? '';
          _shuttleCostController.text =
              data['shuttlecockCostPerUnit']?.toString() ?? '';
          _selectedShuttleBrand = data['shuttlecockBrandId']?.toString();
          
          // ถ้าไม่มี Brand (ไม่ได้โหลดรุ่น) ให้ใส่ค่าเลย แต่ถ้ามี Brand ให้รอ _callReadShuttlecockmodels จัดการ
          if (data['shuttlecockBrandId'] == null) {
             _selectedShuttleModel = shuttlecockModelId;
          }

          _courtPriceController.text =
              data['courtFeePerPerson']?.toString() ?? '';
          _courtTotalCostController.text =
              data['totalCourtCost']?.toString() ?? '';
          _openCourtsController.text =
              data['numberOfCourts']?.toString() ?? '';
          _notesController.text = data['notes'] ?? '';
          if (data['photoUrls'] is List) {
            _gameImages.addAll(List<String>.from(data['photoUrls']));
          }

          // --- ส่วนที่เพิ่ม: ดึงข้อมูล VenueData มาใส่ใน _selectedPlace ---
          if (data['venueData'] != null) {
            final venue = data['venueData'];
            _courtSearchController.text = venue['name'] ?? '';
            _selectedPlace = {
              'placeId': venue['googlePlaceId'],
              'name': venue['name'],
              'address': venue['address'],
              'lat': venue['latitude']?.toString(),
              'lng': venue['longitude']?.toString(),
            };
          }

          // --- ส่วนที่เพิ่ม: ดึงข้อมูล Facilities ที่เลือกไว้ ---
          if (data['facilityIds'] is List) {
            final List<int> selectedFacilityIds = List<int>.from(
              data['facilityIds'],
            );
            for (var facility in _facilitiesFromApi) {
              if (selectedFacilityIds.contains(facility['code'])) {
                _facilities[facility['value']] = true;
              }
            }
          }

          // --- ส่วนที่เพิ่ม: ดึงข้อมูล Court Numbers (รวมใน setState เลย) ---
          if (data['courtNumbers'] is String) {
            final String courtNums = data['courtNumbers'];
            final int count = int.tryParse(data['numberOfCourts']?.toString() ?? '0') ?? 0;
            
            // เคลียร์และสร้าง Controller ใหม่
            for (var controller in _courtNumberControllers) {
              controller.dispose();
            }
            _courtNumberControllers.clear();

            final List<String> values = courtNums.split(',');
            for (int i = 0; i < count; i++) {
              final initialText = i < values.length ? values[i] : '';
              _courtNumberControllers.add(TextEditingController(text: initialText));
            }
          }
        });
      }
    } catch (e, stacktrace) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red,
            content: Text('ไม่สามารถดึงข้อมูล Master Data ได้: $e'),
          ),
        );
      }
    } finally {
      // เมื่อโหลดข้อมูลเสร็จสิ้น (ทั้งสำเร็จและล้มเหลว) ให้ปิด loading
      if (mounted) {
        // เพิ่ม delay เล็กน้อยเพื่อให้แน่ใจว่า UI พร้อม render
        await Future.delayed(const Duration(milliseconds: 100));
        setState(() => _isLoading = false);
        
      }
    }
  }

  // Helper function เพื่อเช็คว่าค่ามีใน Dropdown list หรือไม่
  bool _checkItemExists(List<dynamic> items, String? value) {
    if (value == null) return false;
    // สมมติว่า items เป็น List<Map> และมี key 'value' หรือ 'id'
    // ปรับแก้ตามโครงสร้างจริงของ API Dropdown
    return items.any((item) => item['value'].toString() == value || item['id'].toString() == value || item['code'].toString() == value);
  }

  // เพิ่ม parameter initialModelId เพื่อตั้งค่าหลังจากโหลดเสร็จ
  Future<void> _callReadShuttlecockmodels(dynamic shuttlecockbrandsId, {String? initialModelId}) async {
    try {
      final responses = await ApiProvider().get(
        '/Dropdowns/shuttlecockmodels?brandId=${shuttlecockbrandsId.toString()}',
      ).timeout(const Duration(seconds: 10)); // เพิ่ม Timeout กันเหนียว

      if (mounted) {
        setState(() {
          if (responses is List) {
            _shuttleModels = responses;
          } else {
            _shuttleModels = [];
          }
          // ตั้งค่ารุ่นลูกแบดหลังจากโหลดรายการเสร็จแล้ว
          if (initialModelId != null) {
            _selectedShuttleModel = initialModelId;
          }
        });
      }
    } catch (e) {
    }
  }

  void _updateCourtFields(String value, [String? initialValues]) {
    // แปลง String ที่รับเข้ามาเป็น int (ถ้าแปลงไม่ได้ให้เป็น 0)
    final int count = int.tryParse(value) ?? 0;

    // ถ้าจำนวนเท่าเดิม ไม่ต้องทำอะไร
    if (count == _courtNumberControllers.length && initialValues == null)
      return;

    if (!mounted) return;
    setState(() {
      // เคลียร์ controller เก่าทั้งหมดเพื่อป้องกันปัญหา
      for (var controller in _courtNumberControllers) {
        controller.dispose();
      }
      _courtNumberControllers.clear();

      // แยก initialValues ถ้ามี
      final List<String> values = initialValues?.split(',') ?? [];

      // กรณีที่จำนวนที่กรอก > จำนวนช่องปัจจุบัน -> ให้สร้างเพิ่ม
      for (int i = 0; i < count; i++) {
        final initialText = i < values.length ? values[i] : '';
        _courtNumberControllers.add(TextEditingController(text: initialText));
      }
    });
  }

  // ---  สร้างฟังก์ชันสำหรับเลือกวัน ---
  Future<void> _selectDate(TextEditingController controller) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(), // วันที่แรกที่เลือกได้คือวันนี้
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      // จัดรูปแบบวันที่แล้วนำไปใส่ใน Controller
      final String formattedDate = DateFormat('dd/MM/yyyy').format(picked);
      setState(() {
        controller.text = formattedDate;
      });
    }
  }

  // ---  สร้างฟังก์ชันสำหรับเลือกเวลา ---
  Future<void> _selectTime(TextEditingController controller) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      // จัดรูปแบบเวลาแล้วนำไปใส่ใน Controller
      final String formattedTime = picked.format(context);
      setState(() {
        controller.text = formattedTime;
      });
    }
  }

  String _formatDateForApi(String date) {
    try {
      final inputFormat = DateFormat('dd/MM/yyyy');
      final outputFormat = DateFormat('yyyy-MM-dd');
      final dateTime = inputFormat.parse(date);
      return outputFormat.format(dateTime);
    } catch (e) {
      return DateFormat('yyyy-MM-dd').format(DateTime.now());
    }
  }

  // แปลงจาก "HH:mm" (24-hour) หรือ "h:mm a" (12-hour AM/PM) ไปเป็น "HH:mm"
  String _formatTimeForApi(String time) {
    try {
      // ลองแปลงจาก h:mm a (เช่น 6:30 PM) ก่อน
      final inputFormat12Hour = DateFormat('h:mm a');
      final dateTime = inputFormat12Hour.parse(time);
      return DateFormat('HH:mm').format(dateTime);
    } catch (e) {
      try {
        // ถ้าไม่สำเร็จ ลองแปลงจาก HH:mm (เช่น 18:30)
        final inputFormat24Hour = DateFormat('HH:mm');
        final dateTime = inputFormat24Hour.parse(time);
        return DateFormat('HH:mm').format(dateTime);
      } catch (e) {
        // ถ้าแปลงไม่ได้เลย ให้คืนค่าเวลาปัจจุบัน
        return DateFormat('HH:mm').format(DateTime.now());
      }
    }
  }

  // แปลงจาก yyyy-MM-dd (API) เป็น dd/MM/yyyy (Display)
  String _formatDateForDisplay(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '';
    try {
      final DateTime date = DateTime.parse(dateStr);
      return DateFormat('dd/MM/yyyy').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  // แปลงจาก HH:mm:ss (API) เป็น HH:mm (Display)
  String _formatTimeForDisplay(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) return '';
    try {
      final parts = timeStr.split(':');
      if (parts.length >= 2) return '${parts[0]}:${parts[1]}';
      return timeStr;
    } catch (e) {
      return timeStr;
    }
  }

  Future<void> _onImagePicked(List<File> imageFile) async {
    // จำกัดให้มีรูปได้ไม่เกิน 5 รูป
    if (_gameImages.length >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('อัปโหลดรูปภาพได้สูงสุด 5 รูป')),
      );
      return;
    }

    try {
      final response = await ApiProvider().uploadFiles(
        files: imageFile,
        folderName: "Game",
      );

      if (response is List && response.isNotEmpty) {
        if (mounted) {
          setState(() {
            for (var r in response) {
              _gameImages.add(r['imageUrl']);
            }
          });
        }
      } else {
        if (mounted) {
          final errorMessage =
              (response is Map ? response['message'] : null) ?? 'เกิดข้อผิดพลาดไม่ทราบสาเหตุ';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Colors.orange,
              content: Text(errorMessage),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red,
            content: Text(e.toString().replaceFirst('Exception: ', '')),
          ),
        );
      }
    }
  }

  // --- NEW: ฟังก์ชันสำหรับลบรูปภาพ ---
  void _removeImage(int index) {
    setState(() {
      _gameImages.removeAt(index);
    });
  }

  Future<void> _submitForm() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_selectedPlace == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('กรุณาเลือกสนามจากรายการค้นหา')));
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // (ส่วนนี้ต้องแน่ใจว่า _facilities ถูกสร้างจาก API ที่มี 'code' และ 'value')
      final List<int> facilityIds = [];
      _facilities.forEach((key, value) {
        if (value == true) {
          // ถ้า Checkbox ถูกเลือก
          // หา item ที่มี value ตรงกับ key แล้วดึง code (ID) ออกมา
          // (โค้ดนี้อาจจะต้องปรับแก้ตามโครงสร้างข้อมูล facilities ของคุณ)
          final facility = _facilitiesFromApi.firstWhere(
            (f) => f['value'] == key,
            orElse: () => null,
          );
          if (facility != null) {
            facilityIds.add(facility['code']);
          }
        }
      });

      setState(() {});
      // --- 2. รวบรวมข้อมูลทั้งหมดเพื่อส่งให้ API ---
      final Map<String, dynamic> gameData = {
        "groupName": _teamNameController.text,
        "venueData": {
          "googlePlaceId": _selectedPlace!['placeId'],
          "name": _selectedPlace!['name'],
          "address": _selectedPlace!['address'],
          "latitude": _selectedPlace!['lat'],
          "longitude": _selectedPlace!['lng'],
        },
        "sessionDate": _formatDateForApi(_dateController.text),
        "startTime": _formatTimeForApi(_startTimeController.text),
        "endTime": _formatTimeForApi(_endTimeController.text),
        "gameTypeId": int.tryParse(_selectedGameType ?? '0'),
        "pairingMethodId": int.tryParse(_selectedQueueType ?? '0'),
        "maxParticipants": int.tryParse(_slotsController.text),
        "costingMethod":
            _shuttleChargeMethod, // สมมติว่า 1 = PER_UNIT, 2 = BUFFET
        "courtFeePerPerson": double.tryParse(_courtPriceController.text),
        "shuttlecockFeePerPerson": double.tryParse(
          _shuttlePriceController.text,
        ),
        "totalCourtCost": double.tryParse(_courtTotalCostController.text),
        "shuttlecockCostPerUnit": double.tryParse(_shuttleCostController.text),
        "shuttlecockModelId": int.tryParse(_selectedShuttleModel ?? '0'),
        "numberOfCourts": int.tryParse(_openCourtsController.text),
        "courtNumbers": _courtNumberControllers
            .map((c) => c.text)
            .join(','), // รวมเป็น String
        "notes": _notesController.text,
        "facilityIds": facilityIds, // << ใช้ List ของ ID ที่แปลงแล้ว
        "photoUrls": _gameImages,
      };

      // --- 3. เรียก API (POST สำหรับสร้างใหม่, PUT สำหรับแก้ไข) ---
      if (widget.code == 'new') {
        await ApiProvider().post('/GameSessions', data: gameData);
      } else {
        await ApiProvider().put('/GameSessions/${widget.code}', data: gameData);
      }

      // 4. ถ้าสำเร็จ แสดง Dialog
      if (mounted) {
        final isEditing = widget.code != 'new';
        showDialogMsg(
          context,
          title: isEditing ? 'แก้ไขก๊วนเรียบร้อย' : 'สร้างก๊วนใหม่เรียบร้อย',
          subtitle: isEditing
              ? 'ยืนยันการแก้ไข ${_teamNameController.text}'
              : 'ยืนยันการสร้าง ${_teamNameController.text}',
          btnLeft: 'ไปหน้าข้อมูลก๊วน',
          onConfirm: () {
            context.pop(); // ปิด Dialog
            context.pop(true); // กลับไปหน้าก่อนหน้า พร้อมส่งค่า true กลับไป
          },
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red,
            content: Text('สร้างก๊วนล้มเหลว: $e'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.code != 'new';
    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.white,
      appBar: AppBarSubMain(
        title: isEditing ? 'Edit Game' : 'New Game',
        isBack: true,
      ),
      body: Container(
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFFFFFF), Color(0xFFD5DCF4)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Container(
                    padding: const EdgeInsets.all(16.0),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16.0),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          spreadRadius: 2,
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          if (constraints.maxWidth > 600) {
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: _buildLeftColumn(context)),
                                const SizedBox(width: 24),
                                Expanded(child: _buildRightColumn(context)),
                              ],
                            );
                          } else {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLeftColumn(context),
                                const SizedBox(
                                  height: 24,
                                ), // เพิ่มระยะห่างแนวตั้ง
                                _buildRightColumn(context),
                              ],
                            );
                          }
                        },
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  // --- Widget สำหรับคอลัมน์ด้านซ้าย ---
  Widget _buildLeftColumn(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('เพิ่มรูปได้สูงสุด 5 รูป'),
        const SizedBox(height: 8),
        _buildImagePickerGrid(),
        const SizedBox(height: 16),
        CustomTextFormField(
          labelText: 'ชื่อทีม',
          controller: _teamNameController,
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: GooglePlaceAutoCompleteTextField(
            focusNode: _courtSearchFocusNode,
            textEditingController: _courtSearchController,
            googleAPIKey: "AIzaSyBpk17agVq1F0xjqm3otuO8tXDHE1WtiSc",
            inputDecoration: InputDecoration(
              labelText: "ค้นหาสนาม",
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.0),
              ),
            ),
            debounceTime: 400,
            countries: ["th"], // จำกัดการค้นหาในประเทศไทย
            isLatLngRequired: true,
            getPlaceDetailWithLatLng: (prediction) {
              // Callback เมื่อผู้ใช้เลือกสถานที่
              setState(() {
                _selectedPlace = {
                  'placeId': prediction.placeId, // <<< NEW: เก็บ Place ID
                  'name': prediction.description,
                  'address':
                      prediction.description, // ใช้ description สำหรับที่อยู่ด้วย
                  'lat': prediction.lat,
                  'lng': prediction.lng,
                };
              });
              print("Selected Place: ${prediction.description}");
            },
            itemClick: (prediction) {
              _courtSearchController.text = prediction.description ?? '';
              _courtSearchController.selection = TextSelection.fromPosition(
                TextPosition(offset: prediction.description?.length ?? 0),
              );
            },
            seperatedBuilder: const Divider(), // เพิ่มบรรทัดนี้เพื่อป้องกัน Error ในบางเวอร์ชัน
          ),
        ),
        const SizedBox(height: 16),
        CustomTextFormField(
          labelText: 'วัน',
          controller: _dateController,
          suffixIconData: Icons.calendar_today,
          readOnly: true,
          onSuffixIconPressed: () => _selectDate(_dateController),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: CustomTextFormField(
                labelText: 'เวลาเริ่มต้น',
                controller: _startTimeController,
                suffixIconData: Icons.access_time,
                readOnly: true, // <<< สำคัญมาก
                onSuffixIconPressed: () =>
                    _selectTime(_startTimeController), // <<< เรียกใช้ฟังก์ชัน
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: CustomTextFormField(
                labelText: 'เวลาสิ้นสุด',
                controller: _endTimeController,
                suffixIconData: Icons.access_time,
                readOnly: true, // <<< สำคัญมาก
                onSuffixIconPressed: () =>
                    _selectTime(_endTimeController), // <<< เรียกใช้ฟังก์ชัน
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        CustomDropdown(
          labelText: 'เล่นเกมละ/เซต',
          initialValue: _selectedGameType,
          items: _gameTypes,
          onChanged: (value) {
            setState(() => _selectedGameType = value.toString());
          },
        ),
        const SizedBox(height: 16),
        CustomTextFormField(
          labelText: 'จำนวนที่เปิดรับจอง',
          controller: _slotsController,
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 16),
        CustomDropdown(
          labelText: 'วิธีจัดคิว',
          initialValue: _selectedQueueType,
          items: _pairingMethods,
          onChanged: (value) =>
              setState(() => _selectedQueueType = value.toString()),
        ),
        const SizedBox(height: 16),
        Text(
          'สิ่งอำนวยความสะดวก',
          style: TextStyle(
            fontSize: getResponsiveFontSize(context, fontSize: 12),
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          children: _facilities.keys.map((String key) {
            return SizedBox(
              width: 180, // กำหนดความกว้างเพื่อให้จัดเรียงสวยงาม
              child: CheckboxListTile(
                title: Text(key),
                value: _facilities[key],
                onChanged: (bool? value) =>
                    setState(() => _facilities[key] = value!),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // --- Widget สำหรับคอลัมน์ด้านขวา ---
  Widget _buildRightColumn(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'การคิดเงินลูกแบด',
          style: TextStyle(
            fontSize: getResponsiveFontSize(context, fontSize: 16),
            fontWeight: FontWeight.w400,
          ),
        ),
        RadioGroup<int>(
          groupValue: _shuttleChargeMethod,
          onChanged: (value) {
            setState(() {
              _shuttleChargeMethod = value;
            });
          },
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Expanded(
                child: RadioListTile<int>(
                  title: Text(
                    'เก็บเพิ่มจำนวนลูก',
                    style: TextStyle(
                      fontSize: getResponsiveFontSize(context, fontSize: 12),
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  value: 1,
                ),
              ),
              Expanded(
                child: RadioListTile<int>(
                  title: Text(
                    'เก็บตามรอบ',
                    style: TextStyle(
                      fontSize: getResponsiveFontSize(context, fontSize: 12),
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  value: 2,
                ),
              ),
            ],
          ),
        ),

        Row(
          children: [
            Expanded(
              child: CustomTextFormField(
                labelText: 'ราคาค่าลูก/คน',
                controller: _shuttlePriceController,
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: CustomTextFormField(
                labelText: 'ต้นทุนลูกแบด/คน',
                controller: _shuttleCostController,
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        CustomDropdown(
          labelText: 'ลูกแบดที่ใช้ยี่ห้อ',
          initialValue: _selectedShuttleBrand,
          items: _shuttleBrands,
          onChanged: (v) {
            _callReadShuttlecockmodels(v);
            setState(() => _selectedShuttleBrand = v.toString());
          },
        ),
        // const SizedBox(width: 16),
        const SizedBox(height: 16),
        CustomDropdown(
          labelText: 'รุ่น',
          initialValue: _selectedShuttleModel,
          items: _shuttleModels,
          onChanged: (v) =>
              setState(() => _selectedShuttleModel = v.toString()),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: CustomTextFormField(
                labelText: 'ราคาค่าสนาม/คน',
                controller: _courtPriceController,
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: CustomTextFormField(
                labelText: 'ต้นทุนสนามทั้งหมด',
                controller: _courtTotalCostController,
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        CustomTextFormField(
          labelText: 'จำนวนสนามที่เปิด',
          controller: _openCourtsController,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
          ], // บังคับให้กรอกแต่ตัวเลข
          onChanged: _updateCourtFields,
        ),
        const SizedBox(height: 16),
        Wrap(
          // กำหนดระยะห่างในแนวนอนระหว่างแต่ละช่อง
          spacing: 11.0,
          // กำหนดระยะห่างในแนวตั้งระหว่างบรรทัด
          runSpacing: 12.0,
          // สร้าง List ของ Widget จาก controllers ที่มี
          children: _courtNumberControllers.asMap().entries.map((entry) {
            int index = entry.key;
            TextEditingController controller = entry.value;

            // ใช้ SizedBox เพื่อกำหนดความกว้างของ TextFormField
            return SizedBox(
              width: 100,
              child: CustomTextFormField(
                labelText: 'สนามที่ ${index + 1}',
                controller: controller,
                // คุณสามารถเพิ่ม validator หรืออื่นๆ ได้ตามต้องการ
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        Text(
          'รายละเอียดเพิ่มเติม',
          style: TextStyle(
            fontSize: getResponsiveFontSize(context, fontSize: 12),
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 16),
        CustomTextFormField(
          labelText: '',
          controller: _notesController,
          minLines: 6,
          maxLines: 6,
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: CustomElevatedButton(
            isLoading: _isLoading,
            onPressed: _submitForm,
            text: widget.code != 'new' ? 'Save Changes' : 'Create Game',
          ),
        ),
      ],
    );
  }

  Widget _buildImagePickerGrid() {
    return AspectRatio(
      aspectRatio: 1.8, // กำหนดสัดส่วนของพื้นที่ทั้งหมด
      child: Row(
        children: [
          // --- ช่องใหญ่ด้านซ้าย ---
          Expanded(
            flex: 2, // ให้ความกว้างเป็น 2 ส่วน
            child: _buildImageSlot(
              0,
              isLarge: true,
            ), // ช่องนี้คือรูปที่ 1 (index 0)
          ),
          const SizedBox(width: 10),
          // --- 4 ช่องเล็กด้านขวา ---
          Expanded(
            flex: 2, // ให้ความกว้างเป็น 2 ส่วนเท่ากัน
            child: Column(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Expanded(child: _buildImageSlot(1)), // รูปที่ 2 (index 1)
                      const SizedBox(width: 10),
                      Expanded(child: _buildImageSlot(2)), // รูปที่ 3 (index 2)
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(child: _buildImageSlot(3)), // รูปที่ 4 (index 3)
                      const SizedBox(width: 10),
                      Expanded(child: _buildImageSlot(4)), // รูปที่ 5 (index 4)
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- NEW: ฟังก์ชันย่อยสำหรับสร้างแต่ละช่อง (ทั้งช่องที่มีรูปและช่องว่าง) ---
  Widget _buildImageSlot(int index, {bool isLarge = false}) {
    // --- กรณีที่ช่องนั้นมีรูปภาพอยู่แล้ว ---
    if (index < _gameImages.length) {
      final imageItem = _gameImages[index];
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // แสดงรูปตามประเภท (URL หรือ File)
            if (imageItem is String)
              Image.network(imageItem, fit: BoxFit.cover)
            else if (imageItem is File)
              Image.file(imageItem, fit: BoxFit.cover),

            // ปุ่มลบรูป
            Positioned(
              top: 4,
              right: 4,
              child: InkWell(
                onTap: () => _removeImage(index),
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 16),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // --- กรณีที่เป็นช่องว่างสำหรับเพิ่มรูป ---
    // จะแสดงช่องนี้ก็ต่อเมื่อจำนวนรูปยังไม่ถึง 5 รูป
    if (_gameImages.length < 5) {
      // ใช้ ImageUploadPicker ที่คุณมีอยู่แล้วเป็นปุ่ม
      return ImageUploadPicker(
        allowMultiple: true,
        callback: _onImagePicked,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.add_circle_outline,
                  color: Colors.grey[600],
                  size: isLarge ? 32 : 24,
                ),
                if (isLarge) ...[
                  // แสดงข้อความเฉพาะในช่องใหญ่
                  const SizedBox(height: 8),
                  Text(
                    'เพิ่มได้สูงสุด 5 รูป',
                    style: TextStyle(color: Colors.grey[700], fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    // ถ้าเต็ม 5 รูปแล้ว และ index นี้ไม่มีรูป ก็ให้แสดงเป็นช่องว่างไปเลย
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }
}
