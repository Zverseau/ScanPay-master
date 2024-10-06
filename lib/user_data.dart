class UserData {
  final String fullName;
  String? email;
  String? password;
  String? phoneNumber;
  String? downloadURL;
  String userType;
  final int solde;
  final String? numCompte; // Ajout de la propriété numCompte

  UserData({
    required this.fullName,
    this.email,
    this.password,
    this.phoneNumber,
    this.downloadURL,
    required this.userType,
    required int solde,
    this.numCompte, // Ajout dans le constructeur
  }) : solde = solde.toInt();
}
