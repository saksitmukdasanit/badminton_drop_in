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
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

const _weekdayChoices = [
  (1, 'จันทร์'),
  (2, 'อังคาร'),
  (3, 'พุธ'),
  (4, 'พฤหัส'),
  (5, 'ศุกร์'),
  (6, 'เสาร์'),
  (7, 'อาทิตย์'),
];

int _daysMask(Set<int> weekdays) {
  var m = 0;
  for (final d in weekdays) {
    if (d >= 1 && d <= 7) m |= 1 << (d - 1);
  }
  return m;
}

Set<int> _weekdaysFromMask(int mask) {
  final s = <int>{};
  for (var i = 0; i < 7; i++) {
    if ((mask & (1 << i)) != 0) s.add(i + 1);
  }
  return s;
}

List<dynamic> _asList(dynamic raw) {
  if (raw == null) return [];
  if (raw is List) return raw;
  if (raw is Map && raw['data'] is List) return raw['data'] as List;
  return [];
}

String _normalizeTimeForApi(String raw) {
  try {
    final input12 = DateFormat('h:mm a');
    final dt = input12.parse(raw.trim());
    return DateFormat('HH:mm').format(dt);
  } catch (_) {
    try {
      final input24 = DateFormat('HH:mm');
      final dt = input24.parse(raw.trim());
      return DateFormat('HH:mm').format(dt);
    } catch (_) {
      return raw.trim();
    }
  }
}

class PlacePrediction {
  PlacePrediction({required this.description, required this.placeId});
  final String description;
  final String placeId;
}

class RecurringTemplateFormPage extends StatefulWidget {
  const RecurringTemplateFormPage({super.key, this.templateId});

  final int? templateId;

  @override
  State<RecurringTemplateFormPage> createState() =>
      _RecurringTemplateFormPageState();
}

class _RecurringTemplateFormPageState extends State<RecurringTemplateFormPage> {
  final _courtSearchController = TextEditingController();
  final _teamNameController = TextEditingController();
  final _startTimeController = TextEditingController();
  final _endTimeController = TextEditingController();
  final _slotsController = TextEditingController(text: '8');
  final _shuttlePriceController = TextEditingController();
  final _shuttleCostController = TextEditingController();
  final _courtPriceController = TextEditingController();
  final _courtTotalCostController = TextEditingController();
  final _openCourtsController = TextEditingController(text: '1');
  final List<TextEditingController> _courtNumberControllers = [];
  final _notesController = TextEditingController();

  /// ใช้หลังโหลดจาก API — แยกหมายเลขสนามเป็นกล่องทีละสนาม
  String? _pendingCourtNumbersCsv;

  final List<dynamic> _gameImages = [];

  Map<String, dynamic>? _selectedPlace;
  String? _sessionToken;
  final _uuid = const Uuid();
  TextEditingController? _autocompleteCtrl;

  final Map<String, int> _facilityCodeByLabel = {};

  String? _selectedGameType;
  String? _selectedQueueType;
  String? _selectedShuttleBrand;
  String? _selectedShuttleModel;
  int? _costingMethod = 1;

  List<dynamic> _gameTypes = [];
  List<dynamic> _pairingMethods = [];
  List<dynamic> _shuttleBrands = [];
  List<dynamic> _shuttleModels = [];
  Map<String, bool> _facilityLabelsToSelected = {};

  final Set<int> _weekdays = {};
  bool _isActive = true;

  bool _loading = true;
  bool _submitting = false;

  Future<List<PlacePrediction>> _searchPlaces(String input) async {
    if (input.trim().isEmpty) return [];
    if (_selectedPlace != null &&
        input.trim() == _selectedPlace!['name'].toString()) {
      return [];
    }
    _sessionToken ??= _uuid.v4();
    const apiKey = 'AIzaSyBpk17agVq1F0xjqm3otuO8tXDHE1WtiSc';

    try {
      final response = await Dio().get(
        'https://maps.googleapis.com/maps/api/place/autocomplete/json',
        queryParameters: {
          'input': '$input แบดมินตัน',
          'key': apiKey,
          'sessiontoken': _sessionToken,
          'components': 'country:th',
          'language': 'th',
        },
      );

      if (response.statusCode == 200 &&
          response.data['status'] == 'OK' &&
          response.data['predictions'] is List) {
        final list = response.data['predictions'] as List;
        return list
            .map<PlacePrediction>(
              (p) => PlacePrediction(
                description: p['description'] as String,
                placeId: p['place_id'] as String,
              ),
            )
            .toList();
      }
    } catch (_) {}

    return [];
  }

  Future<void> _getPlaceDetails(PlacePrediction opt) async {
    const apiKey = 'AIzaSyBpk17agVq1F0xjqm3otuO8tXDHE1WtiSc';
    try {
      final response = await Dio().get(
        'https://maps.googleapis.com/maps/api/place/details/json',
        queryParameters: {
          'place_id': opt.placeId,
          'key': apiKey,
          'sessiontoken': _sessionToken,
          'fields': 'name,geometry,formatted_address',
        },
      );
      if (response.statusCode == 200 &&
          response.data['result'] != null &&
          mounted) {
        final r = response.data['result'];
        final loc = r['geometry']['location'];
        setState(() {
          _selectedPlace = {
            'placeId': opt.placeId,
            'name': r['name'],
            'address': r['formatted_address'],
            'lat': (loc['lat'] as num).toDouble(),
            'lng': (loc['lng'] as num).toDouble(),
          };
          final name = r['name'] as String;
          _courtSearchController.text = name;
          _autocompleteCtrl?.text = name;
          _sessionToken = null;
        });
      }
    } catch (_) {}
  }

  void _updateCourtFields(String value, [String? initialCsv]) {
    final int count = int.tryParse(value) ?? 0;
    if (count == _courtNumberControllers.length && initialCsv == null) return;
    if (!mounted) return;
    setState(() {
      for (final controller in _courtNumberControllers) {
        controller.dispose();
      }
      _courtNumberControllers.clear();
      final List<String> parts =
          initialCsv?.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList() ?? [];
      for (var i = 0; i < count; i++) {
        final initialText = i < parts.length ? parts[i] : '';
        _courtNumberControllers.add(TextEditingController(text: initialText));
      }
    });
  }

  Future<void> _onImagePicked(List<File> imageFiles) async {
    if (_gameImages.length >= 5) {
      showDialogMsg(
        context,
        title: 'แจ้งเตือน',
        subtitle: 'อัปโหลดรูปภาพได้สูงสุด 5 รูป',
        btnLeft: 'ตกลง',
        onConfirm: () {},
      );
      return;
    }
    try {
      final response = await ApiProvider().uploadFiles(
        files: imageFiles,
        folderName: 'Game',
      );
      if (response is List && response.isNotEmpty && mounted) {
        setState(() {
          for (final r in response) {
            if (_gameImages.length >= 5) break;
            _gameImages.add(r['imageUrl']);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  void _removeImage(int index) {
    setState(() => _gameImages.removeAt(index));
  }

  Future<void> _loadBrandModels(String? brandCode) async {
    final bid = brandCode != null ? int.tryParse(brandCode) : null;
    try {
      final raw = await ApiProvider().get(
        '/Dropdowns/shuttlecockmodels',
        queryParameters: bid != null ? {'brandId': bid} : null,
      );
      if (!mounted) return;
      setState(() => _shuttleModels = _asList(raw));
    } catch (_) {
      if (!mounted) return;
      setState(() => _shuttleModels = []);
    }
  }

  void _hydrateDetail(Map<String, dynamic> m) {
    _teamNameController.text = '${m['groupName'] ?? m['group_name'] ?? ''}';
    _isActive = (m['isActive'] ?? m['is_active'] ?? true) as bool? ?? true;
    final mask =
        ((m['daysOfWeekMask'] ?? m['days_of_week_mask'] ?? 0) as num).toInt();
    _weekdays
      ..clear()
      ..addAll(_weekdaysFromMask(mask));

    _startTimeController.text =
        '${m['startTime'] ?? m['start_time'] ?? '18:00'}';
    _endTimeController.text =
        '${m['endTime'] ?? m['end_time'] ?? '21:00'}';

    _selectedGameType = m['gameTypeId']?.toString();
    _selectedQueueType = m['pairingMethodId']?.toString();
    final mid = m['shuttlecockModelId'] ?? m['shuttlecock_model_id'];
    if (mid != null) _selectedShuttleModel = mid.toString();

    _slotsController.text =
        '${m['maxParticipants'] ?? m['max_participants'] ?? 8}';
    final cmDyn = m['costingMethod'] ?? m['costing_method'];
    _costingMethod =
        cmDyn is num ? cmDyn.toInt() : int.tryParse('$cmDyn') ?? 1;
    _courtPriceController.text =
        '${m['courtFeePerPerson'] ?? m['court_fee_per_person'] ?? ''}';
    _shuttlePriceController.text =
        '${m['shuttlecockFeePerPerson'] ?? m['shuttlecock_fee_per_person'] ?? ''}';
    _courtTotalCostController.text =
        '${m['totalCourtCost'] ?? m['total_court_cost'] ?? ''}';
    _shuttleCostController.text =
        '${m['shuttlecockCostPerUnit'] ?? m['shuttlecock_cost_per_unit'] ?? ''}';
    _openCourtsController.text =
        '${m['numberOfCourts'] ?? m['number_of_courts'] ?? 1}';
    _pendingCourtNumbersCsv =
        '${m['courtNumbers'] ?? m['court_numbers'] ?? ''}'.trim();
    _notesController.text = '${m['notes'] ?? ''}';

    _gameImages.clear();
    final pics = m['photoUrls'] ?? m['photo_urls'];
    if (pics is List) {
      for (final u in pics) {
        if (u != null && '$u'.isNotEmpty) _gameImages.add('$u');
      }
    }

    final vdRaw = (m['venueData'] ??
        m['venue_data'] ??
        <String, dynamic>{}) as Map;
    final vd = Map<String, dynamic>.from(vdRaw);
    final gpid =
        '${vd['googlePlaceId'] ?? vd['googlePlaceID'] ?? ''}'.trim();
    if (gpid.isNotEmpty) {
      final latNum = vd['latitude'] ?? vd['lat'];
      final lngNum = vd['longitude'] ?? vd['lng'];
      _selectedPlace = {
        'placeId': gpid,
        'name': vd['name'] ?? '',
        'address': vd['address'] ?? '',
        'lat': latNum is num
            ? latNum.toDouble()
            : double.tryParse('$latNum') ?? 0.0,
        'lng':
            lngNum is num ? lngNum.toDouble() : double.tryParse('$lngNum') ?? 0.0,
      };
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final name = '${_selectedPlace!['name']}';
        _courtSearchController.text = name;
        _autocompleteCtrl?.text = name;
      });
    }
  }

  Future<void> _applyFacilitySelectionsFromDetail() async {
    if (widget.templateId == null || !mounted) return;
    try {
      final res = await ApiProvider()
          .get('/organizer/recurring-templates/${widget.templateId}');
      final wrap = res is Map ? res : <String, dynamic>{};
      final data = Map<String, dynamic>.from((wrap['data'] ?? wrap) as Map);
      final facIds =
          ((data['facilityIds'] ?? data['facility_ids']) as List?)
                  ?.whereType<num>()
                  .map((e) => e.toInt())
                  .toSet() ??
              {};
      if (facIds.isEmpty) return;

      final next = Map<String, bool>.from(_facilityLabelsToSelected);
      for (final e in _facilityCodeByLabel.entries) {
        next[e.key] = facIds.contains(e.value);
      }
      setState(() => _facilityLabelsToSelected = next);
    } catch (_) {}
  }

  Future<void> _resolveShuttleBrandForEditedModel() async {
    final mid = _selectedShuttleModel;
    if (mid == null || mid.isEmpty) return;
    for (final b in _shuttleBrands) {
      if (b is! Map) continue;
      final code = '${b['code']}';
      final bid = int.tryParse(code);
      if (bid == null) continue;
      try {
        final rawModels = await ApiProvider().get('/Dropdowns/shuttlecockmodels',
            queryParameters: {'brandId': bid});
        final models = _asList(rawModels);
        for (final mm in models) {
          if (mm is Map && '${mm['code']}' == mid) {
            _selectedShuttleBrand = code;
            _shuttleModels = models;
            return;
          }
        }
      } catch (_) {}
    }
  }

  Future<void> _bootstrapWithoutDetail() async {
    setState(() => _loading = true);
    try {
      final fList =
          _asList(await ApiProvider().get('/Dropdowns/facilities'));
      final mapSel = <String, bool>{};
      _facilityCodeByLabel.clear();
      for (final item in fList) {
        if (item is Map && item['value'] != null) {
          final label = '${item['value']}';
          mapSel[label] = false;
          final id = int.tryParse('${item['code']}');
          if (id != null) _facilityCodeByLabel[label] = id;
        }
      }

      final masters = await Future.wait([
        ApiProvider().get('/Dropdowns/gametypes'),
        ApiProvider().get('/Dropdowns/pairingmethods'),
        ApiProvider().get('/Dropdowns/shuttlecockbrands'),
      ]).timeout(const Duration(seconds: 15));

      if (!mounted) return;
      _gameTypes = _asList(masters[0]);
      _pairingMethods = _asList(masters[1]);
      _shuttleBrands = _asList(masters[2]);

      setState(() => _facilityLabelsToSelected = mapSel);

      if (widget.templateId != null) {
        final res = await ApiProvider()
            .get('/organizer/recurring-templates/${widget.templateId}');
        final wrap = res is Map ? res : <String, dynamic>{};
        final dataRaw = wrap['data'] ?? wrap;
        if (dataRaw is Map) {
          _hydrateDetail(Map<String, dynamic>.from(dataRaw));
          await _applyFacilitySelectionsFromDetail();
          await _resolveShuttleBrandForEditedModel();
        }
      } else {
        if (_weekdays.isEmpty) {
          _weekdays.add(3);
          _weekdays.add(4);
        }
        _startTimeController.text = '18:00';
        _endTimeController.text = '21:00';
      }

      await _loadBrandModels(_selectedShuttleBrand);

      final courtCsv = _pendingCourtNumbersCsv;
      _pendingCourtNumbersCsv = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _updateCourtFields(
          _openCourtsController.text,
          (courtCsv != null && courtCsv.isNotEmpty) ? courtCsv : null,
        );
      });
    } catch (e) {
      debugPrint('_bootstrap recurring: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrapWithoutDetail());
  }

  Future<void> _pickTime(TextEditingController c) async {
    final picked =
        await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (picked != null && mounted) {
      setState(() => c.text = picked.format(context));
    }
  }

  List<int> _facilityIdsChosen() {
    final ids = <int>[];
    for (final e in _facilityLabelsToSelected.entries) {
      if (!e.value) continue;
      final id = _facilityCodeByLabel[e.key];
      if (id != null) ids.add(id);
    }
    return ids;
  }

  Future<void> _save() async {
    if (_selectedPlace == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณาเลือกสนาม')),
      );
      return;
    }
    if (_weekdays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('กรุณาเลือกอย่างน้อยหนึ่งวันในอาทิตย์')),
      );
      return;
    }

    setState(() => _submitting = true);

    try {
      final venue = _selectedPlace!;
      final payload = <String, dynamic>{
        'groupName': _teamNameController.text.trim(),
        'venueData': {
          'googlePlaceId': venue['placeId'],
          'name': venue['name'],
          'address': venue['address'],
          'latitude': venue['lat'],
          'longitude': venue['lng'],
        },
        'daysOfWeekMask': _daysMask(_weekdays),
        'startTime': _normalizeTimeForApi(_startTimeController.text),
        'endTime': _normalizeTimeForApi(_endTimeController.text),
        'gameTypeId':
            _selectedGameType != null ? int.tryParse(_selectedGameType!) : null,
        'pairingMethodId':
            _selectedQueueType != null ? int.tryParse(_selectedQueueType!) : null,
        'maxParticipants': int.tryParse(_slotsController.text) ?? 0,
        'costingMethod': _costingMethod,
        'courtFeePerPerson':
            double.tryParse(_courtPriceController.text.trim()),
        'shuttlecockFeePerPerson':
            double.tryParse(_shuttlePriceController.text.trim()),
        'totalCourtCost':
            double.tryParse(_courtTotalCostController.text.trim()),
        'shuttlecockCostPerUnit':
            double.tryParse(_shuttleCostController.text.trim()),
        'shuttlecockModelId': _selectedShuttleModel != null
            ? int.tryParse(_selectedShuttleModel!)
            : null,
        'numberOfCourts': int.tryParse(_openCourtsController.text.trim()),
        'courtNumbers': _courtNumberControllers.map((c) => c.text.trim()).join(','),
        'notes': _notesController.text.trim(),
        'facilityIds': _facilityIdsChosen(),
        'photoUrls': _gameImages.map((e) => '$e').toList(),
        'isActive': _isActive,
      };

      if (widget.templateId != null) {
        await ApiProvider().put(
            '/organizer/recurring-templates/${widget.templateId}', data: payload);
      } else {
        await ApiProvider()
            .post('/organizer/recurring-templates', data: payload);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                widget.templateId != null ? 'บันทึกแล้ว' : 'สร้างแล้ว')),
      );
      context.pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  void dispose() {
    _courtSearchController.dispose();
    _teamNameController.dispose();
    _startTimeController.dispose();
    _endTimeController.dispose();
    _slotsController.dispose();
    _shuttlePriceController.dispose();
    _shuttleCostController.dispose();
    _courtPriceController.dispose();
    _courtTotalCostController.dispose();
    _openCourtsController.dispose();
    for (final c in _courtNumberControllers) {
      c.dispose();
    }
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBarSubMain(
          title: widget.templateId == null ? 'เพิ่มก๊วนประจำ' : 'แก้ไขก๊วนประจำ',
          isBack: true,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final double scrollBottom =
        MediaQuery.of(context).padding.bottom + 32;

    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.white,
      appBar: AppBarSubMain(
        title: widget.templateId == null ? 'เพิ่มก๊วนประจำ' : 'แก้ไขก๊วนประจำ',
        isBack: true,
      ),
      body: Container(
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFFFFFF), Color(0xFFD5DCF4)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: AbsorbPointer(
          absorbing: _submitting,
          child: Stack(
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        spreadRadius: 2,
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final bool wide = constraints.maxWidth > 600;
                      final Widget columns = wide
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: _buildLeftColumn(context)),
                                const SizedBox(width: 24),
                                Expanded(child: _buildRightColumn(context)),
                              ],
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLeftColumn(context),
                                const SizedBox(height: 24),
                                _buildRightColumn(context),
                              ],
                            );
                      return Padding(
                        padding: EdgeInsets.only(bottom: scrollBottom),
                        child: columns,
                      );
                    },
                  ),
                ),
              ),
              if (_submitting)
                const Center(child: CircularProgressIndicator()),
            ],
          ),
        ),
      ),
    );
  }

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
          child: Autocomplete<PlacePrediction>(
            initialValue: TextEditingValue(text: _courtSearchController.text),
            optionsBuilder: (te) => _searchPlaces(te.text),
            displayStringForOption: (x) => x.description,
            onSelected: _getPlaceDetails,
            fieldViewBuilder: (ctx, ctrl, fn, _) {
              _autocompleteCtrl = ctrl;
              return CustomTextFormField(
                controller: ctrl,
                focusNode: fn,
                labelText: 'ค้นหาสนาม',
                onChanged: (value) {
                  _courtSearchController.text = value;
                  if (_selectedPlace != null &&
                      value != _selectedPlace!['name'].toString()) {
                    setState(() => _selectedPlace = null);
                  }
                },
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'วันที่จัดประจำทุกสัปดาห์',
          style: TextStyle(
            fontSize: getResponsiveFontSize(context, fontSize: 12),
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'ระบบสร้างก๊วนล่วงหน้าโดยประมาณ 14 วัน — แทนช่อง "วัน" ในหน้าสร้างก๊วนปกติ',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _weekdayChoices.map((e) {
            final sel = _weekdays.contains(e.$1);
            return FilterChip(
              label: Text(e.$2),
              selected: sel,
              onSelected: (_) {
                setState(() {
                  if (sel) {
                    _weekdays.remove(e.$1);
                  } else {
                    _weekdays.add(e.$1);
                  }
                });
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Text(
                'เปิดใช้แม่แบบ (ปิดแล้วจะไม่สร้างก๊วนอัตโนมัติ)',
                style: TextStyle(
                  fontSize: getResponsiveFontSize(context, fontSize: 12),
                ),
              ),
            ),
            Switch(
              value: _isActive,
              onChanged: (v) => setState(() => _isActive = v),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: CustomTextFormField(
                labelText: 'เวลาเริ่มต้น',
                controller: _startTimeController,
                suffixIconData: Icons.access_time,
                readOnly: true,
                onSuffixIconPressed: () => _pickTime(_startTimeController),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: CustomTextFormField(
                labelText: 'เวลาสิ้นสุด',
                controller: _endTimeController,
                suffixIconData: Icons.access_time,
                readOnly: true,
                onSuffixIconPressed: () => _pickTime(_endTimeController),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        CustomDropdown(
          labelText: 'เล่นเกมละ/เซต',
          initialValue: _selectedGameType,
          items: _gameTypes,
          onChanged: (v) =>
              setState(() => _selectedGameType = v.toString()),
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
          onChanged: (v) =>
              setState(() => _selectedQueueType = v.toString()),
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
          children: _facilityLabelsToSelected.keys.map((k) {
            return SizedBox(
              width: 180,
              child: CheckboxListTile(
                title: Text(k),
                value: _facilityLabelsToSelected[k] ?? false,
                onChanged: (bool? value) => setState(() {
                  _facilityLabelsToSelected[k] = value ?? false;
                }),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

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
          groupValue: _costingMethod ?? 1,
          onChanged: (value) {
            setState(() => _costingMethod = value);
          },
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Expanded(
                child: RadioListTile<int>(
                  title: Text(
                    'เก็บตามเกมส์',
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
                    'บุฟเฟต์',
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
                labelText: _costingMethod == 2
                    ? 'ราคาบุฟเฟต์/คน'
                    : 'ราคาค่าลูก/คน',
                controller: _shuttlePriceController,
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: CustomTextFormField(
                labelText: _costingMethod == 2
                    ? 'ต้นทุนลูกบุฟเฟต์/คน'
                    : 'ต้นทุนลูกแบด/คน',
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
          onChanged: (v) async {
            setState(() {
              _selectedShuttleBrand = v?.toString();
              _selectedShuttleModel = null;
              _shuttleModels = [];
            });
            if (v != null) await _loadBrandModels(v.toString());
          },
        ),
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
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: _updateCourtFields,
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 11,
          runSpacing: 12,
          children: _courtNumberControllers.asMap().entries.map((entry) {
            final index = entry.key;
            final controller = entry.value;
            return SizedBox(
              width: 100,
              child: CustomTextFormField(
                labelText: 'สนามที่ ${index + 1}',
                controller: controller,
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
            isLoading: _submitting,
            onPressed: _save,
            text: widget.templateId == null
                ? 'สร้างแม่แบบประจำ'
                : 'บันทึกการแก้ไขแม่แบบ',
          ),
        ),
      ],
    );
  }

  Widget _buildImagePickerGrid() {
    return AspectRatio(
      aspectRatio: 1.8,
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: _buildImageSlot(0, isLarge: true),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: Column(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Expanded(child: _buildImageSlot(1)),
                      const SizedBox(width: 10),
                      Expanded(child: _buildImageSlot(2)),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(child: _buildImageSlot(3)),
                      const SizedBox(width: 10),
                      Expanded(child: _buildImageSlot(4)),
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

  Widget _buildImageSlot(int index, {bool isLarge = false}) {
    if (index < _gameImages.length) {
      final imageItem = _gameImages[index];
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (imageItem is String)
              Image.network(imageItem, fit: BoxFit.cover)
            else if (imageItem is File)
              Image.file(imageItem, fit: BoxFit.cover),
            Positioned(
              top: 4,
              right: 4,
              child: InkWell(
                onTap: () => _removeImage(index),
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child:
                      const Icon(Icons.close, color: Colors.white, size: 16),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_gameImages.length < 5) {
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

    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }
}
