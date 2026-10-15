import 'package:flutter/material.dart';

void main() => runApp(const FirefaStaffApp());

class FirefaStaffApp extends StatelessWidget {
  const FirefaStaffApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'FIREFA Staff',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF008F83)),
          scaffoldBackgroundColor: const Color(0xFFF5F7FA),
          appBarTheme: const AppBarTheme(backgroundColor: Colors.white, foregroundColor: Color(0xFF172B4D)),
          cardTheme: CardThemeData(
            color: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
          ),
        ),
        home: const StaffShell(),
      );
}

class StaffShell extends StatefulWidget {
  const StaffShell({super.key});

  @override
  State<StaffShell> createState() => _StaffShellState();
}

class _StaffShellState extends State<StaffShell> {
  int _tab = 0;
  bool _checkedIn = false;
  final Set<int> _done = <int>{};
  static const _tasks = ['Persiapan area kerja', 'Periksa perlengkapan', 'Briefing tim'];

  @override
  Widget build(BuildContext context) {
    final pages = [_home(), _shift(), _taskList(), _profile()];
    return Scaffold(
      appBar: AppBar(
        title: const Row(children: [
          Icon(Icons.restaurant_menu, color: Color(0xFF008F83)),
          SizedBox(width: 10),
          Text('FIREFA Staff', style: TextStyle(fontWeight: FontWeight.w800)),
        ]),
        actions: [IconButton(
          tooltip: 'Notifikasi',
          onPressed: () => _message('Belum ada notifikasi baru.'),
          icon: const Icon(Icons.notifications_none_rounded),
        )],
      ),
      body: SafeArea(child: IndexedStack(index: _tab, children: pages)),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (value) => setState(() => _tab = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Beranda'),
          NavigationDestination(icon: Icon(Icons.schedule_outlined), selectedIcon: Icon(Icons.schedule_rounded), label: 'Shift'),
          NavigationDestination(icon: Icon(Icons.checklist_outlined), selectedIcon: Icon(Icons.checklist_rounded), label: 'Tugas'),
          NavigationDestination(icon: Icon(Icons.person_outline_rounded), selectedIcon: Icon(Icons.person_rounded), label: 'Profil'),
        ],
      ),
    );
  }

  Widget _home() => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('Selamat datang,', style: TextStyle(color: Color(0xFF64748B))),
          const SizedBox(height: 4),
          Text('Tim FIREFA', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: const LinearGradient(colors: [Color(0xFF008F83), Color(0xFF006B63)]),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Row(children: [
                Icon(Icons.storefront_outlined, color: Colors.white70),
                SizedBox(width: 8),
                Text('OUTLET AKTIF', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w700, fontSize: 11, letterSpacing: 1)),
              ]),
              const SizedBox(height: 10),
              const Text('Outlet Utama', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text(_checkedIn ? 'Shift sedang berjalan' : 'Belum memulai shift hari ini', style: const TextStyle(color: Colors.white)),
              const SizedBox(height: 18),
              SizedBox(width: double.infinity, child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: const Color(0xFF007A70)),
                onPressed: _toggleShift,
                child: Text(_checkedIn ? 'Akhiri Shift (Demo)' : 'Mulai Shift (Demo)'),
              )),
            ]),
          ),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: _metric('Status Shift', _checkedIn ? 'Aktif' : 'Belum mulai', Icons.access_time_rounded)),
            const SizedBox(width: 12),
            Expanded(child: _metric('Tugas Selesai', _done.length.toString() + '/' + _tasks.length.toString(), Icons.task_alt_rounded)),
          ]),
          const SizedBox(height: 24),
          const Text('Akses cepat', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _shortcut('Shift', Icons.schedule_rounded, 1)),
            const SizedBox(width: 8),
            Expanded(child: _shortcut('Daftar tugas', Icons.checklist_rounded, 2)),
            const SizedBox(width: 8),
            Expanded(child: _shortcut('Profil', Icons.person_outline_rounded, 3)),
          ]),
          const SizedBox(height: 20),
          const Card(child: ListTile(
            leading: CircleAvatar(backgroundColor: Color(0xFFE0F2F1), child: Icon(Icons.info_outline, color: Color(0xFF008F83))),
            title: Text('Pengingat shift'),
            subtitle: Text('Selesaikan tugas awal shift sebelum operasional ramai.'),
          )),
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('Mode demo: belum terhubung ke server atau akun outlet.', style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
          ),
        ],
      );

  Widget _shift() => ListView(padding: const EdgeInsets.all(20), children: [
        Text('Shift kerja', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        const Text('Kelola kehadiran dan status shift.', style: TextStyle(color: Color(0xFF64748B))),
        const SizedBox(height: 18),
        Card(child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.access_time_filled_rounded, color: Color(0xFF008F83), size: 34),
            const SizedBox(height: 14),
            Text(_checkedIn ? 'Shift sedang aktif' : 'Kamu belum check-in', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(_checkedIn ? 'Status demo tercatat selama sesi aplikasi.' : 'Mulai shift ketika kamu siap bertugas.', style: const TextStyle(color: Color(0xFF64748B))),
            const SizedBox(height: 18),
            SizedBox(width: double.infinity, child: FilledButton.icon(
              onPressed: _toggleShift,
              icon: Icon(_checkedIn ? Icons.logout_rounded : Icons.login_rounded),
              label: Text(_checkedIn ? 'Check-out (Demo)' : 'Check-in (Demo)'),
            )),
          ]),
        )),
        const Card(child: Column(children: [
          ListTile(leading: Icon(Icons.event_outlined), title: Text('Jadwal hari ini'), subtitle: Text('Jadwal resmi belum disinkronkan')),
          Divider(height: 1),
          ListTile(leading: Icon(Icons.history_rounded), title: Text('Riwayat kehadiran'), subtitle: Text('Tersedia setelah integrasi data')),
        ])),
        const Padding(padding: EdgeInsets.only(top: 8), child: Text('Check-in/check-out masih berupa simulasi lokal.', style: TextStyle(color: Color(0xFF64748B), fontSize: 12))),
      ]);

  Widget _taskList() => ListView(padding: const EdgeInsets.all(20), children: [
        Text('Daftar tugas', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text(_done.length.toString() + ' dari ' + _tasks.length.toString() + ' tugas selesai', style: const TextStyle(color: Color(0xFF64748B))),
        const SizedBox(height: 14),
        LinearProgressIndicator(value: _done.length / _tasks.length, minHeight: 7, borderRadius: BorderRadius.circular(8), color: const Color(0xFF008F83)),
        const SizedBox(height: 14),
        ...List.generate(_tasks.length, (index) => Card(child: CheckboxListTile(
          value: _done.contains(index),
          onChanged: (value) => setState(() {
            if (value ?? false) {
              _done.add(index);
            } else {
              _done.remove(index);
            }
          }),
          controlAffinity: ListTileControlAffinity.leading,
          secondary: const CircleAvatar(backgroundColor: Color(0xFFE0F2F1), child: Icon(Icons.task_alt_rounded, color: Color(0xFF008F83))),
          title: Text(_tasks[index], style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: const Text('Tugas contoh untuk prototipe'),
        ))),
        const Padding(padding: EdgeInsets.only(top: 8), child: Text('Daftar tugas resmi mengikuti brief dan integrasi outlet.', style: TextStyle(color: Color(0xFF64748B), fontSize: 12))),
      ]);

  Widget _profile() => ListView(padding: const EdgeInsets.all(20), children: [
        Text('Profil saya', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 18),
        const Card(child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(children: [
            CircleAvatar(radius: 38, backgroundColor: Color(0xFFE0F2F1), child: Icon(Icons.person_rounded, size: 42, color: Color(0xFF008F83))),
            SizedBox(height: 12),
            Text('Anggota Tim', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            SizedBox(height: 4),
            Text('Akun demo • Belum terhubung', style: TextStyle(color: Color(0xFF64748B))),
            Divider(height: 28),
            ListTile(leading: Icon(Icons.badge_outlined), title: Text('ID staf'), subtitle: Text('Belum ditetapkan')),
            ListTile(leading: Icon(Icons.store_outlined), title: Text('Outlet'), subtitle: Text('Outlet Utama (demo)')),
            ListTile(leading: Icon(Icons.security_outlined), title: Text('Akses'), subtitle: Text('Menunggu autentikasi server')),
          ]),
        )),
        const SizedBox(height: 12),
        OutlinedButton.icon(onPressed: () => _message('Autentikasi belum diaktifkan.'), icon: const Icon(Icons.logout_rounded), label: const Text('Keluar')),
      ]);

  Widget _metric(String label, String value, IconData icon) => Card(child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: const Color(0xFF008F83)),
          const SizedBox(height: 14),
          Text(value, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
        ]),
      ));

  Widget _shortcut(String label, IconData icon, int destination) => InkWell(
        onTap: () => setState(() => _tab = destination),
        borderRadius: BorderRadius.circular(14),
        child: Card(child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 6),
          child: Column(children: [
            Icon(icon, color: const Color(0xFF008F83), size: 26),
            const SizedBox(height: 8),
            Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          ]),
        )),
      );

  void _toggleShift() {
    setState(() => _checkedIn = !_checkedIn);
    _message(_checkedIn ? 'Check-in demo berhasil.' : 'Check-out demo berhasil.');
  }

  void _message(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}
