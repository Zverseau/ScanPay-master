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
    _refreshTimer = Timer.periodic(Duration(seconds: 1), (timer) {
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
      final response = await http.post(
        Uri.parse('http://192.168.1.78:3000/get_user_data'),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode({'email': widget.email}),
      );

      if (response.statusCode == 200) {
        final userData = jsonDecode(response.body);
        final numCompte = userData['numCompte'];
        print('User Data: $userData'); // Log user data

        final transactionResponse = await http.post(
          Uri.parse('http://192.168.1.78:3000/get_user_transactions'),
          headers: {'Content-Type': 'application/json; charset=UTF-8'},
          body: jsonEncode({'numCompte': numCompte}),
        );

        if (transactionResponse.statusCode == 200) {
          final List<dynamic> data = jsonDecode(transactionResponse.body);
          print('Transactions Data: $data'); // Log transactions data
          return data.map((json) => Transaction.fromJson(json)).toList();
        } else {
          print('Failed to load transactions. Status code: ${transactionResponse.statusCode}');
          throw Exception('Failed to load transactions');
        }
      } else {
        print('Failed to load user data. Status code: ${response.statusCode}');
        throw Exception('Failed to load user data');
      }
    } catch (e) {
      print('Error fetching transactions: $e');
      throw Exception('Error fetching transactions');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Center(child: Text('Historique')),
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
                  Text('Aucune transaction disponible.')
                ],
              ),
            );
          } else {
            return ListView.builder(
              itemCount: snapshot.data!.length,
              itemBuilder: (context, index) {
                final transaction = snapshot.data![index];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                  child: Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15.0),
                    ),
                    color: Colors.grey[200],
                    child: ListTile(
                      contentPadding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      leading: Icon(Icons.monetization_on, color: Colors.green[700]), // Example icon
                      title: Text(
                        'ID: ${transaction.numTransaction}',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        'Montant: ${transaction.amount},\n Date: ${transaction.date}',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      trailing: Text(
                        transaction.status,
                        style: TextStyle(
                          color: transaction.status == 'Effectué' ? Colors.green : Colors.red,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
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

  Transaction({
    required this.date,
    required this.numTransaction,
    required this.amount,
    required this.status,
  });

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      date: json['date'],
      numTransaction: json['numTransaction'],
      amount: json['amount'],
      status: json['status'],
    );
  }
}
