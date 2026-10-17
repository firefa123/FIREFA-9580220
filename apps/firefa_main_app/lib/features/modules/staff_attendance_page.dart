import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../core/auth/role_permissions.dart';
import '../../core/outlet/active_outlet_store.dart';
import 'backend_client.dart';

class StaffAttendancePage extends StatefulWidget {
  const StaffAttendancePage({super.key});

  @override
  State<StaffAttendancePage> createState() => _StaffAttendancePageState();
}

class _StaffAttendancePageState extends State<StaffAttendancePage> {
  final _outlet = FirefaActiveOutletStore.instance;
  final _code = TextEditingController();
  final _name = TextEditingController();
  final _pin = TextEditingController();
  final _startTime = TextEditingController();
  final _radius = TextEditingController(text: '100');
  bool _loading = true;
  bool _saving = false;
  String? _error;
  List<Map<String, dynamic>> _staff = [];
  List<Map<String, dynamic>> _performance = [];
  List<Map<String, dynamic>> _attendance = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _code.dispose();
    _name.dispose();
    _pin.dispose();
    _startTime.dispose();
    _radius.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    if (!FirefaBackendConfig.isConfigured) {
      throw const FormatException('Backend belum dikonfigurasi untuk aplikasi ini.');
    }
    final token = await FirefaBackendClient.instance.accessToken();
    if (token == null) throw const FormatException('Sesi backend habis. Login kembali.');
    final outletId = await FirefaBackendClient.instance
        .resolveAuthorizedServerOutletId(_outlet.selectedOutletId);
    final uri = Uri.parse('${FirefaBackendClient.instance.baseUrl}/api/v1$path');
    final headers = {'authorization': 'Bearer $token', 'content-type': 'application/json'};
    final response = switch (method) {
      'GET' => await http.get(uri.replace(queryParameters: {'outletId': outletId}), headers: headers),
      'POST' => await http.post(uri, headers: headers, body: jsonEncode({...?body, 'outletId': outletId})),
      'PATCH' => await http.patch(uri, headers: headers, body: jsonEncode({...?body, 'outletId': outletId})),
      _ => throw StateError('HTTP method not supported'),
    };
    final data = Map<String, dynamic>.from(jsonDecode(response.body) as Map);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final code = data['error'];
      throw FormatException(switch (code) {
        'owner_required' => 'Fitur ini hanya dapat digunakan Owner.',
        'outlet_forbidden' => 'Akun tidak memiliki akses ke outlet ini.',
        'staff_code_exists' => 'Kode staff sudah digunakan di outlet ini.',
        'invalid_request' => 'Periksa kembali data yang diisi.',
        _ => 'Permintaan gagal: ${code ?? response.statusCode}.',
      });
    }
    return data;
  }

  Future<void> _load() async {
    if (mounted) setState(() { _loading = true; _error = null; });
    try {
      if (_outlet.role != FirefaRole.owner) {
        throw const FormatException('Pengelolaan staff hanya tersedia untuk Owner.');
      }
      final staffResponse = await _request('GET', '/staff');
      final performanceResponse = await _request('GET', '/staff/performance');
      final radiusResponse = await _request('GET', '/staff/geofence-radius');
      final attendanceResponse = await _request('GET', '/attendance');
      if (!mounted) return;
      setState(() {
        _staff = (staffResponse['staff'] as List<dynamic>).map((row) => Map<String, dynamic>.from(row as Map)).toList();
        _performance = (performanceResponse['performance'] as List<dynamic>).map((row) => Map<String, dynamic>.from(row as Map)).toList();
        _attendance = (attendanceResponse['attendance'] as List<dynamic>).map((row) => Map<String, dynamic>.from(row as Map)).toList();
        _radius.text = '${radiusResponse['geofence']['radiusMeters']}';
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString().replaceFirst('FormatException: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }


  Future<void> _showAttendancePhoto(Map<String, dynamic> row) async {
    if (row['hasCheckInPhoto'] != true) {
      _message('Catatan absensi ini tidak memiliki foto check-in.');
      return;
    }
    try {
      final attendanceId = row['id'];
      if (attendanceId is! String || attendanceId.isEmpty) {
        throw const FormatException('ID absensi tidak valid.');
      }
      final token = await FirefaBackendClient.instance.accessToken();
      if (token == null) {
        throw const FormatException('Sesi backend habis. Login kembali.');
      }
      final response = await http.get(
        Uri.parse('${FirefaBackendClient.instance.baseUrl}/api/v1/attendance/$attendanceId/photo'),
        headers: {'authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        throw FormatException('Foto tidak dapat dimuat (HTTP ${response.statusCode}).');
      }
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => Dialog(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560, maxHeight: 680),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Foto check-in • ${row['displayName']}', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  Flexible(
                    child: Image.memory(
                      response.bodyBytes,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => const Center(child: Text('File foto tidak dapat ditampilkan.')),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      child: const Text('Tutup'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    } catch (error) {
      if (mounted) _message(error.toString().replaceFirst('FormatException: ', ''));
    }
  }

  Future<void> _createStaff() async {
    if (_saving) return;
    final start = _startTime.text.trim();
    if (start.isNotEmpty && !RegExp(r'^(?:[01]\d|2[0-3]):[0-5]\d$').hasMatch(start)) {
      setState(() => _error = 'Jam mulai harus memakai format HH:mm, atau dikosongkan agar staff bebas absen.');
      return;
    }
    if (!RegExp(r'^\d{6}$').hasMatch(_pin.text)) {
      setState(() => _error = 'PIN staff harus tepat 6 digit.');
      return;
    }
    setState(() { _saving = true; _error = null; });
    try {
      await _request('POST', '/staff', body: {
        'staffCode': _code.text.trim(),
        'displayName': _name.text.trim(),
        'pin': _pin.text,
        'expectedStartTime': start.isEmpty ? null : start,
      });
      _code.clear();
      _name.clear();
      _pin.clear();
      _startTime.clear();
      if (mounted) _message('Staff berhasil ditambahkan.');
      await _load();
    } catch (error) {
      if (mounted) setState(() => _error = error.toString().replaceFirst('FormatException: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _editStaff(Map<String, dynamic> row) async {
    final staffId = row['id'];
    if (staffId is! String || staffId.isEmpty) {
      _message('ID staff tidak valid.');
      return;
    }
    final name = TextEditingController(text: '${row['displayName'] ?? ''}');
    final start = TextEditingController(text: '${row['expectedStartTime'] ?? ''}');
    final pin = TextEditingController();
    var status = row['status'] == 'inactive' ? 'inactive' : 'active';
    final formKey = GlobalKey<FormState>();
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Edit Staff • ${row['staffCode']}'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: name,
                      decoration: const InputDecoration(labelText: 'Nama staff'),
                      validator: (value) => value == null || value.trim().length < 2
                          ? 'Nama minimal 2 karakter.' : null,
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: pin,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'PIN baru (opsional)',
                        helperText: 'Kosongkan jika tidak ingin mengganti PIN.',
                      ),
                    ),
                    TextFormField(
                      controller: start,
                      decoration: const InputDecoration(
                        labelText: 'Jam mulai target (opsional)',
                        hintText: '09:00',
                        helperText: 'Kosongkan agar staff bebas absen.',
                      ),
                      validator: (value) {
                        final text = value?.trim() ?? '';
                        if (text.isNotEmpty &&
                            !RegExp(r'^(?:[01]\\d|2[0-3]):[0-5]\\d
    final radius = int.tryParse(_radius.text.trim());
    if (radius == null || radius < 25 || radius > 2000) {
      setState(() => _error = 'Radius harus antara 25–2000 meter.');
      return;
    }
    setState(() { _saving = true; _error = null; });
    try {
      await _request('PATCH', '/staff/geofence-radius', body: {'radiusMeters': radius});
      if (mounted) _message('Radius geofence disimpan.');
      await _load();
    } catch (error) {
      if (mounted) setState(() => _error = error.toString().replaceFirst('FormatException: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _formatTimestamp(dynamic value) {
    if (value == null) return '—';
    if (value is! String) return value.toString();
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return value;
    return parsed.toLocal().toString().split('.').first;
  }

  void _message(String value) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null && !FirefaBackendConfig.isConfigured) {
      return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!)));
    }
    return ListView(
      padding: const EdgeInsets.all(4),
      children: [
        Card(child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Radius geofence', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            const Text('Owner mengatur radius absensi outlet. Koordinat outlet harus sudah dikonfigurasi di backend.'),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: TextField(controller: _radius, keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Radius (meter)', helperText: '25–2000 meter'))),
              const SizedBox(width: 12),
              FilledButton(onPressed: _saving ? null : _saveRadius, child: const Text('Simpan')),
            ]),
          ]),
        )),
        Card(child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Tambah staff', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            const Text('Jam mulai opsional. Jika dikosongkan, staff bebas check-in dan tidak dinilai terlambat.'),
            const SizedBox(height: 12),
            TextField(controller: _code, decoration: const InputDecoration(labelText: 'Kode staff')),
            const SizedBox(height: 10),
            TextField(controller: _name, decoration: const InputDecoration(labelText: 'Nama staff')),
            const SizedBox(height: 10),
            TextField(controller: _pin, keyboardType: TextInputType.number, maxLength: 6, obscureText: true,
              decoration: const InputDecoration(labelText: 'PIN awal (6 digit)')),
            const SizedBox(height: 10),
            TextField(controller: _startTime, decoration: const InputDecoration(labelText: 'Jam mulai target (opsional)', hintText: '09:00')),
            const SizedBox(height: 14),
            FilledButton.icon(onPressed: _saving ? null : _createStaff,
              icon: const Icon(Icons.person_add_alt_1), label: Text(_saving ? 'Menyimpan…' : 'Tambah staff')),
          ]),
        )),
        if (_error != null) Card(child: ListTile(
          leading: const Icon(Icons.error_outline, color: Colors.red),
          title: Text(_error!),
          trailing: IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        )),
        Card(child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Performa absensi', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text('Ketepatan waktu dihitung hanya pada staff yang memiliki jam mulai target.'),
            const SizedBox(height: 12),
            if (_performance.isEmpty) const Text('Belum ada data performa.'),
            for (final row in _performance) ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const CircleAvatar(child: Icon(Icons.person_outline)),
              title: Text('${row['displayName']}'),
              subtitle: Text('Hadir ${row['attendanceDays']} hari • Terlambat ${row['lateDays']} hari dari ${row['evaluatedDays']} hari dinilai'),
              trailing: Text(row['punctualityPercent'] == null ? '—' : '${row['punctualityPercent']}%'),
            ),
          ]),
        )),

        Card(child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Riwayat absensi & foto check-in', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text('Riwayat terbaru dari server. Foto hanya dapat dibuka oleh Owner yang berwenang pada outlet tersebut.'),
            const SizedBox(height: 8),
            if (_attendance.isEmpty) const Text('Belum ada riwayat absensi pada outlet ini.'),
            for (final row in _attendance) ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.access_time),
              title: Text('${row['displayName']} • ${row['workDate']}'),
              subtitle: Text(
                'Masuk: ${_formatTimestamp(row['checkInAt'])}'
                ' • Pulang: ${row['checkOutAt'] == null ? 'Belum check-out' : _formatTimestamp(row['checkOutAt'])}'
                ' • Terlambat: ${row['lateMinutes'] ?? 0} menit',
              ),
              trailing: row['hasCheckInPhoto'] == true
                  ? IconButton(
                      tooltip: 'Lihat foto check-in',
                      onPressed: () => _showAttendancePhoto(row),
                      icon: const Icon(Icons.photo_camera_outlined),
                    )
                  : const Tooltip(message: 'Foto tidak tersedia', child: Icon(Icons.no_photography_outlined)),
            ),
          ]),
        )),
        Card(child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Daftar staff', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            if (_staff.isEmpty) const Text('Belum ada staff. Tambahkan staff di atas.'),
            for (final row in _staff) ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                child: Icon(row['status'] == 'inactive' ? Icons.person_off_outlined : Icons.badge_outlined),
              ),
              title: Text('${row['displayName']}'),
              subtitle: Text('${row['staffCode']} • ${row['expectedStartTime'] == null ? 'Bebas absen' : 'Target ${row['expectedStartTime']}'} • ${row['status'] == 'inactive' ? 'Nonaktif' : 'Aktif'}'),
              trailing: IconButton(
                tooltip: 'Edit data, reset PIN, atau ubah status',
                onPressed: _saving ? null : () => _editStaff(row),
                icon: const Icon(Icons.edit_outlined),
              ),
            ),
          ]),
        )),
        Align(alignment: Alignment.centerRight, child: TextButton.icon(
          onPressed: _load, icon: const Icon(Icons.refresh), label: const Text('Muat ulang'),
        )),
      ],
    );
  }
}
).hasMatch(text)) {
                          return 'Gunakan format HH:mm.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: status,
                      decoration: const InputDecoration(labelText: 'Status akun'),
                      items: const [
                        DropdownMenuItem(value: 'active', child: Text('Aktif')),
                        DropdownMenuItem(value: 'inactive', child: Text('Nonaktif')),
                      ],
                      onChanged: (value) {
                        if (value != null) setDialogState(() => status = value);
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () {
                if (!formKey.currentState!.validate()) return;
                if (pin.text.isNotEmpty && !RegExp(r'^\\d{6}
    final radius = int.tryParse(_radius.text.trim());
    if (radius == null || radius < 25 || radius > 2000) {
      setState(() => _error = 'Radius harus antara 25–2000 meter.');
      return;
    }
    setState(() { _saving = true; _error = null; });
    try {
      await _request('PATCH', '/staff/geofence-radius', body: {'radiusMeters': radius});
      if (mounted) _message('Radius geofence disimpan.');
      await _load();
    } catch (error) {
      if (mounted) setState(() => _error = error.toString().replaceFirst('FormatException: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _formatTimestamp(dynamic value) {
    if (value == null) return '—';
    if (value is! String) return value.toString();
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return value;
    return parsed.toLocal().toString().split('.').first;
  }

  void _message(String value) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null && !FirefaBackendConfig.isConfigured) {
      return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!)));
    }
    return ListView(
      padding: const EdgeInsets.all(4),
      children: [
        Card(child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Radius geofence', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            const Text('Owner mengatur radius absensi outlet. Koordinat outlet harus sudah dikonfigurasi di backend.'),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: TextField(controller: _radius, keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Radius (meter)', helperText: '25–2000 meter'))),
              const SizedBox(width: 12),
              FilledButton(onPressed: _saving ? null : _saveRadius, child: const Text('Simpan')),
            ]),
          ]),
        )),
        Card(child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Tambah staff', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            const Text('Jam mulai opsional. Jika dikosongkan, staff bebas check-in dan tidak dinilai terlambat.'),
            const SizedBox(height: 12),
            TextField(controller: _code, decoration: const InputDecoration(labelText: 'Kode staff')),
            const SizedBox(height: 10),
            TextField(controller: _name, decoration: const InputDecoration(labelText: 'Nama staff')),
            const SizedBox(height: 10),
            TextField(controller: _pin, keyboardType: TextInputType.number, maxLength: 6, obscureText: true,
              decoration: const InputDecoration(labelText: 'PIN awal (6 digit)')),
            const SizedBox(height: 10),
            TextField(controller: _startTime, decoration: const InputDecoration(labelText: 'Jam mulai target (opsional)', hintText: '09:00')),
            const SizedBox(height: 14),
            FilledButton.icon(onPressed: _saving ? null : _createStaff,
              icon: const Icon(Icons.person_add_alt_1), label: Text(_saving ? 'Menyimpan…' : 'Tambah staff')),
          ]),
        )),
        if (_error != null) Card(child: ListTile(
          leading: const Icon(Icons.error_outline, color: Colors.red),
          title: Text(_error!),
          trailing: IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        )),
        Card(child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Performa absensi', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text('Ketepatan waktu dihitung hanya pada staff yang memiliki jam mulai target.'),
            const SizedBox(height: 12),
            if (_performance.isEmpty) const Text('Belum ada data performa.'),
            for (final row in _performance) ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const CircleAvatar(child: Icon(Icons.person_outline)),
              title: Text('${row['displayName']}'),
              subtitle: Text('Hadir ${row['attendanceDays']} hari • Terlambat ${row['lateDays']} hari dari ${row['evaluatedDays']} hari dinilai'),
              trailing: Text(row['punctualityPercent'] == null ? '—' : '${row['punctualityPercent']}%'),
            ),
          ]),
        )),

        Card(child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Riwayat absensi & foto check-in', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text('Riwayat terbaru dari server. Foto hanya dapat dibuka oleh Owner yang berwenang pada outlet tersebut.'),
            const SizedBox(height: 8),
            if (_attendance.isEmpty) const Text('Belum ada riwayat absensi pada outlet ini.'),
            for (final row in _attendance) ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.access_time),
              title: Text('${row['displayName']} • ${row['workDate']}'),
              subtitle: Text(
                'Masuk: ${_formatTimestamp(row['checkInAt'])}'
                ' • Pulang: ${row['checkOutAt'] == null ? 'Belum check-out' : _formatTimestamp(row['checkOutAt'])}'
                ' • Terlambat: ${row['lateMinutes'] ?? 0} menit',
              ),
              trailing: row['hasCheckInPhoto'] == true
                  ? IconButton(
                      tooltip: 'Lihat foto check-in',
                      onPressed: () => _showAttendancePhoto(row),
                      icon: const Icon(Icons.photo_camera_outlined),
                    )
                  : const Tooltip(message: 'Foto tidak tersedia', child: Icon(Icons.no_photography_outlined)),
            ),
          ]),
        )),
        Card(child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Daftar staff', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            if (_staff.isEmpty) const Text('Belum ada staff. Tambahkan staff di atas.'),
            for (final row in _staff) ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.badge_outlined),
              title: Text('${row['displayName']}'),
              subtitle: Text('${row['staffCode']} • ${row['expectedStartTime'] == null ? 'Bebas absen' : 'Target ${row['expectedStartTime']}'} • ${row['status']}'),
            ),
          ]),
        )),
        Align(alignment: Alignment.centerRight, child: TextButton.icon(
          onPressed: _load, icon: const Icon(Icons.refresh), label: const Text('Muat ulang'),
        )),
      ],
    );
  }
}
).hasMatch(pin.text)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('PIN harus tepat 6 digit.')),
                  );
                  return;
                }
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Simpan perubahan'),
            ),
          ],
        ),
      ),
    );
    if (saved != true || !mounted) {
      name.dispose();
      start.dispose();
      pin.dispose();
      return;
    }
    setState(() { _saving = true; _error = null; });
    try {
      final body = <String, dynamic>{
        'displayName': name.text.trim(),
        'expectedStartTime': start.text.trim().isEmpty ? null : start.text.trim(),
        'status': status,
      };
      if (pin.text.isNotEmpty) body['pin'] = pin.text;
      await _request('PATCH', '/staff/$staffId', body: body);
      if (mounted) _message('Data staff berhasil diperbarui.');
      await _load();
    } catch (error) {
      if (mounted) setState(() => _error = error.toString().replaceFirst('FormatException: ', ''));
    } finally {
      name.dispose();
      start.dispose();
      pin.dispose();
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveRadius() async {
    final radius = int.tryParse(_radius.text.trim());
    if (radius == null || radius < 25 || radius > 2000) {
      setState(() => _error = 'Radius harus antara 25–2000 meter.');
      return;
    }
    setState(() { _saving = true; _error = null; });
    try {
      await _request('PATCH', '/staff/geofence-radius', body: {'radiusMeters': radius});
      if (mounted) _message('Radius geofence disimpan.');
      await _load();
    } catch (error) {
      if (mounted) setState(() => _error = error.toString().replaceFirst('FormatException: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _formatTimestamp(dynamic value) {
    if (value == null) return '—';
    if (value is! String) return value.toString();
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return value;
    return parsed.toLocal().toString().split('.').first;
  }

  void _message(String value) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null && !FirefaBackendConfig.isConfigured) {
      return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!)));
    }
    return ListView(
      padding: const EdgeInsets.all(4),
      children: [
        Card(child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Radius geofence', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            const Text('Owner mengatur radius absensi outlet. Koordinat outlet harus sudah dikonfigurasi di backend.'),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: TextField(controller: _radius, keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Radius (meter)', helperText: '25–2000 meter'))),
              const SizedBox(width: 12),
              FilledButton(onPressed: _saving ? null : _saveRadius, child: const Text('Simpan')),
            ]),
          ]),
        )),
        Card(child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Tambah staff', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            const Text('Jam mulai opsional. Jika dikosongkan, staff bebas check-in dan tidak dinilai terlambat.'),
            const SizedBox(height: 12),
            TextField(controller: _code, decoration: const InputDecoration(labelText: 'Kode staff')),
            const SizedBox(height: 10),
            TextField(controller: _name, decoration: const InputDecoration(labelText: 'Nama staff')),
            const SizedBox(height: 10),
            TextField(controller: _pin, keyboardType: TextInputType.number, maxLength: 6, obscureText: true,
              decoration: const InputDecoration(labelText: 'PIN awal (6 digit)')),
            const SizedBox(height: 10),
            TextField(controller: _startTime, decoration: const InputDecoration(labelText: 'Jam mulai target (opsional)', hintText: '09:00')),
            const SizedBox(height: 14),
            FilledButton.icon(onPressed: _saving ? null : _createStaff,
              icon: const Icon(Icons.person_add_alt_1), label: Text(_saving ? 'Menyimpan…' : 'Tambah staff')),
          ]),
        )),
        if (_error != null) Card(child: ListTile(
          leading: const Icon(Icons.error_outline, color: Colors.red),
          title: Text(_error!),
          trailing: IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        )),
        Card(child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Performa absensi', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text('Ketepatan waktu dihitung hanya pada staff yang memiliki jam mulai target.'),
            const SizedBox(height: 12),
            if (_performance.isEmpty) const Text('Belum ada data performa.'),
            for (final row in _performance) ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const CircleAvatar(child: Icon(Icons.person_outline)),
              title: Text('${row['displayName']}'),
              subtitle: Text('Hadir ${row['attendanceDays']} hari • Terlambat ${row['lateDays']} hari dari ${row['evaluatedDays']} hari dinilai'),
              trailing: Text(row['punctualityPercent'] == null ? '—' : '${row['punctualityPercent']}%'),
            ),
          ]),
        )),

        Card(child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Riwayat absensi & foto check-in', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text('Riwayat terbaru dari server. Foto hanya dapat dibuka oleh Owner yang berwenang pada outlet tersebut.'),
            const SizedBox(height: 8),
            if (_attendance.isEmpty) const Text('Belum ada riwayat absensi pada outlet ini.'),
            for (final row in _attendance) ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.access_time),
              title: Text('${row['displayName']} • ${row['workDate']}'),
              subtitle: Text(
                'Masuk: ${_formatTimestamp(row['checkInAt'])}'
                ' • Pulang: ${row['checkOutAt'] == null ? 'Belum check-out' : _formatTimestamp(row['checkOutAt'])}'
                ' • Terlambat: ${row['lateMinutes'] ?? 0} menit',
              ),
              trailing: row['hasCheckInPhoto'] == true
                  ? IconButton(
                      tooltip: 'Lihat foto check-in',
                      onPressed: () => _showAttendancePhoto(row),
                      icon: const Icon(Icons.photo_camera_outlined),
                    )
                  : const Tooltip(message: 'Foto tidak tersedia', child: Icon(Icons.no_photography_outlined)),
            ),
          ]),
        )),
        Card(child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Daftar staff', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            if (_staff.isEmpty) const Text('Belum ada staff. Tambahkan staff di atas.'),
            for (final row in _staff) ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.badge_outlined),
              title: Text('${row['displayName']}'),
              subtitle: Text('${row['staffCode']} • ${row['expectedStartTime'] == null ? 'Bebas absen' : 'Target ${row['expectedStartTime']}'} • ${row['status']}'),
            ),
          ]),
        )),
        Align(alignment: Alignment.centerRight, child: TextButton.icon(
          onPressed: _load, icon: const Icon(Icons.refresh), label: const Text('Muat ulang'),
        )),
      ],
    );
  }
}
