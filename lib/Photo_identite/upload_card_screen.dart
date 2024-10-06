import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:scanpay/type_user/user_type.dart';
import 'package:scanpay/user_data.dart';

class UploadCard extends StatefulWidget {
  final UserData userData;
  const UploadCard({Key? key, required this.userData}) : super(key: key);

  @override
  State<UploadCard> createState() => _UploadCardState();
}

class _UploadCardState extends State<UploadCard> {
  final ImagePicker _picker = ImagePicker();
  XFile? _imageFile;
  bool _photoUploaded = false;
  bool _isUploading = false;
  String? _downloadURL;

  Future<void> _pickImage(ImageSource source) async {
    final pickedFile = await _picker.pickImage(source: source);
    setState(() {
      _imageFile = pickedFile;
      _photoUploaded = true;
    });
  }

  Future<void> _requestPermission(Permission permission) async {
    final status = await permission.request();
    if (status != PermissionStatus.granted) {
      // Permission rejected
    }
  }

  Future<void> _uploadImage() async {
    if (_imageFile == null) return;

    setState(() {
      _isUploading = true;
    });

    try {
      print('Uploading image: ${_imageFile!.path}');
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('uploads/${DateTime.now().millisecondsSinceEpoch}.png');
      final uploadTask = storageRef.putFile(File(_imageFile!.path));

      final snapshot = await uploadTask.whenComplete(() {});
      final downloadURL = await snapshot.ref.getDownloadURL();

      setState(() {
        _downloadURL = downloadURL;
        _isUploading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload successful! ')), //URL: $_downloadURL
      );
    } catch (e) {
      print('Failed to upload image: $e');
      setState(() {
        _isUploading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to upload image: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Votre carte d\'identité'),
        backgroundColor: Colors.indigoAccent,
        foregroundColor: Colors.white,
      ),
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            _photoUploaded
                ? Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                border: Border.all(
                  color: Colors.indigoAccent,
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(10.0),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10.0),
                child: _downloadURL != null
                    ? Image.network(
                  _downloadURL!,
                  fit: BoxFit.cover,
                )
                    : Image.file(
                  File(_imageFile!.path),
                  fit: BoxFit.cover,
                ),
              ),
            )
                : Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                color: Colors.indigoAccent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10.0),
                border: Border.all(
                  color: Colors.indigoAccent,
                  width: 2,
                ),
              ),
              child: const Icon(
                Icons.photo,
                size: 100,
                color: Colors.indigoAccent,
              ),
            ),
            const SizedBox(height: 20),
            _isUploading
                ? CircularProgressIndicator()
                : _photoUploaded
                ? Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: () async {
                    setState(() {
                      _imageFile = null;
                      _photoUploaded = false;
                    });
                    await _requestPermission(Permission.camera);
                    _pickImage(ImageSource.camera);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigoAccent,
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.0),
                    ),
                  ),
                  child: const Text(
                    'Resélectionner',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: () async {
                    await _uploadImage();
                    widget.userData.downloadURL = _downloadURL; // Store downloadURL in UserData
                    //await _sendUserDataToBackend();
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            UserTypePage(userData: widget.userData, email: '',),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigoAccent,
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.0),
                    ),
                  ),
                  child: const Text(
                    'Valider',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            )
                : Column(
              children: [
                ElevatedButton(
                  onPressed: () async {
                    await _requestPermission(Permission.camera);
                    _pickImage(ImageSource.camera);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigoAccent,
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.0),
                    ),
                  ),
                  child: const Text(
                    'Prendre une photo',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: () async {
                    await _requestPermission(Permission.photos);
                    _pickImage(ImageSource.gallery);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigoAccent,
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.0),
                    ),
                  ),
                  child: const Text(
                    'Sélectionner depuis la galerie',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}