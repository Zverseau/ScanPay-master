import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:scanpay/user_data.dart';

class GenererQrcode extends StatefulWidget {
  final String email;

  const GenererQrcode({Key? key, required this.email}) : super(key: key);

  @override
  State<GenererQrcode> createState() => _GenererQrcodeState();
}

class _GenererQrcodeState extends State<GenererQrcode> {
  final TextEditingController _controller = TextEditingController();
  String _qrData = '';
  late Future<UserData> _userDataFuture;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _userDataFuture = _fetchUserData();
  }

  Future<UserData> _fetchUserData() async {
    try {
      final response = await http.post(
        Uri.parse('http://192.168.1.78:3000/get_user_data'),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode({'email': widget.email}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return UserData(
          fullName: data['fullName'] ?? 'Nom inconnu',
          email: widget.email,
          password: data['password'] ?? '',
          phoneNumber: data['phoneNumber'] ?? '',
          solde: data['solde'] ?? 0,
          userType: data['userType'] ?? 'Type inconnu',
          numCompte: data['numCompte'] ?? 'Compte inconnu',
        );
      } else {
        throw Exception('Failed to load user data');
      }
    } catch (e) {
      rethrow;
    }
  }

  void _generateQrCode(UserData userData) {
    final amountText = _controller.text;
    final amount = double.tryParse(amountText);

    if (amount == null || amount <= 0) {
      setState(() {
        _errorMessage = 'Veuillez entrer un montant valide.';
        _qrData = '';
      });
    } else {
      setState(() {
        _qrData = jsonEncode({
          'amount': amount.toString(),
          'numCompteMarchand': userData.numCompte,
        });
        _errorMessage = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Générer le QR Code"),
        backgroundColor: Colors.indigoAccent,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        elevation: 0,
      ),
      backgroundColor: Colors.grey[100],
      body: FutureBuilder<UserData>(
        future: _userDataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Erreur: ${snapshot.error}'));
          } else if (snapshot.hasData) {
            return _buildQrCodeGenerator(snapshot.data!);
          } else {
            return const Center(child: Text('Aucune donnée disponible'));
          }
        },
      ),
    );
  }

  Widget _buildQrCodeGenerator(UserData userData) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Text(
            'Générez votre QR Code',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.indigoAccent,
                ),
          ),
          const SizedBox(height: 20),
          Text(
            'Entrez le montant que vous souhaitez inclure dans le QR Code.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[700],
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 30),
          TextField(
            controller: _controller,
            decoration: InputDecoration(
              labelText: 'Montant',
              hintText: 'Entrez le montant',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15.0),
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            ),
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => _generateQrCode(userData),
            style: ElevatedButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: Colors.teal,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15.0),
              ),
              textStyle: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            child: const Text('Générer'),
          ),
          const SizedBox(height: 20),
          if (_errorMessage.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(
                _errorMessage,
                style: const TextStyle(color: Colors.red, fontSize: 16),
              ),
            ),
          if (_qrData.isNotEmpty)
            Expanded(
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.teal),
                    borderRadius: BorderRadius.circular(15),
                    color: Colors.white,
                  ),
                  child: QrImageView(
                    data: _qrData,
                    size: 250.0,
                    foregroundColor: Colors.indigoAccent,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
