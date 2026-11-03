class Earnings {
  final double totalEarnings;
  final int totalDeliveries;
  final double todayEarnings;
  final int todayDeliveries;
  final double codOutstanding;
  final double codRemitted;
  final List<WeeklyEarning> weekly;

  Earnings({this.totalEarnings = 0, this.totalDeliveries = 0, this.todayEarnings = 0, this.todayDeliveries = 0, this.codOutstanding = 0, this.codRemitted = 0, this.weekly = const []});

  factory Earnings.fromJson(Map<String, dynamic> j) => Earnings(
    totalEarnings: double.tryParse('${j['total_earnings']}') ?? 0,
    totalDeliveries: j['total_deliveries'] is int ? j['total_deliveries'] : int.tryParse('${j['total_deliveries']}') ?? 0,
    todayEarnings: double.tryParse('${j['today_earnings']}') ?? 0,
    todayDeliveries: j['today_deliveries'] is int ? j['today_deliveries'] : int.tryParse('${j['today_deliveries']}') ?? 0,
    codOutstanding: double.tryParse('${j['cod_outstanding']}') ?? 0,
    codRemitted: double.tryParse('${j['cod_remitted']}') ?? 0,
    weekly: j['weekly'] != null ? (j['weekly'] as List).map((x) => WeeklyEarning.fromJson(x)).toList() : [],
  );
}

class WeeklyEarning {
  final String date;
  final double earnings;
  final int deliveries;

  WeeklyEarning({this.date = '', this.earnings = 0, this.deliveries = 0});

  factory WeeklyEarning.fromJson(Map<String, dynamic> j) => WeeklyEarning(
    date: j['date'] ?? '',
    earnings: double.tryParse('${j['earnings']}') ?? 0,
    deliveries: j['deliveries'] is int ? j['deliveries'] : int.tryParse('${j['deliveries']}') ?? 0,
  );
}
