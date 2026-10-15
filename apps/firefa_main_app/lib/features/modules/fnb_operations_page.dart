// ignore_for_file: prefer_interpolation_to_compose_strings
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/auth/role_permissions.dart';
import '../../core/outlet/active_outlet_store.dart';
import 'fnb_operations_store.dart';
import 'menu_store.dart';
import 'table_store.dart';
import 'order_models.dart';
import 'order_store.dart';

class FnbOperationsPage extends StatefulWidget {
  const FnbOperationsPage({super.key});
  @override
  State<FnbOperationsPage> createState()=>_FnbOperationsPageState();
}
class _FnbOperationsPageState extends State<FnbOperationsPage> with SingleTickerProviderStateMixin {
  final outlet=FirefaActiveOutletStore.instance;
  final store=FirefaFnbOperationsStore.instance;
  final orders=FirefaOrderStore.instance;
  late final Future<void> ready;
  late final TabController tabs;
  static const primary=Color(0xFF008F83);
  bool get canManage=>FirefaAccess.can(outlet.role,FirefaPermission.menuManage);
  @override void initState(){super.initState();tabs=TabController(length:6,vsync:this);ready=Future.wait([store.initialize(),orders.initialize(),FirefaMenuStore.instance.initialize(),FirefaTableStore.instance.initialize()]);store.addListener(refresh);orders.addListener(refresh);outlet.addListener(refresh);}
  void refresh(){if(mounted)setState((){});}
  @override void dispose(){store.removeListener(refresh);orders.removeListener(refresh);outlet.removeListener(refresh);tabs.dispose();super.dispose();}
  String money(int v)=>'Rp '+v.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'),(_)=>'.');
  void message(String text){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(text)));}
  Future<void> addReservation() async {
    final guest=TextEditingController(),phone=TextEditingController(),party=TextEditingController(text:'2'),table=TextEditingController(),note=TextEditingController();
    DateTime at=DateTime.now().add(const Duration(hours:1));
    final ok=await showDialog<bool>(context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,update)=>AlertDialog(title:const Text('Reservasi Baru'),content:SizedBox(width:420,child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
      TextField(controller:guest,decoration:const InputDecoration(labelText:'Nama tamu')),
      TextField(controller:phone,decoration:const InputDecoration(labelText:'Nomor telepon'),keyboardType:TextInputType.phone),
      TextField(controller:party,decoration:const InputDecoration(labelText:'Jumlah tamu'),keyboardType:TextInputType.number),
      TextField(controller:table,decoration:const InputDecoration(labelText:'Meja (opsional)')),
      TextField(controller:note,decoration:const InputDecoration(labelText:'Catatan (opsional)')),
      const SizedBox(height:8),Row(children:[Expanded(child:Text('Jadwal: '+MaterialLocalizations.of(ctx).formatMediumDate(at)+' '+MaterialLocalizations.of(ctx).formatTimeOfDay(TimeOfDay.fromDateTime(at)))),TextButton(onPressed:()async{final d=await showDatePicker(context:ctx,initialDate:at.isBefore(DateTime.now())?DateTime.now():at,firstDate:DateTime.now().subtract(const Duration(days:1)),lastDate:DateTime.now().add(const Duration(days:365)));if(d!=null)update(()=>at=DateTime(d.year,d.month,d.day,at.hour,at.minute));},child:const Text('Tanggal')),TextButton(onPressed:()async{final t=await showTimePicker(context:ctx,initialTime:TimeOfDay.fromDateTime(at));if(t!=null)update(()=>at=DateTime(at.year,at.month,at.day,t.hour,t.minute));},child:const Text('Jam'))])
    ]))),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Batal')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Simpan'))])));
    if(ok==true){final knownTables=FirefaTableStore.instance.forOutlet(outlet.selectedOutletId);if(table.text.trim().isNotEmpty&&knownTables.isNotEmpty&&!knownTables.any((t)=>t.name.toLowerCase()==table.text.trim().toLowerCase())){message('Nama meja tidak ditemukan di outlet aktif.');}else{final success=store.addReservation(outlet:outlet.selectedOutletId,guest:guest.text,phone:phone.text,partySize:int.tryParse(party.text)??0,at:at,table:table.text,note:note.text);message(success?'Reservasi tersimpan.':'Meja sudah dipesan pada waktu berdekatan atau data reservasi tidak valid.');}}
    guest.dispose();phone.dispose();party.dispose();table.dispose();note.dispose();
  }
  Future<void> addQueue() async {
    final guest=TextEditingController(),party=TextEditingController(text:'2');
    final ok=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(title:const Text('Tambah Antrean'),content:SizedBox(width:360,child:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:guest,decoration:const InputDecoration(labelText:'Nama pelanggan')),TextField(controller:party,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Jumlah orang'))])),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Batal')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Ambil Nomor'))]));
    if(ok==true){final success=store.addQueue(outlet:outlet.selectedOutletId,guest:guest.text,partySize:int.tryParse(party.text)??0);message(success?'Nomor antrean dibuat.':'Nama dan jumlah orang wajib valid.');}guest.dispose();party.dispose();
  }
  Future<void> addBundle() async {
    final name=TextEditingController(),lines=TextEditingController(),price=TextEditingController();
    final ok=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(title:const Text('Buat Paket Menu'),content:SizedBox(width:420,child:Column(mainAxisSize:MainAxisSize.min,children:[
      TextField(controller:name,decoration:const InputDecoration(labelText:'Nama paket')),
      TextField(controller:lines,maxLines:4,decoration:const InputDecoration(labelText:'Isi paket, satu per baris',hintText:'2x Nasi Goreng\n1x Es Teh (nama harus sama dengan menu aktif)')),
      TextField(controller:price,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Harga paket (Rp)')),
    ])),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Batal')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Simpan Paket'))]));
    if(ok==true){final parsed=<FirefaBundleLine>[];for(final raw in lines.text.split('\n')){final s=raw.trim();if(s.isEmpty)continue;final m=RegExp(r'^\s*(\d+)\s*[xX]\s*(.+)$').firstMatch(s);parsed.add(m==null?FirefaBundleLine(s,1):FirefaBundleLine(m.group(2)!.trim(),int.tryParse(m.group(1)!)??1));}
      final activeNames=FirefaMenuStore.instance.forOutlet(outlet.selectedOutletId).where((m)=>m.isActive).map((m)=>m.name.toLowerCase()).toSet();
      if(parsed.any((line)=>!activeNames.contains(line.name.toLowerCase()))){message('Setiap komponen paket harus sama persis dengan nama menu aktif di Menu Management.');}
      else {final success=store.saveBundle(outlet:outlet.selectedOutletId,name:name.text,lines:parsed,price:int.tryParse(price.text)??0);message(success?'Paket menu tersimpan.':'Periksa nama, isi paket, dan harga.');}}
    name.dispose();lines.dispose();price.dispose();
  }
  Future<void> editPrice(String type) async {
    final p=store.price(outlet.selectedOutletId,type);final fee=TextEditingController(text:p.fee.toString()),percent=TextEditingController(text:p.percent.toString());
    final ok=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(title:Text('Harga '+type),content:SizedBox(width:360,child:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:fee,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Biaya tambahan tetap (Rp)')),TextField(controller:percent,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Biaya tambahan (%)'))])),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Batal')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Simpan'))]));
    if(ok==true){final success=store.savePrice(outlet:outlet.selectedOutletId,type:type,fee:int.tryParse(fee.text)??-1,percent:int.tryParse(percent.text)??-1);message(success?'Aturan harga tersimpan.':'Biaya tidak valid.');}fee.dispose();percent.dispose();
  }
  Future<void> addPromo() async {
    final name=TextEditingController(),code=TextEditingController(),value=TextEditingController(text:'10'),minimum=TextEditingController(text:'0');
    String type='percent';DateTime start=DateTime.now().subtract(const Duration(minutes:1)),end=DateTime.now().add(const Duration(days:30));
    final ok=await showDialog<bool>(context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,update)=>AlertDialog(title:const Text('Promo Baru'),content:SizedBox(width:420,child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
      TextField(controller:name,decoration:const InputDecoration(labelText:'Nama promo')),TextField(controller:code,decoration:const InputDecoration(labelText:'Kode promo (opsional)')),
      DropdownButtonFormField<String>(initialValue:type,decoration:const InputDecoration(labelText:'Jenis diskon'),items:const [DropdownMenuItem(value:'percent',child:Text('Persentase (%)')),DropdownMenuItem(value:'nominal',child:Text('Nominal (Rp)'))],onChanged:(v){if(v!=null)update(()=>type=v);}),
      TextField(controller:value,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Nilai diskon')),TextField(controller:minimum,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Minimum belanja (Rp)')),
      const SizedBox(height:8),Text('Aktif: '+MaterialLocalizations.of(ctx).formatMediumDate(start)+' – '+MaterialLocalizations.of(ctx).formatMediumDate(end)),
      Wrap(children:[TextButton(onPressed:()async{final d=await showDatePicker(context:ctx,initialDate:start,firstDate:DateTime.now().subtract(const Duration(days:365)),lastDate:DateTime.now().add(const Duration(days:730)));if(d!=null)update(()=>start=DateTime(d.year,d.month,d.day));},child:const Text('Mulai')),TextButton(onPressed:()async{final d=await showDatePicker(context:ctx,initialDate:end,firstDate:DateTime.now(),lastDate:DateTime.now().add(const Duration(days:730)));if(d!=null)update(()=>end=DateTime(d.year,d.month,d.day,23,59,59));},child:const Text('Berakhir'))])
    ]))),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Batal')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Simpan Promo'))])));
    if(ok==true){final success=store.savePromo(outlet:outlet.selectedOutletId,name:name.text,code:code.text,type:type,value:int.tryParse(value.text)??0,minimum:int.tryParse(minimum.text)??-1,start:start,end:end);message(success?'Promo tersimpan.':'Data promo tidak valid atau kode sudah digunakan.');}name.dispose();code.dispose();value.dispose();minimum.dispose();
  }
  Future<void> printKot(FirefaOrder order) async {
    final lines=<String>['FIREFA • KITCHEN ORDER TICKET','Order: '+order.id,'Tipe: '+order.orderType,if(order.tableId!=null)'Meja: '+order.tableId!,'Waktu: '+MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(order.createdAt.toLocal())),'--------------------------------',for(final item in order.items)item.quantity.toString()+' x '+item.productName+(item.details.isEmpty?'':' • '+item.details),'--------------------------------','Catatan: cek detail pesanan sebelum produksi'];
    await showDialog<void>(context:context,builder:(ctx)=>AlertDialog(title:const Text('Preview KOT — simulasi cetak'),content:SizedBox(width:420,child:SingleChildScrollView(child:SelectableText(lines.join('\n'),style:const TextStyle(fontFamily:'monospace')))),actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Tutup')),FilledButton.icon(onPressed:()async{await Clipboard.setData(ClipboardData(text:lines.join('\n')));if(ctx.mounted)Navigator.pop(ctx);if(mounted)message('KOT disalin. Pengiriman ke printer fisik masih perlu driver printer.');},icon:const Icon(Icons.copy),label:const Text('Salin KOT'))]));
  }
  Widget _reservationTile(FirefaReservation r, String id) => Card(
    child: ListTile(
      leading: const Icon(Icons.event_available_outlined),
      title: Text(r.guest + ' • ' + r.partySize.toString() + ' orang'),
      subtitle: Text(r.id + ' • ' + r.at.toLocal().toString().substring(0,16) +
        (r.table.isEmpty ? '' : ' • Meja ' + r.table) + '\n' + r.phone +
        (r.note.isEmpty ? '' : ' • ' + r.note)),
      isThreeLine: true,
      trailing: PopupMenuButton<String>(
        tooltip: 'Ubah status reservasi',
        onSelected: (v) { if (!store.setReservationStatus(id, r.id, v)) message('Perubahan status reservasi tidak sesuai alur.'); },
        itemBuilder: (_) => const [
          PopupMenuItem(value:'booked', child:Text('Dipesan')),
          PopupMenuItem(value:'arrived', child:Text('Tamu tiba')),
          PopupMenuItem(value:'seated', child:Text('Sudah duduk')),
          PopupMenuItem(value:'completed', child:Text('Selesai')),
          PopupMenuItem(value:'cancelled', child:Text('Batalkan')),
        ],
        child: Chip(label:Text(r.status)),
      ),
    ),
  );
  Widget _queueTile(FirefaQueueTicket q, String id) => Card(
    child: ListTile(
      leading: CircleAvatar(child:Text(q.number)),
      title: Text(q.guest + ' • ' + q.partySize.toString() + ' orang'),
      subtitle: Text(q.at.toLocal().toString().substring(0,16)),
      trailing: PopupMenuButton<String>(
        tooltip:'Ubah status antrean',
        onSelected:(v){if(!store.setQueueStatus(id,q.id,v))message('Perubahan status antrean tidak sesuai alur.');},
        itemBuilder:(_)=>const [
          PopupMenuItem(value:'waiting',child:Text('Menunggu')),
          PopupMenuItem(value:'called',child:Text('Panggil')),
          PopupMenuItem(value:'seated',child:Text('Sudah duduk')),
          PopupMenuItem(value:'completed',child:Text('Selesai')),
          PopupMenuItem(value:'cancelled',child:Text('Batalkan')),
        ],
        child:Chip(label:Text(q.status)),
      ),
    ),
  );
  Widget _kotTile(FirefaOrder o, String id) => Card(
    child: ListTile(
      leading: const Icon(Icons.soup_kitchen_outlined),
      title: Text(o.id + ' • ' + o.orderType + (o.tableId == null ? '' : ' • ' + o.tableId!)),
      subtitle: Text(o.items.map((e)=>e.quantity.toString()+'x '+e.productName).join('\n')+'\nStatus: '+o.status.label),
      isThreeLine:true,
      trailing: Row(mainAxisSize:MainAxisSize.min,children:[
        IconButton(tooltip:'Preview KOT',onPressed:()=>printKot(o),icon:const Icon(Icons.print_outlined)),
        if (o.status.next != null)
          IconButton(
            tooltip: 'Lanjut status dapur',
            onPressed: () {
              final advanced = orders.advance(id, o.id);
              if (!advanced) {
                message('Status belum dapat dilanjutkan. Pastikan pembayaran selesai sebelum menutup pesanan.');
              }
            },
            icon: const Icon(Icons.arrow_forward),
          ),
      ]),
    ),
  );
  Widget _bundleTile(FirefaMenuBundle b,String id)=>Card(
    child:ListTile(
      leading:const Icon(Icons.lunch_dining_outlined),
      title:Text(b.name),
      subtitle:Text(b.lines.map((e)=>e.quantity.toString()+'x '+e.name).join(', ')),
      isThreeLine:true,
      trailing:SizedBox(width:150,child:Row(mainAxisSize:MainAxisSize.min,children:[
        Flexible(child:Text(money(b.price),overflow:TextOverflow.ellipsis)),
        Switch(value:b.active,onChanged:canManage?(v)=>store.setBundleActive(id,b.id,v):null),
      ])),
    ),
  );
  Widget _priceTile(String type,String id){
    final p=store.price(id,type);
    return Card(child:ListTile(
      leading:const Icon(Icons.price_change_outlined),
      title:Text(type),
      subtitle:Text('Biaya tetap: '+money(p.fee)+' • Tambahan: '+p.percent.toString()+'%'),
      trailing:IconButton(onPressed:canManage?()=>editPrice(type):null,icon:const Icon(Icons.edit_outlined)),
    ));
  }
  Widget _promoTile(FirefaPromo p,String id)=>Card(
    child:ListTile(
      leading:const Icon(Icons.local_offer_outlined),
      title:Text(p.name),
      subtitle:Text((p.code.isEmpty?'Tanpa kode':'Kode: '+p.code)+' • '+(p.type=='percent'?p.value.toString()+'%':money(p.value))+' • Min. '+money(p.minimum)+'\n'+p.start.toLocal().toString().substring(0,10)+' s.d. '+p.end.toLocal().toString().substring(0,10)),
      isThreeLine:true,
      trailing:Switch(value:p.active,onChanged:canManage?(v)=>store.setPromoActive(id,p.id,v):null),
    ),
  );
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future:ready,
      builder:(context,snapshot) {
        if(snapshot.hasError) return const Text('Gagal memuat data operasional F&B. Data lama dipertahankan.');
        if(snapshot.connectionState!=ConnectionState.done) return const Center(child:CircularProgressIndicator());
        final id=outlet.selectedOutletId;
        final activeOrders=orders.ordersForOutlet(id).where((o)=>o.status!=FirefaOrderStatus.completed&&o.status!=FirefaOrderStatus.cancelled).toList();
        return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          const Text('Operasional F&B',style:TextStyle(fontSize:22,fontWeight:FontWeight.bold)),
          const SizedBox(height:5),
          Text(outlet.selectedOutletName+' • Data tersimpan lokal',style:const TextStyle(color:Colors.blueGrey)),
          const SizedBox(height:16),
          TabBar(controller:tabs,isScrollable:true,labelColor:primary,tabs:const [
            Tab(text:'Reservasi'),Tab(text:'Antrean'),Tab(text:'KOT Dapur'),
            Tab(text:'Paket Menu'),Tab(text:'Harga Pesanan'),Tab(text:'Promo'),
          ]),
          Expanded(child:TabBarView(controller:tabs,children:[
            _panel('Reservasi',store.reservations(id).length,canManage?addReservation:null,[
              for(final r in store.reservations(id)) _reservationTile(r,id),
            ]),
            _panel('Antrean Pelanggan',store.queue(id).length,addQueue,[
              for(final q in store.queue(id)) _queueTile(q,id),
            ]),
            _panel('Kitchen Order Ticket',activeOrders.length,null,[
              for(final o in activeOrders) _kotTile(o,id),
            ]),
            _panel('Paket Menu',store.bundles(id).length,canManage?addBundle:null,[
              for(final b in store.bundles(id)) _bundleTile(b,id),
            ]),
            _panel('Harga per Tipe Pesanan',3,null,[
              for(final type in const ['Dine In','Takeaway','Delivery']) _priceTile(type,id),
            ]),
            _panel('Promo & Diskon',store.promos(id).length,canManage?addPromo:null,[
              for(final p in store.promos(id)) _promoTile(p,id),
            ]),
          ])),
        ]);
      },
    );
  }
  Widget _panel(String title,int count,VoidCallback? onAdd,List<Widget> children)=>Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Padding(padding:const EdgeInsets.symmetric(vertical:12),child:Row(children:[Expanded(child:Text(title+' • '+count.toString(),style:const TextStyle(fontWeight:FontWeight.bold,fontSize:16))),if(onAdd!=null)FilledButton.icon(onPressed:onAdd,icon:const Icon(Icons.add),label:const Text('Tambah'))])),
    Expanded(child:children.isEmpty?const Center(child:Text('Belum ada data. Gunakan tombol Tambah untuk memulai.')):ListView(children:children))
  ]);
}
