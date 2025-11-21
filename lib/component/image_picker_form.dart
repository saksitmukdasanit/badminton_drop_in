import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class ImagePickerFormField extends FormField<XFile> {

  ImagePickerFormField({
    Key? key,
    required String labelText,
    bool isRequired = false,
    String? initialImageUrl,
    required Function(File) onImageSelected,
    FormFieldSetter<XFile>? onSaved,
    FormFieldValidator<XFile>? validator,
  }) : super(
         key: key,
         initialValue: null,
         validator: (value) {
           if (isRequired && value == null) {
             return 'กรุณาเลือกรูปภาพ';
           }
           if (validator != null) return validator(value);
           return null;
         },
         onSaved: onSaved,
         builder: (FormFieldState<XFile> state) {
           final _picker = ImagePicker();
           XFile? _selectedImage = state.value;

           Future<void> _pickImage(BuildContext context) async {
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
                             state.didChange(image);
                             File imageFile = File(image.path); 
                             onImageSelected(imageFile);
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
                             state.didChange(image);
                             File imageFile = File(image.path); 
                             onImageSelected(imageFile);
                           }
                         },
                       ),
                     ],
                   ),
                 );
               },
             );
           }

           return InputDecorator(
             decoration: InputDecoration(
               filled: true,
               border: const OutlineInputBorder(),
               errorText: state.errorText, // แสดงข้อความ error
               label: RichText(
                 text: TextSpan(
                   text: labelText,
                   style: const TextStyle(color: Colors.black54, fontSize: 16),
                   children: isRequired
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
                 InkWell(
                   onTap: () => _pickImage(state.context),
                   child: Row(
                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
                     children: [
                       Expanded(
                         child: Text(
                          //  _selectedImage?.name ?? 'เลือกหรือถ่ายรูป',
                           (initialImageUrl != null && initialImageUrl.isNotEmpty
                               ? 'มีรูปภาพอยู่แล้ว (กดเพื่อเปลี่ยน)' // 2. ข้อความถ้ามีรูปเดิม
                               : 'กรุณาเลือกรูปภาพ'),
                           style: const TextStyle(fontSize: 16),
                           overflow: TextOverflow.ellipsis,
                         ),
                       ),
                       IconButton(
                         icon: Icon(Icons.camera_alt, color: Colors.grey[600]),
                         onPressed: () => _pickImage(state.context),
                       ),
                     ],
                   ),
                 ),
                 if (_selectedImage != null)
                   Padding(
                     padding: const EdgeInsets.only(top: 16.0),
                     child: ClipRRect(
                       borderRadius: BorderRadius.circular(8),
                       child: Image.file(
                         File(_selectedImage.path),
                         width: double.infinity,
                         height: 200,
                         fit: BoxFit.cover,
                       ),
                     ),
                   )
                 else
                   Padding(
                     padding: const EdgeInsets.only(top: 16.0),
                     child: ClipRRect(
                       borderRadius: BorderRadius.circular(8),
                       child: Image.network(
                         initialImageUrl ??'https://gateway.we-builds.com/wb-document/images/banner/banner_254135409.png',
                         width: double.infinity,
                         fit: BoxFit.cover,
                       ),
                     ),
                   ),
               ],
             ),
           );
         },
       );
}
