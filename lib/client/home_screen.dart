import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import '../user_data.dart';
import 'scanner_screen.dart';
import 'transactions_screen.dart';

class HomePage extends StatefulWidget {
  final String email;

  const HomePage({Key? key, required this.email}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;
  late Future<Map<String, dynamic>> _dataFuture;

  @override
  void initState() {
    super.initState();
    _dataFuture = _fetchData();
  }

  Future<void> _fetchDataAndUpdate() async {
    try {
      final data = await _fetchData();
      setState(() {
        _dataFuture = Future.value(data);
      });
    } catch (e) {
      // Gérer les erreurs si nécessaire
    }
  }

  Future<Map<String, dynamic>> _fetchData() async {
    final userResponse = await http.post(
      Uri.parse('http://192.168.1.78:3000/get_user_data'),
      headers: {'Content-Type': 'application/json; charset=UTF-8'},
      body: jsonEncode({'email': widget.email}),
    );

    if (userResponse.statusCode != 200) {
      throw Exception('Échec du chargement des données utilisateur');
    }

    final userData = jsonDecode(userResponse.body);

    final transactionsResponse = await http.post(
      Uri.parse('http://192.168.1.78:3000/get_user_transactions'),
      headers: {'Content-Type': 'application/json; charset=UTF-8'},
      body: jsonEncode({'numCompte': userData['numCompte']}),
    );

    if (transactionsResponse.statusCode != 200) {
      throw Exception('Échec du chargement des transactions');
    }

    final transactions = jsonDecode(transactionsResponse.body);

    return {
      'userData': UserData(
        fullName: userData['fullName'],
        email: widget.email,
        password: userData['password'] ?? '',
        phoneNumber: '', // Ajouter la récupération du numéro si nécessaire
        numCompte: userData['numCompte'] ?? '',
        solde: userData['solde'],
        userType: userData['userType'],
      ),
      'transactions': transactions,
    };
  }

  Future<void> _refreshData() async {
    setState(() {
      _dataFuture = _fetchData();
    });
  }

  void _showRechargeOptions(UserData userData) {
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
        'password': password, // Inclure le mot de passe dans la demande
      }),
    );

    if (response.statusCode == 200) {
      final responseBody = jsonDecode(response.body);
      if (responseBody['success']) {
        _showSuccessDialog('Recharge effectuée avec succès.');
        _refreshData();
      } else {
        _showErrorDialog(responseBody['message'] ??
            'Échec de la recharge. Veuillez réessayer.');
      }
    } else {
      // Traitement des autres statuts HTTP avec messages spécifiques
      final responseBody = jsonDecode(response.body);
      if (responseBody['error'] != null) {
        _showErrorDialog(responseBody['error']);
      } else {
        _showErrorDialog('Échec de la recharge. Veuillez réessayer.');
      }
    }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: FutureBuilder<Map<String, dynamic>>(
        future: _dataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SizedBox.shrink();
          } else if (snapshot.hasError) {
            return Center(child: Text('Erreur : ${snapshot.error}'));
          } else if (!snapshot.hasData) {
            return const Center(child: Text('Aucune donnée trouvée.'));
          } else {
            final data = snapshot.data!;
            return IndexedStack(
              index: _currentIndex,
              children: [
                _buildHome(data['userData'], data['transactions']),
                ScannerScreen(email: widget.email),
                TransactionsScreen(email: widget.email),
              ],
            );
          }
        },
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) async {
          setState(() {
            _currentIndex = index;
          });
          await _refreshData();
        },
        backgroundColor: Colors.white,
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.qr_code_2),
            label: 'Scanner',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'Historique',
          ),
        ],
      ),
    );
  }

  Widget _buildHome(UserData userData, List<dynamic> transactions) {
    return Column(
      children: [
        BankCard(userData: userData),
        const SizedBox(height: 35),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 19.0),
          child: Center(
            child: ElevatedButton(
              onPressed: () => _showRechargeOptions(userData),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.yellow[700],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('Recharger'),
            ),
          ),
        ),
        Expanded(
          child: TransactionsList(transactions: transactions),
        ),
      ],
    );
  }
}

class BankCard extends StatelessWidget {
  final UserData userData;

  const BankCard({Key? key, required this.userData}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 50.0, left: 19.0, right: 19.0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15.0),
            ),
            color: Colors.indigoAccent,
            child: Container(
              width: constraints.maxWidth * 0.97,
              height: 200,
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'UTILISATEUR',
                        style: TextStyle(
                          color: Colors.yellow[700],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        userData.fullName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Solde',
                            style: TextStyle(
                              color: Colors.yellow[700],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${userData.solde} \XOF',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Type Utilisateur',
                            style: TextStyle(
                              color: Colors.yellow[700],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            userData.userType,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
class TransactionsList extends StatelessWidget {
  final List<dynamic> transactions;

  const TransactionsList({Key? key, required this.transactions})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (transactions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shopping_cart_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Vos dernières courses ici.',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(
              left: 16.0, right: 16.0, top: 18.0, bottom: 4.0),
          child: Text(
            'Transactions récentes',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: transactions.length,
            itemBuilder: (context, index) {
              final transaction = transactions[index];
              return Padding(
                padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                child: Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20.0), // Augmenter le rayon de la bordure ici
                  ),
                  color: Colors.grey[200],
                  child: ListTile(
                    contentPadding:
                    EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    leading: Icon(Icons.shopping_bag_outlined,
                        color: Colors.green[700]),
                    title: Text(transaction['description'] ?? 'Payement'),
                    subtitle: Text(
                        'Date: ${transaction['date'] ?? 'Date indisponible'} '),
                    trailing: Text(
                      '${transaction['amount']}',
                      style: TextStyle(
                        color: Colors.redAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
