import 'package:equatable/equatable.dart';

class SplitDetail extends Equatable {
  final String userId;
  final double? amount;
  final double? percentage;
  final int? shares;

  const SplitDetail({
    required this.userId,
    this.amount,
    this.percentage,
    this.shares,
  });

  factory SplitDetail.fromJson(Map<String, dynamic> json) {
    return SplitDetail(
      userId: json['userId'] as String,
      amount: (json['amount'] as num?)?.toDouble(),
      percentage: (json['percentage'] as num?)?.toDouble(),
      shares: json['shares'] as int?,
    );
  }

  Map<String, dynamic> toJson() => {
        'userId': userId,
        if (amount != null) 'amount': amount,
        if (percentage != null) 'percentage': percentage,
        if (shares != null) 'shares': shares,
      };

  @override
  List<Object?> get props => [userId, amount, percentage, shares];
}
