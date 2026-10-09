import 'invoice_model.dart';

class InvoiceController {
  final List<InvoiceModel> invoices = [];

  void addInvoice(InvoiceModel invoice) {
    invoices.add(invoice);
  }

  List<InvoiceModel> getAll() => invoices;
}
