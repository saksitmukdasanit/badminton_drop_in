import 'package:badminton/component/button.dart';
import 'package:badminton/component/dropdown.dart';
import 'package:badminton/component/dialog.dart';
import 'package:badminton/component/text_box.dart';
import 'package:badminton/shared/api_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AddGuestDialog extends StatefulWidget {
  final int sessionId;
  final double courtFee;
  final double shuttleFee;

  const AddGuestDialog({
    super.key,
    required this.sessionId,
    this.courtFee = 0.0,
    this.shuttleFee = 0.0,
  });

  @override
  AddGuestDialogState createState() => AddGuestDialogState();
}

class AddGuestDialogState extends State<AddGuestDialog> {
  final _formKey = GlobalKey<FormState>();
  final _guestNameController = TextEditingController();
  final _phoneNumberController = TextEditingController(); // เพิ่ม Controller เบอร์โทร
  String? _selectedGender;
  String? _selectedSkillLevelId;

  bool _isLoading = true;
  bool _isSaving = false;
  bool _hasAddedAny = false;
  List<dynamic> _skillLevels = [];
  TextEditingController? _autocompleteController;

  final List<Map<String, String>> _genders = [
    {'code': '1', 'value': 'ชาย'},
    {'code': '2', 'value': 'หญิง'},
    {'code': '3', 'value': 'อื่นๆ'},
  ];

  @override
  void initState() {
    super.initState();
    _fetchSkillLevels();
  }

  @override
  void dispose() {
    _guestNameController.dispose();
    _phoneNumberController.dispose();
    super.dispose();
  }

  Future<void> _fetchSkillLevels() async {
    try {
      final response = await ApiProvider().get('/organizer/skill-levels');
      if (mounted) {
        setState(() {
          // แปลงข้อมูลให้ตรงกับ Format ที่ CustomDropdown ต้องการ
          _skillLevels = (response['data'] as List).map((level) {
            return {
              "code": level['skillLevelId'].toString(),
              "value": level['levelName'],
            };
          }).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        Navigator.of(context).pop(); // ปิด Dialog ถ้าโหลดข้อมูลไม่สำเร็จ
        showDialogMsg(
          context,
          title: 'ไม่สามารถโหลดระดับมือได้',
          subtitle: e.toString().replaceFirst('Exception: ', ''),
          btnLeft: 'ตกลง',
          onConfirm: () {},
        );
      }
    }
  }

  // ฟังก์ชันค้นหาชื่อแขกเก่า
  Future<List<Map<String, dynamic>>> _searchGuests(String query) async {
    final trimmedQuery = query.trim(); // ตัดช่องว่างหน้าหลังออกก่อน
    if (trimmedQuery.isEmpty) return [];
    try {
      // ใช้ Uri เพื่อสร้าง URL ที่ถูกต้องและปลอดภัยกว่า
      final uri = Uri(
        path: '/organizer/previous-guests',
        queryParameters: {'query': trimmedQuery}, // ส่งค่าที่ตัดช่องว่างแล้ว
      );
      final response = await ApiProvider().get(uri.toString());
      if (response['data'] is List) {
        return List<Map<String, dynamic>>.from(response['data']);
      }
    } catch (e) {
      print(e);
    }
    return [];
  }

  Future<void> _addGuest({bool addAnother = false}) async {
    final bool isFormValid = _formKey.currentState?.validate() ?? false;

    setState(() {});

    if (!isFormValid ||
        _selectedGender == null ||
        _selectedSkillLevelId == null) {
      showDialogMsg(
        context,
        title: 'แจ้งเตือน',
        subtitle: 'กรุณากรอกข้อมูลให้ครบถ้วน',
        btnLeft: 'ตกลง',
        onConfirm: () {},
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final data = {
        'guestName': _guestNameController.text,
        'phoneNumber': _phoneNumberController.text, // ส่งเบอร์โทรไปด้วย
        'gender': int.tryParse(_selectedGender ?? '0'),
        'skillLevelId': int.tryParse(_selectedSkillLevelId ?? '0'),
      };

      await ApiProvider().post(
        '/gameSessions/${widget.sessionId}/add-guest',
        data: data,
      );

      if (mounted) {
        _hasAddedAny = true;
        // --- CHANGED: เปลี่ยนจาก SnackBar เป็น showDialogMsg ---
        showDialogMsg(
          context,
          title: 'เพิ่มผู้เล่น Walk-in สำเร็จ',
          subtitle: 'เพิ่ม ${_guestNameController.text} เข้าสู่ก๊วนเรียบร้อย',
          btnLeft: 'ตกลง',
          onConfirm: () {
            if (addAnother) {
              setState(() {
                _guestNameController.clear();
                _autocompleteController?.clear();
                _phoneNumberController.clear();
                _selectedGender = null;
                _selectedSkillLevelId = null;
              });
            } else {
              Navigator.of(context).pop(true);
            }
          },
        );
      }
    } catch (e) {
      if (mounted) {
        showDialogMsg(
          context,
          title: 'เกิดข้อผิดพลาด',
          subtitle: e.toString().replaceFirst('Exception: ', ''),
          btnLeft: 'ตกลง',
          onConfirm: () {},
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const platformFee = 10.0;
    // คำนวณราคารวมใหม่เพื่อให้แน่ใจว่าถูกต้อง
    // final totalFee = widget.courtFee + widget.shuttleFee + platformFee;
    final totalFee = widget.courtFee + platformFee;
    return AlertDialog(
      title: const Text('เพิ่มผู้เล่น Walk In'),
      content: _isLoading
          ? const SizedBox(
              width: 400,
              child: Center(child: CircularProgressIndicator()),
            )
          : SizedBox(
              width: 400, // <-- ขยายความกว้างของ Dialog
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // --- ส่วนข้อมูลผู้เล่น ---
                      const Text(
                        'ข้อมูลผู้เล่น',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 12),
                      // --- ชื่อและเพศในแถวเดียวกัน ---
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 3, // ให้ช่องชื่อกว้างกว่า
                            // --- เปลี่ยน TextField เป็น Autocomplete ---
                            child: Autocomplete<Map<String, dynamic>>(
                              optionsBuilder: (TextEditingValue textEditingValue) {
                                return _searchGuests(textEditingValue.text);
                              },
                              displayStringForOption: (option) => option['guestName'],
                              onSelected: (option) {
                                // เมื่อเลือกชื่อเก่า ให้เติมข้อมูลอัตโนมัติ
                                _guestNameController.text = option['guestName'];
                                if (option['phoneNumber'] != null) {
                                  _phoneNumberController.text = option['phoneNumber'];
                                }
                                if (option['gender'] != null) {
                                  setState(() {
                                    _selectedGender = option['gender'].toString();
                                  });
                                }
                                if (option['skillLevelId'] != null) {
                                  setState(() {
                                    _selectedSkillLevelId = option['skillLevelId'].toString();
                                  });
                                }
                              },
                              fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                                // Sync controller ของ Autocomplete กับ _guestNameController ของเรา
                                if (_guestNameController.text.isNotEmpty && controller.text.isEmpty) {
                                   controller.text = _guestNameController.text;
                                }
                                _autocompleteController = controller;
                                return CustomTextFormField(
                                  controller: controller,
                                  focusNode: focusNode,
                                  labelText: 'ชื่อ',
                                  isRequired: true,
                                  onChanged: (val) => _guestNameController.text = val,
                                );
                              },
                              optionsViewBuilder: (context, onSelected, options) {
                                return Align(
                                  alignment: Alignment.topLeft,
                                  child: Material(
                                    elevation: 4.0,
                                    child: SizedBox(
                                      width: 250,
                                      child: ListView.builder(
                                        padding: EdgeInsets.zero,
                                        shrinkWrap: true,
                                        itemCount: options.length,
                                        itemBuilder: (BuildContext context, int index) {
                                          final option = options.elementAt(index);
                                          return ListTile(
                                            title: Text(option['guestName']),
                                            subtitle: option['phoneNumber'] != null ? Text(option['phoneNumber']) : null,
                                            onTap: () => onSelected(option),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 2, // ช่องเพศ
                            child: CustomDropdown(
                              labelText: 'เพศ',
                              items: _genders,
                              initialValue: _selectedGender,
                              onChanged: (value) =>
                                  setState(() => _selectedGender = value),
                              validator: (value) {
                                if (value == null) {
                                  return 'กรุณาเลือกเพศ';
                                }
                                return null;
                              },
                              isRequired: true,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // --- เพิ่มช่องกรอกเบอร์โทรศัพท์ ---
                      CustomTextFormField(
                        controller: _phoneNumberController,
                        labelText: 'เบอร์โทรศัพท์',
                        isRequired: true,
                        isPhone: true,
                        keyboardType: TextInputType.phone,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      ),
                      const SizedBox(height: 16),
                      CustomDropdown(
                        labelText: 'ระดับมือ',
                        items: _skillLevels,
                        initialValue: _selectedSkillLevelId,
                        onChanged: (value) =>
                            setState(() => _selectedSkillLevelId = value),
                        validator: (value) {
                          if (value == null) {
                            return 'กรุณาเลือกระดับมือ';
                          }
                          return null;
                        },
                        isRequired: true,
                      ),
                      const SizedBox(height: 20),

                      // // --- ส่วนข้อความแจ้งเตือน (ปรับปรุงใหม่) ---
                      // const Padding(
                      //   padding: EdgeInsets.symmetric(vertical: 2.0),
                      //   child: Align(
                      //     alignment: Alignment.centerLeft,
                      //     child: Text(
                      //       'จองเป็นผู้เล่นตัวจริง',
                      //       style: TextStyle(
                      //         fontWeight: FontWeight.bold,
                      //         fontSize: 16,
                      //       ),
                      //     ),
                      //   ),
                      // ),
                      // Padding(
                      //   padding: const EdgeInsets.symmetric(vertical: 2.0),
                      //   child: Row(
                      //     mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      //     children: [
                      //       const Text(
                      //         'ไม่สามารถยกเลิกได้',
                      //         style: TextStyle(fontSize: 16),
                      //       ),
                      //       TextButton(
                      //         style: TextButton.styleFrom(
                      //           padding: EdgeInsets.zero,
                      //           minimumSize: Size(50, 30),
                      //           tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      //           alignment: Alignment.centerRight,
                      //         ),
                      //         onPressed: () {}, // สามารถเพิ่ม action ได้ที่นี่
                      //         child: const Text(
                      //           'เพิ่มเติม',
                      //           style: TextStyle(
                      //             decoration: TextDecoration.underline,
                      //             color: Color(0xFF0E9D7A),
                      //           ),
                      //         ),
                      //       ),
                      //     ],
                      //   ),
                      // ),
                      // if (widget.courtFee > 0)
                      //   _buildPriceRow(
                      //     'ค่าสนาม',
                      //     '${widget.courtFee.toStringAsFixed(0)} บาท',
                      //   ),
                      // // if (widget.shuttleFee > 0)
                      // //   _buildPriceRow(
                      // //     'ค่าลูกแบด',
                      // //     '${widget.shuttleFee.toStringAsFixed(0)} บาท',
                      // //   ),
                      // _buildPriceRow(
                      //   'ค่าธรรมเนียม',
                      //   '${platformFee.toStringAsFixed(0)} บาท',
                      // ),
                      // const Divider(),
                      // _buildPriceRow(
                      //   'ราคารวม',
                      //   '${totalFee.toStringAsFixed(0)} บาท',
                      //   isBold: true,
                      // ),
                    ],
                  ),
                ),
              ),
            ),
      actions: [
        CustomElevatedButton(
          text: 'ยกเลิก',
          onPressed: () => Navigator.of(context).pop(_hasAddedAny),
          backgroundColor: Color(0xFFFFFFFF),
          foregroundColor: Color(0xFF0E9D7A),
          fontSize: 16,
        ),
        CustomElevatedButton(
          text: 'บันทึก & เพิ่มต่อ',
          onPressed: () => _addGuest(addAnother: true),
          isLoading: _isSaving,
          backgroundColor: Color(0xFFFFFFFF),
          foregroundColor: Color(0xFF0E9D7A),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          fontSize: 16,
        ),
        CustomElevatedButton(
          text: 'ยืนยัน',
          onPressed: () => _addGuest(addAnother: false),
          isLoading: _isSaving,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          fontSize: 16,
          backgroundColor: Color(0xFF0E9D7A),
          foregroundColor: Color(0xFFFFFFFF),
        ),
      ],
    );
  }

  Widget _buildPriceRow(String title, String amount, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16, // <-- เพิ่มขนาดตัวอักษร
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            amount,
            style: TextStyle(
              fontSize: 16, // <-- เพิ่มขนาดตัวอักษร
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
