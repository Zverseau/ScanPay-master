import 'package:flutter/material.dart';
import 'package:scanpay/marchand/historique_transaction.dart';
import 'package:scanpay/marchand/qrcode_gen.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:scanpay/user_data.dart';

import '../client/home_screen.dart';

class SellerPage extends StatefulWidget {
  final String email;

  const SellerPage({Key? key, required this.email}) : super(key: key);

  @override
  State<SellerPage> createState() => _SellerPageState();
}

class _SellerPageState extends State<SellerPage> {
  int _currentIndex = 0;
  final ValueNotifier<Map<String, dynamic>?> _dataNotifier =
  ValueNotifier(null);
  Timer? _timer; // Timer pour actualisation automatique

  @override
  void initState() {
    super.initState();
    _loadData();
    _startAutoRefresh();
  }

  @override
  void dispose() {
    _timer?.cancel(); // Annuler le Timer lorsque la page est fermée
    super.dispose();
  }

  void _startAutoRefresh() {
    _timer = Timer.periodic(Duration(seconds: 4), (timer) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    try {
      final data = await _fetchData();
      _dataNotifier.value = data;
    } catch (e) {
      _dataNotifier.value = {'userData': null, 'transactions': []};
    }
  }

  Future<Map<String, dynamic>> _fetchData() async {
    final userResponse = await http.post(
      Uri.parse('http://192.168.1.78:3000/get_user_data'),
      headers: {'Content-Type': 'application/json; charset=UTF-8'},
      body: jsonEncode({'email': widget.email}),
    );

    if (userResponse.statusCode != 200) {
      throw Exception('Failed to load user data');
    }

    final userData = jsonDecode(userResponse.body);

    final transactionsResponse = await http.post(
      Uri.parse('http://192.168.1.78:3000/get_user_transactions'),
      headers: {'Content-Type': 'application/json; charset=UTF-8'},
      body: jsonEncode({'numCompte': userData['numCompte']}),
    );

    if (transactionsResponse.statusCode != 200) {
      throw Exception('Failed to load transactions');
    }

    final transactions = jsonDecode(transactionsResponse.body);

    return {
      'userData': UserData(
        fullName: userData['fullName'] ?? 'Nom inconnu',
        email: widget.email,
        password: userData['password'] ?? '',
        phoneNumber: '',
        numCompte: userData['numCompte'] ?? '',
        solde: userData['solde'] ?? 0,
        userType: userData['userType'] ?? 'Type inconnu',
      ),
      'transactions': transactions ?? [],
    };
  }

  Widget _buildBody(UserData userData, List<dynamic> transactions) {
    return IndexedStack(
      index: _currentIndex,
      children: [
        _buildHome(userData, transactions),
        GenererQrcode(email: userData.email ?? ''),
        TransactionsScreen(email: userData.email ?? ''),
      ],
    );
  }

  Widget _buildHome(UserData userData, List<dynamic> transactions) {
    return Column(
      children: [
        BankCard(userData: userData),
        SizedBox(height: 35), // Add some space between the card and buttons
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 19.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: <Widget>[
              ElevatedButton(
                onPressed: () async {
                  await _showRechargeOptions(userData);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.yellow[700], // Button color
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text('Recharger'),
              ),
              ElevatedButton(
                onPressed: () async {
                  await _showWithdrawOptions(userData);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent, // Button color
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text('Retirer'),
              ),
            ],
          ),
        ),
        Expanded(
          child: TransactionsList(transactions: transactions),
        ),
      ],
    );
  }

  // ZONE POUR LA RECHARGE
  Future<void> _showRechargeOptions(UserData userData) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choisissez un mode de recharge'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _showAmountInput(userData, 'T-money');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: const Text('T-money'),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _showAmountInput(userData, 'Flooz');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              child: const Text('Flooz'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAmountInput(UserData userData, String mode) {
    TextEditingController amountController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(mode),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Montant',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showPasswordInput(userData, mode, amountController.text);
            },
            child: const Text('Suivant'),
          ),
        ],
      ),
    );
  }

  void _showPasswordInput(UserData userData, String mode, String amount) {
    TextEditingController passwordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sécurité'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Mot de passe',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _processRecharge(
                  userData, mode, amount, passwordController.text);
            },
            child: const Text('Terminer'),
          ),
        ],
      ),
    );
  }

  Future<void> _processRecharge(
      UserData userData, String mode, String amount, String password) async {
    // Envoyer la demande de recharge au serveur
    final response = await http.post(
      Uri.parse('http://192.168.1.78:3000/recharge_account'),
      headers: {'Content-Type': 'application/json; charset=UTF-8'},
      body: jsonEncode({
        'numCompte': userData.numCompte,
        'montant': amount,
        'mode': mode,
        'password':
        password, // Passer le mot de passe au serveur pour validation
      }),
    );

    final responseData = jsonDecode(response.body);

    if (response.statusCode == 200) {
      if (responseData['success']) {
        _showSuccessDialog('Recharge effectuée avec succès.');
        await _loadData(); // Rafraîchir les données après recharge
      } else {
        _showErrorDialog(responseData['message'] ??
            'Échec de la recharge. Veuillez réessayer.');
      }
    } else {
      // Traitement des autres statuts HTTP avec messages spécifiques
      if (responseData['error'] != null) {
        _showErrorDialog(responseData['error']);
      } else {
        _showErrorDialog('Échec de la recharge. Veuillez réessayer.');
      }
    }
  }

  // ZONE POUR LE RETRAIT
  Future<void> _showWithdrawOptions(UserData userData) async {
    showDialog(
        context: context,
        builder: (context) => AlertDialog(
        title: const Text('Choisissez un mode de retrait'),
    content: Column(
    mainAxisSize: MainAxisSize.min,
    children: [
    ElevatedButton(
    onPressed: () {
    Navigator.pop(context);
    _showWithdrawAmountInput(userData, 'T-money');
    },
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      child: const Text('T-money'),
    ),
      const SizedBox(height: 10),
      ElevatedButton(
        onPressed: () {
          Navigator.pop(context);
          _showWithdrawAmountInput(userData, 'Flooz');
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
        ),
        child: const Text('Flooz'),
      ),
    ],
    ),
        ),
    );
  }

  void _showWithdrawAmountInput(UserData userData, String mode) {
    TextEditingController amountController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(mode),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Montant',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showWithdrawPasswordInput(
                  userData, mode, amountController.text);
            },
            child: const Text('Suivant'),
          ),
        ],
      ),
    );
  }

  void _showWithdrawPasswordInput(
      UserData userData, String mode, String amount) {
    TextEditingController passwordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sécurité'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Mot de passe',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _processWithdraw(
                  userData, mode, amount, passwordController.text);
            },
            child: const Text('Terminer'),
          ),
        ],
      ),
    );
  }

  Future<void> _processWithdraw(
      UserData userData, String mode, String amount, String password) async {
    // Envoyer la demande de retrait au serveur
    final response = await http.post(
      Uri.parse('http://192.168.1.78:3000/withdraw_account'),
      headers: {'Content-Type': 'application/json; charset=UTF-8'},
      body: jsonEncode({
        'numCompte': userData.numCompte,
        'montant': amount,
        'mode': mode,
        'password':
        password, // Passer le mot de passe au serveur pour validation
      }),
    );

    final responseData = jsonDecode(response.body);

    if (response.statusCode == 200) {
      if (responseData['success']) {
        _showSuccessDialog('Retrait effectué avec succès.');
        await _loadData(); // Rafraîchir les données après le retrait
      } else {
        _showErrorDialog(responseData['message'] ??
            'Échec du retrait. Veuillez réessayer.');
      }
    } else {
      // Traitement des autres statuts HTTP avec messages spécifiques
      if (responseData['error'] != null) {
        _showErrorDialog(responseData['error']);
      } else {
        _showErrorDialog('Échec du retrait. Veuillez réessayer.');
      }
    }
  }

  void _showSuccessDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Succès'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Erreur'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ValueListenableBuilder<Map<String, dynamic>?>(
        valueListenable: _dataNotifier,
        builder: (context, data, child) {
          if (data == null) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final userData = data['userData'] as UserData?;
          final transactions = data['transactions'] as List<dynamic>?;

          if (userData == null || transactions == null) {
            return const Center(
              child: Text('Erreur lors du chargement des données.'),
            );
          }

          return _buildBody(userData, transactions);
        },
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Accueil',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.qr_code),
            label: 'QR Code',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'Historique',
          ),
        ],
      ),
    );
  }
}

