// Pumply minimal app (LOCAL_MODE=true by default).
// Codemagic will run `flutter create .` to generate android/ios.
// Build cmd: flutter build apk --release --dart-define=LOCAL_MODE=true
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:geolocator/geolocator.dart';

enum Fuel { petrol, diesel, cng, ev }
enum Availability { available, low, unavailable }

Availability _avail(String s) =>
    s.toUpperCase() == 'AVAILABLE' ? Availability.available
  : s.toUpperCase() == 'LOW'       ? Availability.low
                                   : Availability.unavailable;

String label(Availability a) =>
    a == Availability.available ? 'Fuel Available'
  : a == Availability.low       ? 'Low / Queue'
                                : 'Unavailable';

Color color(BuildContext c, Availability a) =>
    a == Availability.available ? const Color(0xFF24C268)
  : a == Availability.low       ? const Color(0xFFFFCC00)
                                : const Color(0xFFFF3B30);

class Station {
  final String id, name, brand, area;
  final double lat, lng;
  final Map<Fuel, Availability> fuels;
  Station({
    required this.id, required this.name, required this.brand, required this.area,
    required this.lat, required this.lng, required this.fuels
  });
  factory Station.fromJson(Map<String, dynamic> j) => Station(
    id: j['id'], name: j['name'], brand: j['brand'], area: j['area'],
    lat: (j['lat'] ?? 0).toDouble(), lng: (j['lng'] ?? 0).toDouble(),
    fuels: {
      Fuel.petrol: _avail(j['fuels']['PETROL']),
      Fuel.diesel: _avail(j['fuels']['DIESEL']),
      Fuel.cng:    _avail(j['fuels']['CNG']),
      Fuel.ev:     _avail(j['fuels']['EV']),
    },
  );
}

Future<Position> _pos() async {
  if (!await Geolocator.isLocationServiceEnabled()) throw 'Turn on location services.';
  var p = await Geolocator.checkPermission();
  if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
  if (p == LocationPermission.deniedForever || p == LocationPermission.denied) throw 'Location permission denied.';
  return Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
}

(double, Station?) _nearest(double lat, double lng, List<Station> ss){
  double best = 1e9; Station? pick;
  for(final s in ss){
    final d = _hav(lat, lng, s.lat, s.lng);
    if (d < best) { best = d; pick = s; }
  }
  return (best, pick);
}
double _hav(double lat1, double lon1, double lat2, double lon2){
  const R = 6371.0;
  double dLat = _rad(lat2-lat1), dLon = _rad(lon2-lon1);
  double a = sin(dLat/2)*sin(dLat/2) + cos(_rad(lat1))*cos(_rad(lat2))*sin(dLon/2)*sin(dLon/2);
  return R * 2 * atan2(sqrt(a), sqrt(1-a));
}
double _rad(double d)=> d*pi/180.0;

void main() => runApp(const Pumply());
class Pumply extends StatelessWidget{
  const Pumply({super.key});
  @override Widget build(BuildContext c)=> MaterialApp(
    debugShowCheckedModeBanner:false,
    theme: ThemeData(useMaterial3:true, colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF5B5BD6))),
    home: const Home());
}

class Home extends StatefulWidget{ const Home({super.key}); @override State<Home> createState()=>_HomeState(); }
class _HomeState extends State<Home>{
  Fuel fuel=Fuel.petrol; String? msg; Color stateColor=const Color(0xFF24C268);
  Station? st; double? dist; bool busy=false; List<Station>? stations;
  @override void initState(){ super.initState(); _load(); }
  Future<void> _load() async {
    final raw = await rootBundle.loadString('assets/stations_panvel.json');
    stations = (jsonDecode(raw) as List).map((e)=> Station.fromJson(e)).toList();
    setState((){});
  }
  Future<void> _check() async {
    setState(()=>busy=true);
    try{
      final pos = await _pos();
      final (d, s) = _nearest(pos.latitude, pos.longitude, stations!);
      if (s == null){ setState((){ msg='No nearby stations'; stateColor=Colors.grey;}); return; }
      final m = s.fuels[fuel] ?? Availability.unavailable;
      setState((){ st=s; dist=d; msg=label(m); stateColor=color(context,m); });
    }catch(e){ setState((){ msg=e.toString(); stateColor=Colors.red;}); }
    finally{ setState(()=>busy=false); }
  }
  @override Widget build(BuildContext c)=> Scaffold(
    appBar: AppBar(title: Row(children:[
      Container(width:28,height:28,decoration:BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        gradient: const LinearGradient(colors:[Color(0xFF6E5CF5), Color(0xFF5B5BD6)]),
      ), child: const Icon(Icons.water_drop,color:Colors.white,size:18)),
      const SizedBox(width:10),
      const Text('Pumply', style: TextStyle(fontWeight: FontWeight.w900)),
    ])),
    body: stations==null? const Center(child:CircularProgressIndicator()):
    ListView(padding: const EdgeInsets.fromLTRB(16,12,16,24), children:[
      Wrap(spacing:8, children:[
        ChoiceChip(label: const Text('Petrol', style: TextStyle(fontWeight: FontWeight.w700)), selected: fuel==Fuel.petrol, onSelected:(_)=> setState(()=>fuel=Fuel.petrol)),
        ChoiceChip(label: const Text('Diesel', style: TextStyle(fontWeight: FontWeight.w700)), selected: fuel==Fuel.diesel, onSelected:(_)=> setState(()=>fuel=Fuel.diesel)),
        ChoiceChip(label: const Text('CNG', style: TextStyle(fontWeight: FontWeight.w700)), selected: fuel==Fuel.cng, onSelected:(_)=> setState(()=>fuel=Fuel.cng)),
        ChoiceChip(label: const Text('EV', style: TextStyle(fontWeight: FontWeight.w700)), selected: fuel==Fuel.ev, onSelected:(_)=> setState(()=>fuel=Fuel.ev)),
      ]),
      const SizedBox(height:16),
      _Card(child: Column(children:[
        const Text('Is Fuel Available?', style: TextStyle(fontSize:22,fontWeight: FontWeight.w900)),
        const SizedBox(height:8),
        Text(st==null ? 'Instant status for your nearest station' : '${st!.name} • ${dist!.toStringAsFixed(1)} km',
          style: TextStyle(color: Colors.grey[600]), textAlign: TextAlign.center),
        const SizedBox(height:14),
        Container(width:112,height:112, decoration: BoxDecoration(
          color: stateColor.withOpacity(.12), borderRadius: BorderRadius.circular(28)),
          alignment: Alignment.center, child: Icon(Icons.local_gas_station,color: stateColor,size:44)),
        const SizedBox(height:10),
        if(msg!=null) Text(msg!, style: TextStyle(fontWeight: FontWeight.w900, color: stateColor)),
        const SizedBox(height:12),
        FilledButton.icon(onPressed: busy?null:_check, icon: const Icon(Icons.refresh),
          label: Text(busy?'Checking…':'Check Availability', style: const TextStyle(fontWeight: FontWeight.w800))),
      ])),
    ]));
}

class _Card extends StatelessWidget{
  final Widget child; const _Card({required this.child});
  @override Widget build(BuildContext ctx)=> Container(
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22),
      boxShadow: const [BoxShadow(color: Color(0x14101828), blurRadius:24, offset: Offset(0,10))]),
    child: child,
  );
}
