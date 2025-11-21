import 'dart:io';

import 'package:badminton/component/stack_tap.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class ImageUploadPicker extends StatefulWidget {
  const ImageUploadPicker({
    super.key,
    this.onTap,
    this.child,
    required this.callback,
    this.allowMultiple = false,
  });

  final Function()? onTap;
  final Function(List<File>) callback;
  final Widget? child;
  final bool allowMultiple;

  @override
  ImageUploadPickerState createState() => ImageUploadPickerState();
}

class ImageUploadPickerState extends State<ImageUploadPicker>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    if (mounted) {
      _controller = AnimationController(
        duration: const Duration(seconds: 2),
        vsync: this,
      )..repeat();
    }
    super.initState();
  }

  @override
  dispose() {
    _controller.dispose(); // you need this

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StackTap(
      onTap: () => _showPickerImage(context),
      child: widget.child ?? Container(),
    );
  }

  void _showPickerImage(context) {
    FocusScope.of(context).unfocus();
    showModalBottomSheet(
      context: context,
      builder: (BuildContext bc) {
        return SafeArea(
          child: Container(
            child: Wrap(
              children: <Widget>[
                ListTile(
                  leading: Icon(Icons.photo_library),
                  title: Text(
                    'อัลบั้มรูปภาพ',
                    style: TextStyle(
                      fontSize: 13,
                      fontFamily: 'Kanit',
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                  onTap: () {
                    _imgFromGallery();
                    Navigator.of(context).pop();
                  },
                ),
                ListTile(
                  leading: Icon(Icons.photo_camera),
                  title: Text(
                    'กล้องถ่ายรูป',
                    style: TextStyle(
                      fontSize: 13,
                      fontFamily: 'Kanit',
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                  onTap: () {
                    _imgFromCamera();
                    Navigator.of(context).pop();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  _imgFromCamera() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 100,
    );
    if (image != null) {
      _upload([image]);
    }
  }

  _imgFromGallery() async {
    final ImagePicker picker = ImagePicker();

    if (widget.allowMultiple) {
      // ถ้าอนุญาตให้เลือกหลายรูป
      final List<XFile> images = await picker.pickMultipleMedia(
        imageQuality: 100,
      );
      if (images.isNotEmpty) {
        _upload(images);
      }
    } else {
      // ถ้าเลือกรูปเดียว (เหมือนเดิม)
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 100,
      );
      if (image != null) {
        _upload([image]); // ส่งเป็น List ที่มี 1 item
      }
    }
  }

  void _upload(List<XFile> images) {
    if (images.isEmpty) return;
    // แปลง List<XFile> เป็น List<File>
    final List<File> imageFiles = images
        .map((image) => File(image.path))
        .toList();
    // เรียก callback พร้อมส่ง List ของไฟล์กลับไป
    widget.callback(imageFiles);
  }
}
