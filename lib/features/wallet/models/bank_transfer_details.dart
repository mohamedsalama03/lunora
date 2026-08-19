class BankTransferDetails {
  final String bankName;
  final String accountHolder;
  final String accountNumber;
  final String iban;

  const BankTransferDetails({
    required this.bankName,
    required this.accountHolder,
    required this.accountNumber,
    required this.iban,
  });
}

/// Temporary fallback until the API exposes bank transfer account details.
const kDefaultBankTransferDetails = BankTransferDetails(
  bankName: 'شمال أفريقيا',
  accountHolder: 'شركة تصاميم',
  accountNumber: '00901118418017',
  iban: 'LY47007009009011184181017',
);
