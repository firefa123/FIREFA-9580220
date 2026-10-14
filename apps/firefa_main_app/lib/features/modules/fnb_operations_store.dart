// ignore_for_file: prefer_interpolation_to_compose_strings
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FirefaReservation {
  const FirefaReservation({required this.id, required this.outletId, required this.guest, required this.phone, required this.partySize, required this.at, required this.status, this.table = '', this.note = ''});
  final String id, outletId, guest, phone, status, table, note;
  final int partySize;
  final DateTime at;
  FirefaReservation withStatus(String value) => FirefaReservation(id:id,outletId:outletId,guest:guest,phone:phone,partySize:partySize,at:at,status:value,table:table,note:note);
  Map<String,dynamic> toJson()=>{'id':id,'outletId':outletId,'guest':guest,'phone':phone,'partySize':partySize,'at':at.toIso8601String(),'status':status,'table':table,'note':note};
  factory FirefaReservation.fromJson(Map<String,dynamic> j)=>FirefaReservation(id:j['id'] as String,outletId:j['outletId'] as String,guest:j['guest'] as String,phone:j['phone'] as String? ?? '',partySize:j['partySize'] as int,at:DateTime.parse(j['at'] as String),status:j['status'] as String? ?? 'booked',table:j['table'] as String? ?? '',note:j['note'] as String? ?? '');
}
class FirefaQueueTicket {
  const FirefaQueueTicket({required this.id,required this.outletId,required this.number,required this.guest,required this.partySize,required this.at,required this.status});
  final String id,outletId,number,guest,status; final int partySize; final DateTime at;
  FirefaQueueTicket withStatus(String value)=>FirefaQueueTicket(id:id,outletId:outletId,number:number,guest:guest,partySize:partySize,at:at,status:value);
  Map<String,dynamic> toJson()=>{'id':id,'outletId':outletId,'number':number,'guest':guest,'partySize':partySize,'at':at.toIso8601String(),'status':status};
  factory FirefaQueueTicket.fromJson(Map<String,dynamic> j)=>FirefaQueueTicket(id:j['id'] as String,outletId:j['outletId'] as String,number:j['number'] as String,guest:j['guest'] as String,partySize:j['partySize'] as int,at:DateTime.parse(j['at'] as String),status:j['status'] as String? ?? 'waiting');
}
class FirefaBundleLine {
  const FirefaBundleLine(this.name,this.quantity); final String name; final int quantity;
  Map<String,dynamic> toJson()=>{'name':name,'quantity':quantity};
  factory FirefaBundleLine.fromJson(Map<String,dynamic> j)=>FirefaBundleLine(j['name'] as String,j['quantity'] as int);
}
class FirefaMenuBundle {
  const FirefaMenuBundle({required this.id,required this.outletId,required this.name,required this.lines,required this.price,required this.active});
  final String id,outletId,name; final List<FirefaBundleLine> lines; final int price; final bool active;
  FirefaMenuBundle withActive(bool value)=>FirefaMenuBundle(id:id,outletId:outletId,name:name,lines:lines,price:price,active:value);
  Map<String,dynamic> toJson()=>{'id':id,'outletId':outletId,'name':name,'lines':lines.map((e)=>e.toJson()).toList(),'price':price,'active':active};
  factory FirefaMenuBundle.fromJson(Map<String,dynamic> j)=>FirefaMenuBundle(id:j['id'] as String,outletId:j['outletId'] as String,name:j['name'] as String,lines:(j['lines'] as List).map((e)=>FirefaBundleLine.fromJson(Map<String,dynamic>.from(e as Map))).toList(),price:j['price'] as int,active:j['active'] as bool? ?? true);
}
class FirefaOrderTypePrice {
  const FirefaOrderTypePrice({required this.outletId,required this.type,required this.fee,required this.percent});
  final String outletId,type; final int fee,percent;
  Map<String,dynamic> toJson()=>{'outletId':outletId,'type':type,'fee':fee,'percent':percent};
  factory FirefaOrderTypePrice.fromJson(Map<String,dynamic> j)=>FirefaOrderTypePrice(outletId:j['outletId'] as String,type:j['type'] as String,fee:j['fee'] as int,percent:j['percent'] as int);
}
class FirefaPromo {
  const FirefaPromo({required this.id,required this.outletId,required this.name,required this.code,required this.type,required this.value,required this.minimum,required this.start,required this.end,required this.active});
  final String id,outletId,name,code,type; final int value,minimum; final DateTime start,end; final bool active;
  bool validAt(DateTime now,int subtotal)=>active && !now.isBefore(start) && !now.isAfter(end) && subtotal>=minimum;
  int discountAt(DateTime now,int subtotal){if(!validAt(now,subtotal)) return 0; return (type=='percent'?(subtotal*value/100).round():value).clamp(0,subtotal);}
  FirefaPromo withActive(bool value)=>FirefaPromo(id:id,outletId:outletId,name:name,code:code,type:type,value:this.value,minimum:minimum,start:start,end:end,active:value);
  Map<String,dynamic> toJson()=>{'id':id,'outletId':outletId,'name':name,'code':code,'type':type,'value':value,'minimum':minimum,'start':start.toIso8601String(),'end':end.toIso8601String(),'active':active};
  factory FirefaPromo.fromJson(Map<String,dynamic> j)=>FirefaPromo(id:j['id'] as String,outletId:j['outletId'] as String,name:j['name'] as String,code:j['code'] as String? ?? '',type:j['type'] as String,value:j['value'] as int,minimum:j['minimum'] as int,start:DateTime.parse(j['start'] as String),end:DateTime.parse(j['end'] as String),active:j['active'] as bool? ?? true);
}

class FirefaFnbOperationsStore extends ChangeNotifier {
  FirefaFnbOperationsStore._();
  static final instance=FirefaFnbOperationsStore._();
  static const storageKey='firefa_fnb_operations_v1';
  bool _ready=false; int _r=1,_q=1,_b=1,_p=1;
  final List<FirefaReservation> _reservations=[];
  final List<FirefaQueueTicket> _queue=[];
  final List<FirefaMenuBundle> _bundles=[];
  final Map<String,FirefaOrderTypePrice> _prices={};
  final List<FirefaPromo> _promos=[];
  Future<void> _pending=Future<void>.value();
  Future<void> initialize() async {
    if(_ready)return;
    final prefs=await SharedPreferences.getInstance(); final raw=prefs.getString(storageKey);
    if(raw!=null && raw.isNotEmpty){
      final j=jsonDecode(raw) as Map<String,dynamic>;
      final rs=(j['reservations'] as List? ?? const []).map((e)=>FirefaReservation.fromJson(Map<String,dynamic>.from(e as Map))).toList();
      final qs=(j['queue'] as List? ?? const []).map((e)=>FirefaQueueTicket.fromJson(Map<String,dynamic>.from(e as Map))).toList();
      final bs=(j['bundles'] as List? ?? const []).map((e)=>FirefaMenuBundle.fromJson(Map<String,dynamic>.from(e as Map))).toList();
      final ps=(j['promos'] as List? ?? const []).map((e)=>FirefaPromo.fromJson(Map<String,dynamic>.from(e as Map))).toList();
      final prices=<String,FirefaOrderTypePrice>{};
      for(final e in (j['prices'] as List? ?? const [])){final p=FirefaOrderTypePrice.fromJson(Map<String,dynamic>.from(e as Map));prices[p.outletId+':'+p.type]=p;}
      _reservations..clear()..addAll(rs);_queue..clear()..addAll(qs);_bundles..clear()..addAll(bs);_promos..clear()..addAll(ps);_prices..clear()..addAll(prices);
      _r=j['nextReservation'] as int? ?? 1;_q=j['nextQueue'] as int? ?? 1;_b=j['nextBundle'] as int? ?? 1;_p=j['nextPromo'] as int? ?? 1;
    }
    _ready=true;notifyListeners();
  }
  void _check(){if(!_ready)throw StateError('F&B store belum diinisialisasi');}
  List<FirefaReservation> reservations(String outlet)=>List.unmodifiable(_reservations.where((e)=>e.outletId==outlet).toList()..sort((a,b)=>a.at.compareTo(b.at)));
  List<FirefaQueueTicket> queue(String outlet)=>List.unmodifiable(_queue.where((e)=>e.outletId==outlet).toList()..sort((a,b)=>a.at.compareTo(b.at)));
  List<FirefaMenuBundle> bundles(String outlet)=>List.unmodifiable(_bundles.where((e)=>e.outletId==outlet));
  List<FirefaPromo> promos(String outlet)=>List.unmodifiable(_promos.where((e)=>e.outletId==outlet));
  FirefaOrderTypePrice price(String outlet,String type)=>_prices[outlet+':'+type]??FirefaOrderTypePrice(outletId:outlet,type:type,fee:0,percent:0);
  int typeFee(String outlet,String type,int subtotal){final p=price(outlet,type);return p.fee+(subtotal*p.percent.clamp(0,100)/100).round();}
  int promoDiscount(String outlet,int subtotal,{DateTime? now}){_check();final time=now??DateTime.now();final eligible=_promos.where((p)=>p.outletId==outlet&&p.validAt(time,subtotal)).toList()..sort((a,b)=>b.discountAt(time,subtotal).compareTo(a.discountAt(time,subtotal)));return eligible.isEmpty?0:eligible.first.discountAt(time,subtotal);}
  bool addReservation({required String outlet,required String guest,required String phone,required int partySize,required DateTime at,String table='',String note=''}){_check();if(outlet.trim().isEmpty||guest.trim().isEmpty||partySize<1||partySize>100||phone.length>40||note.length>240)return false;_reservations.add(FirefaReservation(id:'RSV-'+(_r++).toString().padLeft(5,'0'),outletId:outlet,guest:guest.trim(),phone:phone.trim(),partySize:partySize,at:at,status:'booked',table:table.trim(),note:note.trim()));_save();return true;}
  bool setReservationStatus(String outlet,String id,String status){_check();if(!const ['booked','arrived','seated','cancelled','completed'].contains(status))return false;final i=_reservations.indexWhere((e)=>e.outletId==outlet&&e.id==id);if(i<0)return false;_reservations[i]=_reservations[i].withStatus(status);_save();return true;}
  bool addQueue({required String outlet,required String guest,required int partySize}){_check();if(outlet.trim().isEmpty||guest.trim().isEmpty||partySize<1||partySize>100)return false;final number='Q'+(_q++).toString().padLeft(3,'0');_queue.add(FirefaQueueTicket(id:'queue-'+number,outletId:outlet,number:number,guest:guest.trim(),partySize:partySize,at:DateTime.now(),status:'waiting'));_save();return true;}
  bool setQueueStatus(String outlet,String id,String status){_check();if(!const ['waiting','called','seated','completed','cancelled'].contains(status))return false;final i=_queue.indexWhere((e)=>e.outletId==outlet&&e.id==id);if(i<0)return false;_queue[i]=_queue[i].withStatus(status);_save();return true;}
  bool saveBundle({String? id,required String outlet,required String name,required List<FirefaBundleLine> lines,required int price,bool active=true}){_check();final n=name.trim();if(outlet.trim().isEmpty||n.isEmpty||n.length>100||lines.isEmpty||lines.any((e)=>e.name.trim().isEmpty||e.quantity<1||e.quantity>99)||price<1||price>999999999||_bundles.any((e)=>e.outletId==outlet&&e.id!=id&&e.name.toLowerCase()==n.toLowerCase()))return false;if(id==null){_bundles.add(FirefaMenuBundle(id:'BND-'+(_b++).toString().padLeft(4,'0'),outletId:outlet,name:n,lines:List.unmodifiable(lines),price:price,active:active));}else{final i=_bundles.indexWhere((e)=>e.outletId==outlet&&e.id==id);if(i<0)return false;_bundles[i]=FirefaMenuBundle(id:id,outletId:outlet,name:n,lines:List.unmodifiable(lines),price:price,active:active);}_save();return true;}
  bool setBundleActive(String outlet,String id,bool active){_check();final i=_bundles.indexWhere((e)=>e.outletId==outlet&&e.id==id);if(i<0)return false;_bundles[i]=_bundles[i].withActive(active);_save();return true;}
  bool savePrice({required String outlet,required String type,required int fee,required int percent}){_check();if(outlet.trim().isEmpty||!const ['Dine In','Takeaway','Delivery'].contains(type)||fee<0||fee>999999999||percent<0||percent>100)return false;_prices[outlet+':'+type]=FirefaOrderTypePrice(outletId:outlet,type:type,fee:fee,percent:percent);_save();return true;}
  bool savePromo({String? id,required String outlet,required String name,required String code,required String type,required int value,required int minimum,required DateTime start,required DateTime end,bool active=true}){_check();final n=name.trim(),c=code.trim().toUpperCase();if(outlet.trim().isEmpty||n.isEmpty||n.length>100||c.length>30||!const ['percent','nominal'].contains(type)||value<1||(type=='percent'&&value>100)||value>999999999||minimum<0||minimum>999999999||end.isBefore(start)||_promos.any((p)=>p.outletId==outlet&&p.id!=id&&c.isNotEmpty&&p.code==c))return false;if(id==null){_promos.add(FirefaPromo(id:'PROMO-'+(_p++).toString().padLeft(4,'0'),outletId:outlet,name:n,code:c,type:type,value:value,minimum:minimum,start:start,end:end,active:active));}else{final i=_promos.indexWhere((p)=>p.outletId==outlet&&p.id==id);if(i<0)return false;_promos[i]=FirefaPromo(id:id,outletId:outlet,name:n,code:c,type:type,value:value,minimum:minimum,start:start,end:end,active:active);}_save();return true;}
  bool setPromoActive(String outlet,String id,bool active){_check();final i=_promos.indexWhere((p)=>p.outletId==outlet&&p.id==id);if(i<0)return false;_promos[i]=_promos[i].withActive(active);_save();return true;}
  Map<String,dynamic> exportLocalSnapshot()=>{'version':1,'nextReservation':_r,'nextQueue':_q,'nextBundle':_b,'nextPromo':_p,'reservations':_reservations.map((e)=>e.toJson()).toList(),'queue':_queue.map((e)=>e.toJson()).toList(),'bundles':_bundles.map((e)=>e.toJson()).toList(),'prices':_prices.values.map((e)=>e.toJson()).toList(),'promos':_promos.map((e)=>e.toJson()).toList()};
  void validateLocalSnapshot(Map<String,dynamic> j){if(j['version']!=1||j['reservations'] is! List||j['queue'] is! List||j['bundles'] is! List||j['prices'] is! List||j['promos'] is! List)throw const FormatException('Snapshot F&B tidak valid.');for(final e in (j['reservations'] as List)){FirefaReservation.fromJson(Map<String,dynamic>.from(e as Map));}for(final e in (j['queue'] as List)){FirefaQueueTicket.fromJson(Map<String,dynamic>.from(e as Map));}for(final e in (j['bundles'] as List)){FirefaMenuBundle.fromJson(Map<String,dynamic>.from(e as Map));}for(final e in (j['promos'] as List)){FirefaPromo.fromJson(Map<String,dynamic>.from(e as Map));}}
  Future<void> waitForPendingSave()=>_pending;
  void _save(){notifyListeners();final snapshot=jsonEncode(exportLocalSnapshot());_pending=_pending.catchError((Object _){}).then((_)async{final prefs=await SharedPreferences.getInstance();if(!await prefs.setString(storageKey,snapshot))throw StateError('Gagal menyimpan data F&B');});unawaited(_pending.catchError((Object e){debugPrint('F&B save failed: '+e.toString());}));}
}
