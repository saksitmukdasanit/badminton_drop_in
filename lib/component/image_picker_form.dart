import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class ImagePickerFormField extends StatefulWidget {
  final String labelText;
  final bool isRequired;
  final Function(XFile?) onImageSelected; // Callback เพื่อส่งไฟล์ที่เลือกกลับไป

  const ImagePickerFormField({
    super.key,
    required this.labelText,
    this.isRequired = false,
    required this.onImageSelected,
  });

  @override
  State<ImagePickerFormField> createState() => _ImagePickerFormFieldState();
}

class _ImagePickerFormFieldState extends State<ImagePickerFormField> {
  XFile? _selectedImage;
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage() async {
    // แสดง BottomSheet ให้เลือกระหว่างกล้องกับคลังภาพ
    showModalBottomSheet(
      context: context,
      builder: (BuildContext bc) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('เลือกจากคลังภาพ'),
                onTap: () async {
                  Navigator.of(context).pop();
                  final XFile? image = await _picker.pickImage(
                    source: ImageSource.gallery,
                  );
                  if (image != null) {
                    setState(() {
                      _selectedImage = image;
                    });
                    widget.onImageSelected(_selectedImage);
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: const Text('ถ่ายรูป'),
                onTap: () async {
                  Navigator.of(context).pop();
                  final XFile? image = await _picker.pickImage(
                    source: ImageSource.camera,
                  );
                  if (image != null) {
                    setState(() {
                      _selectedImage = image;
                    });
                    widget.onImageSelected(_selectedImage);
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        filled: true,
        border: const OutlineInputBorder(),
        // ใช้ label เพื่อแสดง * สีแดง
        label: RichText(
          text: TextSpan(
            text: widget.labelText,
            style: const TextStyle(color: Colors.black54, fontSize: 16),
            children: widget.isRequired
                ? [
                    const TextSpan(
                      text: ' *',
                      style: TextStyle(color: Colors.red),
                    ),
                  ]
                : [],
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- ส่วนที่ทำให้หน้าตาเหมือน TextFormField ---
          InkWell(
            onTap: _pickImage, // กดตรงไหนก็ได้ในช่องเพื่อเลือกรูป
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // แสดงชื่อไฟล์ถ้ามี, หรือแสดงข้อความว่างๆ
                Text(
                  _selectedImage?.name ?? 'ตัวอย่าง',
                  style: const TextStyle(fontSize: 16),
                  overflow: TextOverflow.ellipsis,
                ),
                IconButton(
                  icon: Icon(Icons.camera_alt, color: Colors.grey[600]),
                  onPressed: _pickImage, // กดที่ไอคอนเพื่อเลือกรูป
                ),
              ],
            ),
          ),
          // --- ส่วนแสดงรูปภาพตัวอย่าง ---
          if (_selectedImage != null)
            Padding(
              padding: const EdgeInsets.only(top: 16.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  File(_selectedImage!.path), // แสดงรูปจาก path ของไฟล์
                  width: double.infinity,
                  height: 200,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          if (_selectedImage == null)
            Padding(
              padding: const EdgeInsets.only(top: 16.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  'https://gateway.we-builds.com/wb-document/images/banner/banner_254135409.png', 
                  width: double.infinity,
                  
                ),
              ),
            ),
        ],
      ),
    );
  }
}
