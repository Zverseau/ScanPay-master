import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async'; // Import Timer

class TransactionsScreen extends StatefulWidget {
  final String email;

  const TransactionsScreen({Key? key, required this.email}) : super(key: key);

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  late Future<List<Transaction>> _transactionsFuture;
  late Timer _refreshTimer; // Timer for automatic refresh

  @override
  void initState() {
    super.initState();
    _fetchTransactionsData();
    // Set up a timer to refresh data every 5 minutes
    _refreshTimer = Timer.periodic(Duration(seconds: 2), (timer) {
      _fetchTransactionsData();
    });
  }

  @override
  void dispose() {
    _refreshTimer.cancel(); // Cancel the timer when the widget is disposed
    super.dispose();
  }

  void _fetchTransactionsData() {
    setState(() {
      _transactionsFuture = _fetchTransactions();
    });
  }

  Future<List<Transaction>> _fetchTransactions() async {
    try {
      final userResponse = await http.post(
        Uri.parse('http://192.168.1.78:3000/get_user_data'),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode({'email': widget.email}),
      );

      if (userResponse.statusCode == 200) {
        final userData = jsonDecode(userResponse.body);
        final numCompte = userData['numCompte'];

        final transactionResponse = await http.post(
          Uri.parse('http://192.168.1.78:3000/get_user_transactions'),
          headers: {'Content-Type': 'application/json; charset=UTF-8'},
          body: jsonEncode({'numCompte': numCompte}),
        );

        if (transactionResponse.statusCode == 200) {
          final List<dynamic> data = jsonDecode(transactionResponse.body);
          return data.map((json) => Transaction.fromJson(json)).toList();
        } else {
          _showErrorSnackbar('Échec de la récupération des transactions');
          return [];
        }
      } else {
        _showErrorSnackbar('Échec de la récupération des données utilisateur');
        return [];
      }
    } catch (error) {
      _showErrorSnackbar('Erreur : $error');
      return [];
    }
  }

  Future<void> _rejectTransaction(Transaction transaction) async {
    try {
      final amount = transaction.amount.replaceAll(RegExp(r'[^0-9.]'), '');

      final response = await http.post(
        Uri.parse('http://192.168.1.78:3000/reject_transaction'),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode({
          'numTransaction': transaction.numTransaction,
          'amount': amount,
          'numCompteClient': transaction.numCompteClient,
          'numCompteMarchand': transaction.numCompteMarchand,
        }),
      );

      if (response.statusCode == 200) {
        setState(() {
          _fetchTransactionsData(); // Rafraîchir les données après le rejet
        });
        _showSuccessSnackbar('Transaction rejetée avec succès.');
      } else {
        // Afficher le message d'erreur spécifique renvoyé par l'endpoint
        final errorMessage = response.body.isNotEmpty
            ? response.body
            : 'Échec du rejet de la transaction.';
        _showErrorSnackbar(errorMessage);
      }
    } catch (error) {
      _showErrorSnackbar('Erreur : $error');
    }
  }

  void _showConfirmationDialog(Transaction transaction) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Confirmer le rejet'),
          content: Text('Êtes-vous sûr de vouloir rejeter cette transaction ?'),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Ferme la boîte de dialogue
              },
              child: Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(); // Ferme la boîte de dialogue
                _rejectTransaction(transaction); // Rejette la transaction
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              child: Text('Rejeter'),
            ),
          ],
        );
      },
    );
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message, style: TextStyle(color: Colors.red))),
    );
  }

  void _showSuccessSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message, style: TextStyle(color: Colors.green))),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Rejetée':
        return Colors.red;
      case 'Effectué':
        return Colors.green;
      default:
        return Colors.black;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Center(
          child: Text('Historique des Transactions'),
        ),
        backgroundColor: Colors.indigoAccent,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
      ),
      body: FutureBuilder<List<Transaction>>(
        future: _transactionsFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Erreur : ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.hourglass_empty, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'Aucune transaction disponible.',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                ],
              ),
            );
          } else {
            return ListView.builder(
              itemCount: snapshot.data!.length,
              itemBuilder: (context, index) {
                final transaction = snapshot.data![index];
                return Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 4.0),
                  child: Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15.0),
                    ),
                    color: Colors.grey[200],
                    child: ListTile(
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      leading:
                          Icon(Icons.monetization_on, color: Colors.green[700]),
                      title: Text(
                        'ID: ${transaction.numTransaction}',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Montant: ${transaction.amount}'),
                          Text('Date: ${transaction.date}'),
                          Text(
                            'Status: ${transaction.status}',
                            style: TextStyle(
                                color: _getStatusColor(transaction.status)),
                          ),
                        ],
                      ),
                      trailing: transaction.status != 'Rejetée'
                          ? ElevatedButton(
                              onPressed: () {
                                _showConfirmationDialog(transaction);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15.0),
                                ),
                              ),
                              child: const Text(
                                'Rejeter',
                                style: TextStyle(color: Colors.white),
                              ),
                            )
                          : null,
                    ),
                  ),
                );
              },
            );
          }
        },
      ),
    );
  }
}

class Transaction {
  final String date;
  final String numTransaction;
  final String amount;
  final String status;
  final String numCompteClient;
  final String numCompteMarchand;

  Transaction({
    required this.date,
    required this.numTransaction,
    required this.amount,
    required this.status,
    required this.numCompteClient,
    required this.numCompteMarchand,
  });

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      date: json['date'] ?? 'N/A',
      numTransaction: json['numTransaction'] ?? 'N/A',
      amount: json['amount'] ?? '0.0',
      status: json['status'] ?? 'N/A',
      numCompteClient: json['numCompteClient'] ?? 'N/A',
      numCompteMarchand: json['numCompteMarchand'] ?? 'N/A',
    );
  }
}
