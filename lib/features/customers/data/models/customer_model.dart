class Customer {
  final int id;
  final String name;
  final String phone;
  final double clv;
  final String riskScore;
  final double churnProbability;

  Customer({
    required this.id,
    required this.name,
    required this.phone,
    required this.clv,
    required this.riskScore,
    required this.churnProbability,
  });

  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(
      id: json['id'],
      name: json['name'],
      phone: json['primary_phone'],
      clv: double.parse(json['clv'].toString()),
      riskScore: json['risk_score'],
      churnProbability: double.parse(json['churn_probability'].toString()),
    );
  }
}
