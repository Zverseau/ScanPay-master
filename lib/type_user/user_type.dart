import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:scanpay/user_data.dart';

import '../inscription/login_screen.dart';

class UserTypePage extends StatefulWidget {
  final UserData userData;
  final String email;

  const UserTypePage({super.key, required this.userData, required this.email});

  @override
  State<UserTypePage> createState() => _UserTypePageState();
}

class _UserTypePageState extends State<UserTypePage> {
  String? _userType;

  void _navigateToLoginPage() async {
    if (_userType != null) {
      widget.userData.userType = _userType!;
      await _sendUserDataToBackend(); // Send data to backend

      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => LoginPage()), // Naviguer vers la page de connexion
      );
    }
  }

  Future<void> _sendUserDataToBackend() async {
    final url = Uri.parse('http://192.168.1.78:3000/insert_user_data');
    final response = await http.post(
      url,
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: jsonEncode(<String, dynamic>{
        'fullName': widget.userData.fullName,
        'email': widget.userData.email,
        'password': widget.userData.password,
        'phoneNumber': widget.userData.phoneNumber,
        'downloadURL': widget.userData.downloadURL,
        'userType': widget.userData.userType,
        'solde': widget.userData.solde,
      }),
    );

    if (response.statusCode == 200) {
      print('Data sent successfully');
    } else {
      throw Exception('Failed to send data');
    }
  }

  Widget _buildCategoryButton(String title, IconData icon, String userType) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _userType = userType;
        });
        _navigateToLoginPage();
      },
      child: Container(
        margin: const EdgeInsets.all(8.0),
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: Colors.indigoAccent.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12.0),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40.0, color: Colors.indigoAccent),
            const SizedBox(height: 10.0),
            Text(
              title,
              style: const TextStyle(
                color: Colors.indigoAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Type d\'utilisateur'),
        backgroundColor: Colors.indigoAccent,
        foregroundColor: Colors.white,
      ),
      body: Container(
        color: Colors.white,
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 16.0,
            mainAxisSpacing: 16.0,
            shrinkWrap: true,
            children: [
              _buildCategoryButton('Marchand', Icons.store, 'Marchand'),
              _buildCategoryButton('Client', Icons.person, 'Client'),
            ],
          ),
        ),
      ),
    );
  }
}
