import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FirefaCartItemData {
  final String productId;
  final String size;
  final List<String> extras;
  final String note;
  final int unitPrice;
  final int quantity;
  const FirefaCartItemData({required this.productId, required this.size, required this.extras, required this.note, required this.unitPrice, required this.quantity});
  Map<String,dynamic> toJson() => {'productId':productId,'size':size,'extras':extras,'note':note,'unitPrice':unitPrice,'quantity':quantity};
  factory FirefaCartItemData.fromJson(Map<String,dynamic> j) => FirefaCartItemData(productId:j['productId'] as String,size:j['size'] as String,extras:List<String>.from(j['extras'] as List),note:j['note'] as String,unitPrice:j['unitPrice'] as int,quantity:j['quantity'] as int);
}
class FirefaCartData {
  final List<FirefaCartItemData> items;
  final String orderType;
  final String table;
  final String discountType;
  final int discountInput;
  final int taxRate;
  final int serviceRate;
  const FirefaCartData({this.items=const [],this.orderType='Dine In',this.table='A01',this.discountType='Nominal',this.discountInput=0,this.taxRate=0,this.serviceRate=0});
  Map<String,dynamic> toJson() => {'items':items.map((e)=>e.toJson()).toList(),'orderType':orderType,'table':table,'discountType':discountType,'discountInput':discountInput,'taxRate':taxRate,'serviceRate':serviceRate};
  factory FirefaCartData.fromJson(Map<String,dynamic> j) => FirefaCartData(items:(j['items'] as List).map((e)=>FirefaCartItemData.fromJson(Map<String,dynamic>.from(e as Map))).toList(),orderType:j['orderType'] as String,table:j['table'] as String,discountType:j['discountType'] as String,discountInput:j['discountInput'] as int,taxRate:j['taxRate'] as int,serviceRate:j['serviceRate'] as int);
}
class FirefaPersistentCartStore extends ChangeNotifier {
  FirefaPersistentCartStore._();
  static final instance=FirefaPersistentCartStore._();
  static const _key='firefa_carts_v1';
  final Map<String,FirefaCartData> _carts={};
  bool _initialized=false;
  Future<void> _pendingSave=Future.value();
  Future<void> initialize() async {
    if(_initialized)return;
    final prefs=await SharedPreferences.getInstance();
    final raw=prefs.getString(_key);
    if(raw!=null && raw.isNotEmpty){
      final decoded=Map<String,dynamic>.from(jsonDecode(raw) as Map);
      for(final entry in decoded.entries){_carts[entry.key]=FirefaCartData.fromJson(Map<String,dynamic>.from(entry.value as Map));}
    }
    _initialized=true;
    notifyListeners();
  }
  FirefaCartData getCart(String outletId){
    if(!_initialized)throw StateError('Cart store belum diinisialisasi');
    return _carts[outletId]??const FirefaCartData();
  }
  void saveCart(String outletId,FirefaCartData data){
    if(!_initialized)throw StateError('Cart store belum diinisialisasi');
    if(outletId.trim().isEmpty)throw ArgumentError('Outlet tidak valid');
    _carts[outletId]=data;
    final snapshot=jsonEncode(_carts.map((k,v)=>MapEntry(k,v.toJson())));
    _pendingSave=_pendingSave.catchError((Object e){debugPrint('Cart save error: $e');}).then((_)async{
      final prefs=await SharedPreferences.getInstance();
      if(!await prefs.setString(_key,snapshot))throw StateError('Gagal menyimpan cart');
    });
    unawaited(_pendingSave.catchError((Object e){debugPrint('Cart save error: $e');}));
    notifyListeners();
  }
  void clearCart(String outletId){saveCart(outletId,const FirefaCartData());}
  Future<void> waitForPendingSave()=>_pendingSave;
}
