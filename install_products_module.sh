#!/usr/bin/env bash
set -euo pipefail
cd /workspaces/POS-Software
mkdir -p lib/models lib/services lib/screens
cat > lib/models/product.dart <<'DART'
class Product {
  const Product({required this.id, required this.name, required this.sku, this.barcode, required this.costPrice, required this.sellingPrice, required this.beginningStock, required this.active, this.createdAt, this.updatedAt});
  final String id, name, sku;
  final String? barcode;
  final double costPrice, sellingPrice;
  final int beginningStock;
  final bool active;
  final int? createdAt, updatedAt;

  factory Product.fromMap(String id, Map<Object?, Object?> map) => Product(
    id: id,
    name: (map['name'] ?? '').toString(),
    sku: (map['sku'] ?? '').toString(),
    barcode: (map['barcode']?.toString().trim().isEmpty ?? true) ? null : map['barcode'].toString(),
    costPrice: (map['costPrice'] as num?)?.toDouble() ?? 0,
    sellingPrice: (map['sellingPrice'] as num?)?.toDouble() ?? 0,
    beginningStock: (map['beginningStock'] as num?)?.toInt() ?? 0,
    active: map['active'] as bool? ?? true,
    createdAt: (map['createdAt'] as num?)?.toInt(),
    updatedAt: (map['updatedAt'] as num?)?.toInt(),
  );
}
DART

cat > lib/services/product_service.dart <<'DART'
import 'package:firebase_database/firebase_database.dart';
import '../models/product.dart';

class DuplicateProductException implements Exception {
  const DuplicateProductException(this.field);
  final String field;
  @override String toString() => 'Duplicate $field';
}

class ProductService {
  final FirebaseDatabase _db = FirebaseDatabase.instance;
  DatabaseReference get _products => _db.ref('products');
  DatabaseReference get _skuIndex => _db.ref('productSkuIndex');
  DatabaseReference get _barcodeIndex => _db.ref('productBarcodeIndex');
  DatabaseReference get connectedRef => _db.ref('.info/connected');

  Stream<List<Product>> watchProducts() => _products.onValue.map((event) {
    final raw = event.snapshot.value;
    if (raw is! Map) return <Product>[];
    final items = raw.entries.where((e) => e.value is Map).map((e) => Product.fromMap(e.key.toString(), Map<Object?, Object?>.from(e.value as Map))).toList();
    items.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return items;
  });

  Future<void> save({String? id, required String name, required String sku, String? barcode, required double costPrice, required double sellingPrice, required int beginningStock, required bool active, required String? oldSku, required String? oldBarcode}) async {
    final productId = id ?? _products.push().key!;
    final normalizedSku = sku.trim().toUpperCase();
    final normalizedBarcode = barcode?.trim() ?? '';
    await _claim(_skuIndex.child(normalizedSku), productId, 'SKU');
    try {
      if (normalizedBarcode.isNotEmpty) await _claim(_barcodeIndex.child(normalizedBarcode), productId, 'barcode');
    } catch (_) {
      if (id == null || oldSku != normalizedSku) await _skuIndex.child(normalizedSku).remove();
      rethrow;
    }

    final updates = <String, Object?>{
      'products/$productId/name': name.trim(),
      'products/$productId/sku': normalizedSku,
      'products/$productId/barcode': normalizedBarcode.isEmpty ? null : normalizedBarcode,
      'products/$productId/costPrice': costPrice,
      'products/$productId/sellingPrice': sellingPrice,
      'products/$productId/beginningStock': beginningStock,
      'products/$productId/active': active,
      'products/$productId/updatedAt': ServerValue.timestamp,
      'productSkuIndex/$normalizedSku': productId,
    };
    if (id == null) updates['products/$productId/createdAt'] = ServerValue.timestamp;
    if (normalizedBarcode.isNotEmpty) updates['productBarcodeIndex/$normalizedBarcode'] = productId;
    if (oldSku != null && oldSku.isNotEmpty && oldSku != normalizedSku) updates['productSkuIndex/$oldSku'] = null;
    if (oldBarcode != null && oldBarcode.isNotEmpty && oldBarcode != normalizedBarcode) updates['productBarcodeIndex/$oldBarcode'] = null;
    await _db.ref().update(updates);
  }

  Future<void> _claim(DatabaseReference ref, String id, String field) async {
    final result = await ref.runTransaction((current) {
      if (current == null || current == id) return Transaction.success(id);
      return Transaction.abort();
    });
    if (!result.committed) throw DuplicateProductException(field);
  }
}
DART

cat > lib/screens/product_form_screen.dart <<'DART'
import 'package:flutter/material.dart';
import '../models/product.dart';
import '../services/product_service.dart';

class ProductFormScreen extends StatefulWidget {
  const ProductFormScreen({super.key, this.product});
  final Product? product;
  @override State<ProductFormScreen> createState() => _ProductFormScreenState();
}
class _ProductFormScreenState extends State<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _service = ProductService();
  late final TextEditingController _name, _sku, _barcode, _cost, _selling, _stock;
  late bool _active;
  bool _saving = false;
  @override void initState() {
    super.initState(); final p = widget.product;
    _name = TextEditingController(text: p?.name ?? ''); _sku = TextEditingController(text: p?.sku ?? '');
    _barcode = TextEditingController(text: p?.barcode ?? ''); _cost = TextEditingController(text: p?.costPrice.toStringAsFixed(2) ?? '');
    _selling = TextEditingController(text: p?.sellingPrice.toStringAsFixed(2) ?? ''); _stock = TextEditingController(text: p?.beginningStock.toString() ?? '0');
    _active = p?.active ?? true;
  }
  @override void dispose() { for (final c in [_name,_sku,_barcode,_cost,_selling,_stock]) { c.dispose(); } super.dispose(); }
  String? _required(String? v) => (v == null || v.trim().isEmpty) ? 'Required' : null;
  String? _money(String? v) { final n = double.tryParse(v ?? ''); return n == null ? 'Enter a valid number' : n < 0 ? 'Cannot be negative' : null; }
  String? _integer(String? v) { final n = int.tryParse(v ?? ''); return n == null ? 'Enter a whole number' : n < 0 ? 'Cannot be negative' : null; }
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final cost = double.parse(_cost.text), selling = double.parse(_selling.text);
    if (selling < cost) {
      final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(title: const Text('Selling below cost'), content: const Text('Selling price is lower than cost price. Continue?'), actions: [TextButton(onPressed:()=>Navigator.pop(context,false),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(context,true),child:const Text('Continue'))])) ?? false;
      if (!ok) return;
    }
    setState(()=>_saving=true);
    try {
      await _service.save(id: widget.product?.id, name:_name.text, sku:_sku.text, barcode:_barcode.text, costPrice:cost, sellingPrice:selling, beginningStock:int.parse(_stock.text), active:_active, oldSku:widget.product?.sku, oldBarcode:widget.product?.barcode);
      if (!mounted) return; ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(widget.product == null ? 'Product saved. It will sync when online.' : 'Product updated. It will sync when online.'))); Navigator.pop(context);
    } on DuplicateProductException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${e.field} already exists.')));
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Save failed: $e'))); }
    finally { if (mounted) setState(()=>_saving=false); }
  }
  @override Widget build(BuildContext context) => Scaffold(appBar:AppBar(title:Text(widget.product==null?'Add Product':'Edit Product')),body:Form(key:_formKey,child:ListView(padding:const EdgeInsets.all(16),children:[
    TextFormField(controller:_name,decoration:const InputDecoration(labelText:'Product name',border:OutlineInputBorder()),validator:_required),const SizedBox(height:12),
    TextFormField(controller:_sku,textCapitalization:TextCapitalization.characters,decoration:const InputDecoration(labelText:'SKU',border:OutlineInputBorder()),validator:_required),const SizedBox(height:12),
    TextFormField(controller:_barcode,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Barcode (optional)',border:OutlineInputBorder())),const SizedBox(height:12),
    Row(children:[Expanded(child:TextFormField(controller:_cost,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'Cost price',prefixText:'₱ ',border:OutlineInputBorder()),validator:_money)),const SizedBox(width:12),Expanded(child:TextFormField(controller:_selling,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'Selling price',prefixText:'₱ ',border:OutlineInputBorder()),validator:_money))]),const SizedBox(height:12),
    TextFormField(controller:_stock,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Beginning stock',border:OutlineInputBorder()),validator:_integer),const SizedBox(height:8),
    SwitchListTile(contentPadding:EdgeInsets.zero,title:const Text('Active product'),value:_active,onChanged:(v)=>setState(()=>_active=v)),const SizedBox(height:16),
    FilledButton.icon(onPressed:_saving?null:_save,icon:_saving?const SizedBox.square(dimension:18,child:CircularProgressIndicator(strokeWidth:2)):const Icon(Icons.save),label:Text(_saving?'Saving...':'Save Product'))
  ])));
}
DART

cat > lib/screens/products_screen.dart <<'DART'
import 'dart:async';
import 'package:flutter/material.dart';
import '../models/product.dart';
import '../services/product_service.dart';
import 'product_form_screen.dart';

class ProductsScreen extends StatefulWidget { const ProductsScreen({super.key}); @override State<ProductsScreen> createState()=>_ProductsScreenState(); }
class _ProductsScreenState extends State<ProductsScreen> {
  final _service=ProductService(); final _search=TextEditingController(); Timer? _debounce; String _query='';
  @override void dispose(){_debounce?.cancel();_search.dispose();super.dispose();}
  void _changed(String value){_debounce?.cancel();_debounce=Timer(const Duration(milliseconds:300),()=>setState(()=>_query=value.trim().toLowerCase()));}
  List<Product> _filter(List<Product> items){if(_query.isEmpty)return items;return items.where((p)=>p.name.toLowerCase().contains(_query)||p.sku.toLowerCase().startsWith(_query)||(p.barcode??'').startsWith(_query)).toList();}
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Products'),actions:[StreamBuilder<DatabaseEventShim>(stream:null,builder:(_,__)=>const SizedBox())]),floatingActionButton:FloatingActionButton.extended(onPressed:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const ProductFormScreen())),icon:const Icon(Icons.add),label:const Text('Add Product')),body:Column(children:[
    StreamBuilder<dynamic>(stream:_service.connectedRef.onValue,builder:(context,s){final online=s.data?.snapshot.value==true;return Container(width:double.infinity,padding:const EdgeInsets.symmetric(horizontal:16,vertical:6),color:online?const Color(0xFFECFDF5):const Color(0xFFFFF7ED),child:Text(online?'● Online · Live sync':'● Offline · Changes will sync later',style:TextStyle(color:online?const Color(0xFF047857):const Color(0xFFC2410C),fontSize:12)));}),
    Padding(padding:const EdgeInsets.all(16),child:TextField(controller:_search,onChanged:_changed,decoration:InputDecoration(prefixIcon:const Icon(Icons.search),hintText:'Search name, SKU, or barcode',suffixIcon:_search.text.isEmpty?null:IconButton(onPressed:(){_search.clear();_changed('');},icon:const Icon(Icons.clear)),border:const OutlineInputBorder()))),
    Expanded(child:StreamBuilder<List<Product>>(stream:_service.watchProducts(),builder:(context,s){if(s.hasError)return Center(child:Text('Unable to load products: ${s.error}'));if(!s.hasData)return const Center(child:CircularProgressIndicator());final items=_filter(s.data!);if(items.isEmpty)return Center(child:Text(_query.isEmpty?'No products yet. Tap Add Product.':'No products match your search.'));return ListView.separated(padding:const EdgeInsets.fromLTRB(16,0,16,100),itemCount:items.length,separatorBuilder:(_,__)=>const SizedBox(height:8),itemBuilder:(context,i){final p=items[i];return Opacity(opacity:p.active?1:.55,child:Card(child:ListTile(onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>ProductFormScreen(product:p))),leading:CircleAvatar(child:Icon(p.active?Icons.inventory_2:Icons.inventory_2_outlined)),title:Row(children:[Expanded(child:Text(p.name,style:const TextStyle(fontWeight:FontWeight.w700))),Container(padding:const EdgeInsets.symmetric(horizontal:8,vertical:3),decoration:BoxDecoration(color:p.active?const Color(0xFFD1FAE5):Colors.grey.shade300,borderRadius:BorderRadius.circular(999)),child:Text(p.active?'ACTIVE':'INACTIVE',style:const TextStyle(fontSize:10,fontWeight:FontWeight.bold)))]),subtitle:Text('SKU ${p.sku}  •  ₱${p.sellingPrice.toStringAsFixed(2)}  •  Stock ${p.beginningStock}'),trailing:const Icon(Icons.chevron_right))));};})),
  ]));
}
class DatabaseEventShim {}
DART

# Fix imports/type in products screen cleanly
python3 - <<'PY'
p='lib/screens/products_screen.dart'
s=open(p).read().replace("appBar:AppBar(title:const Text('Products'),actions:[StreamBuilder<DatabaseEventShim>(stream:null,builder:(_,__)=>const SizedBox())]),","appBar:AppBar(title:const Text('Products')),").replace("\nclass DatabaseEventShim {}\n", "\n")
open(p,'w').write(s)
PY

cat > lib/main.dart <<'DART'
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'firebase_options.dart';
import 'screens/products_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options:DefaultFirebaseOptions.currentPlatform);
  if (!kIsWeb) { try { FirebaseDatabase.instance.setPersistenceEnabled(true); await FirebaseDatabase.instance.ref('products').keepSynced(true); } catch (_) {} }
  runApp(const SimplePosApp());
}
class SimplePosApp extends StatelessWidget { const SimplePosApp({super.key}); @override Widget build(BuildContext context)=>MaterialApp(debugShowCheckedModeBanner:false,title:'Simple POS',theme:ThemeData(useMaterial3:true,colorScheme:ColorScheme.fromSeed(seedColor:const Color(0xFF5B5CEB)),scaffoldBackgroundColor:const Color(0xFFF5F7FB)),home:const DashboardScreen()); }
class DashboardScreen extends StatelessWidget { const DashboardScreen({super.key}); @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('Simple POS',style:TextStyle(fontWeight:FontWeight.w700)),Text('Main Branch',style:TextStyle(fontSize:12))]),backgroundColor:const Color(0xFF5B5CEB),foregroundColor:Colors.white),body:ListView(padding:const EdgeInsets.all(16),children:[const Text('Welcome to Simple POS',style:TextStyle(fontSize:24,fontWeight:FontWeight.w800)),const Text('Firebase connection is ready.'),const SizedBox(height:20),GridView.count(shrinkWrap:true,physics:const NeverScrollableScrollPhysics(),crossAxisCount:2,crossAxisSpacing:12,mainAxisSpacing:12,children:[_Card('Cashiering','Create a new sale',Icons.point_of_sale,null),_Card('Products','Manage product list',Icons.inventory_2,()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const ProductsScreen()))),_Card('Inventory','View current stocks',Icons.warehouse,null),_Card('Sales History','Review transactions',Icons.receipt_long,null)]),const SizedBox(height:20),Container(padding:const EdgeInsets.all(16),decoration:BoxDecoration(color:const Color(0xFFECFDF5),borderRadius:BorderRadius.circular(16)),child:const Text('Firebase Connected\nProject: pos-software-ef89c',style:TextStyle(color:Color(0xFF047857),fontWeight:FontWeight.w700)))])); }
class _Card extends StatelessWidget { const _Card(this.title,this.subtitle,this.icon,this.action);final String title,subtitle;final IconData icon;final VoidCallback? action;@override Widget build(BuildContext context)=>Card(child:InkWell(onTap:action??()=>ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('$title module will be added next.'))),child:Padding(padding:const EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[CircleAvatar(child:Icon(icon)),const Spacer(),Text(title,style:const TextStyle(fontWeight:FontWeight.w700)),Text(subtitle,style:const TextStyle(fontSize:12))]))));}
DART

dart format lib
flutter analyze
flutter test
flutter build web
fuser -k 3000/tcp 2>/dev/null || true
nohup python3 -m http.server 3000 --bind 0.0.0.0 --directory build/web > /tmp/simple_pos_web.log 2>&1 &
echo $! > /tmp/simple_pos_web.pid
sleep 2
curl -sS -o /dev/null -w 'HTTP STATUS: %{http_code}\n' http://127.0.0.1:3000/
echo 'Products module installed. Open Codespaces port 3000.'
