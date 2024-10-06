import 'package:flutter/material.dart';
import 'package:flutter_barcode_scanner/flutter_barcode_scanner.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ScannerScreen extends StatefulWidget {
  final String email;

  ScannerScreen({required this.email});

  @override
  _ScannerScreenState createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  String qrCodeResult = "Scannez un code QR";
  bool isProcessing = false;
  String? numCompteClient;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    try {
      final response = await http.post(
        Uri.parse('http://192.168.1.78:3000/get_user_data'),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode({'email': widget.email}),
      );

      if (response.statusCode == 200) {
        final userData = jsonDecode(response.body);
        setState(() {
          numCompteClient = userData['numCompte'];
        });
      } else {
        print(
            "Erreur lors de la récupération des données utilisateur: ${response.reasonPhrase}");
      }
    } catch (e) {
      print("Erreur: $e");
    }
  }

  Future<void> startScan() async {
    String scanResult;
    try {
      scanResult = await FlutterBarcodeScanner.scanBarcode(
        "#4F5AFF",
        "Annuler",
        true,
        ScanMode.QR,
      );

      if (scanResult == '-1') {
        scanResult = "Le scan a été annulé";
      }
    } catch (e) {
      scanResult = 'Erreur: $e';
    }

    if (scanResult.isNotEmpty && scanResult != "Le scan a été annulé") {
      setState(() {
        qrCodeResult = scanResult;
      });

      _showConfirmationDialog(scanResult);
    }
  }

  void _showConfirmationDialog(String qrData) {
    final qrCodeData = jsonDecode(qrData);
    final numCompteMarchand = qrCodeData['numCompteMarchand'];
    final amount = double.parse(qrCodeData['amount']);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Confirmation de Transaction'),
          content: Text(
              'Vous êtes sur le point de payer $amount au compte marchand $numCompteMarchand.'),
          actions: <Widget>[
            TextButton(
              child: Text('Annuler'),
              onPressed: () {
                Navigator.of(context).pop(); // Ferme la boîte de dialogue
                setState(() {
                  qrCodeResult =
                      "La transaction a été annulée"; // Affiche le message d'annulation
                });
              },
            ),
            TextButton(
              child: Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
                _processTransaction(qrData);
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _processTransaction(String qrData) async {
    if (numCompteClient == null) {
      setState(() {
        qrCodeResult = "Erreur: numéro de compte client introuvable";
      });
      return;
    }

    setState(() {
      isProcessing = true;
    });

    try {
      final qrCodeData = jsonDecode(qrData);
      final numCompteMarchand = qrCodeData['numCompteMarchand'];
      final amount = double.parse(qrCodeData['amount']);

      if (amount <= 0) {
        setState(() {
          qrCodeResult = "Le montant doit être supérieur à zéro.";
        });
        return;
      }

      final response = await http.post(
        Uri.parse('http://192.168.1.78:3000/api/process_transaction'),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode({
          'numCompteClient': numCompteClient,
          'numCompteMarchand': numCompteMarchand,
          'amount': amount,
        }),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        setState(() {
          qrCodeResult =
              responseData['message'] ?? "Transaction effectuée avec succès";
        });
      } else {
        setState(() {
          qrCodeResult = "Erreur de transaction: ${response.reasonPhrase}";
        });
      }
    } catch (e) {
      setState(() {
        qrCodeResult = "Erreur: $e";
      });
    } finally {
      setState(() {
        isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Center(
          child: Text('Scanner QR'),
        ),
        backgroundColor: Colors.indigoAccent,
        automaticallyImplyLeading: false,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: isProcessing
              ? CircularProgressIndicator()
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    Icon(
                      Icons.qr_code_scanner_outlined,
                      color: Colors.indigoAccent,
                      size: 300,
                    ),
                    SizedBox(height: 30.0),
                    Text(
                      qrCodeResult,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18.0,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    SizedBox(height: 30.0),
                    ElevatedButton(
                      onPressed: startScan,
                      child: Text('Commencer le scan'),
                      style: ElevatedButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: Colors.indigoAccent,
                        padding:
                            EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        textStyle: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    SizedBox(height: 20.0),
                    if (qrCodeResult.startsWith('Erreur'))
                      Padding(
                        padding: const EdgeInsets.only(top: 20.0),
                        child: Text(
                          qrCodeResult,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16.0,
                            fontWeight: FontWeight.bold,
                            color: Colors.redAccent,
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}
