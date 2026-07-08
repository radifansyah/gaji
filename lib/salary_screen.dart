import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SalaryCalculatorScreen extends StatefulWidget {
  const SalaryCalculatorScreen({super.key});

  @override
  State<SalaryCalculatorScreen> createState() => _SalaryCalculatorScreenState();
}

class _SalaryCalculatorScreenState extends State<SalaryCalculatorScreen> {
  Map<String, double> _defaultRates = {
    'Weekday': 785000,
    'Weekend': 700000,
    'Holiday': 900000,
  };

  List<Map<String, dynamic>> _workDays = [];
  DateTime _selectedDate = DateTime.now();
  String _dayType = 'Weekday';
  final TextEditingController _customRateController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  
  // PERBAIKAN 1: Tambahkan variabel status loading
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initApplicationData();
  }

  Future<void> _initApplicationData() async {
    final prefs = await SharedPreferences.getInstance();
    
    final String? cachedRates = prefs.getString('custom_default_rates');
    if (cachedRates != null) {
      final Map<String, dynamic> decodedRates = jsonDecode(cachedRates);
      _defaultRates = decodedRates.map((key, value) => MapEntry(key, value.toDouble()));
    }

    final String? cachedData = prefs.getString('saved_work_days');
    if (cachedData != null) {
      final List<dynamic> decodedList = jsonDecode(cachedData);
      _workDays = decodedList.map((item) {
        return {
          'date': DateTime.parse(item['date']),
          'type': item['type'],
          'rate': item['rate'].toDouble(),
        };
      }).toList();
    }

    // PERBAIKAN 2: Bungkus perubahan status dalam setState dan matikan loading
    setState(() {
      _updateAutomaticDayType(_selectedDate);
      _isLoading = false; // Data selesai dimuat, matikan loading
    });
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    final List<Map<String, dynamic>> formattedList = _workDays.map((item) {
      return {
        'date': item['date'].toIso8601String(),
        'type': item['type'],
        'rate': item['rate'],
      };
    }).toList();
    await prefs.setString('saved_work_days', jsonEncode(formattedList));
  }

  Future<void> _saveDefaultRates() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('custom_default_rates', jsonEncode(_defaultRates));
  }

  void _updateAutomaticDayType(DateTime date) {
    if (date.weekday == DateTime.saturday || date.weekday == DateTime.sunday) {
      _dayType = 'Weekend';
    } else {
      _dayType = 'Weekday';
    }
    _customRateController.text = _defaultRates[_dayType]!.toStringAsFixed(0);
    _dateController.text = DateFormat('EEEE, dd MMMM yyyy', 'id_ID').format(date);
  }

  void _onDateChanged(DateTime date) {
    setState(() {
      _selectedDate = date;
      _updateAutomaticDayType(date);
    });
  }

  void _showSettingsDialog() {
    final weekdayController = TextEditingController(text: _defaultRates['Weekday']!.toStringAsFixed(0));
    final weekendController = TextEditingController(text: _defaultRates['Weekend']!.toStringAsFixed(0));
    final holidayController = TextEditingController(text: _defaultRates['Holiday']!.toStringAsFixed(0));

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            Icon(Icons.settings_outlined, color: Colors.teal),
            SizedBox(width: 10),
            Text('Setelan Standar Gaji', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Ubah nominal standar berikut sesuai dengan rate gaji Anda harian.',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: weekdayController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Senin - Jumat (Normal)',
                  prefixText: 'Rp ',
                  border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: weekendController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Sabtu - Minggu',
                  prefixText: 'Rp ',
                  border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: holidayController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Tanggal Merah / Libur',
                  prefixText: 'Rp ',
                  border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              setState(() {
                _defaultRates['Weekday'] = double.tryParse(weekdayController.text) ?? _defaultRates['Weekday']!;
                _defaultRates['Weekend'] = double.tryParse(weekendController.text) ?? _defaultRates['Weekend']!;
                _defaultRates['Holiday'] = double.tryParse(holidayController.text) ?? _defaultRates['Holiday']!;
                _customRateController.text = _defaultRates[_dayType]!.toStringAsFixed(0);
              });
              _saveDefaultRates();
              Navigator.pop(context);
              
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Pengaturan gaji berhasil diperbarui!'),
                  behavior: SnackBarBehavior.floating,
                  backgroundColor: Colors.teal,
                ),
              );
            },
            child: const Text('Simpan', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _addWorkDay() {
    bool isDateAlreadyExist = _workDays.any((item) {
      DateTime existingDate = item['date'];
      return existingDate.year == _selectedDate.year &&
             existingDate.month == _selectedDate.month &&
             existingDate.day == _selectedDate.day;
    });

    if (isDateAlreadyExist) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
              SizedBox(width: 10),
              Text('Tanggal Sudah Ada', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: Text(
            'Gaji untuk tanggal ${DateFormat('dd MMMM yyyy', 'id_ID').format(_selectedDate)} sudah pernah diinput.\n\nSilakan hapus data lama terlebih dahulu jika ingin menggantinya.',
            style: const TextStyle(fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Mengerti', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal)),
            ),
          ],
        ),
      );
      return;
    }

    double rate = double.tryParse(_customRateController.text) ?? 0;
    setState(() {
      _workDays.insert(0, {
        'date': _selectedDate,
        'type': _dayType,
        'rate': rate,
      });
    });
    
    _saveData();
    _onDateChanged(DateTime.now());
    FocusScope.of(context).unfocus();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Hari kerja berhasil ditambahkan!'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: Colors.teal.shade700,
      ),
    );
  }

  double get _totalSalary => _workDays.fold(0, (sum, item) => sum + item['rate']);

  int get _weekdayCount => _workDays.where((item) => item['type'] == 'Weekday').length;
  int get _weekendCount => _workDays.where((item) => item['type'] == 'Weekend').length;
  int get _holidayCount => _workDays.where((item) => item['type'] == 'Holiday').length;

  String _formatRupiah(double amount) {
    return NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(amount);
  }

  Color _getColorForType(String type) {
    switch (type) {
      case 'Weekend': return Colors.amber.shade700;
      case 'Holiday': return Colors.indigo.shade600;
      default: return Colors.teal.shade600;
    }
  }

  String _getLabelForType(String type) {
    switch (type) {
      case 'Weekend': return 'Sabtu - Minggu';
      case 'Holiday': return 'Tanggal Merah';
      default: return 'Senin - Jumat';
    }
  }

  Widget _buildStatCard({required String label, required int count, required Color color}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200, width: 1),
        ),
        child: Column(
          children: [
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade500),
            ),
            const SizedBox(height: 6),
            Text(
              '$count Hari',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: color),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff8fafc),
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text('Truba Jaga Cita', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.5)),
        centerTitle: false,
        titleSpacing: 20,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xff0f172a),
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_rounded, color: Color(0xff475569)),
            onPressed: _showSettingsDialog,
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: Colors.grey.shade200, height: 1),
        ),
      ),
      // PERBAIKAN 3: Jika masih memuat data, tampilkan loading spinner melingkar di tengah layar
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.teal),
            )
          : SafeArea(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 16),
                      
                      // --- KARTU TOTAL GAJI ---
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.teal.shade700, Colors.green.shade600],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.teal.shade700.withOpacity(0.3),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            )
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ESTIMASI TOTAL GAJI',
                              style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    _formatRupiah(_totalSalary),
                                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.5),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                                  child: const Icon(Icons.wallet, color: Colors.white, size: 28),
                                )
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Terhitung dari ${_workDays.length} hari kerja',
                              style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // --- RINCIAN JUMLAH HARI ---
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildStatCard(
                            label: 'Senin - Jumat', 
                            count: _weekdayCount, 
                            color: Colors.teal.shade600
                          ),
                          const SizedBox(width: 8),
                          _buildStatCard(
                            label: 'Sabtu - Minggu', 
                            count: _weekendCount, 
                            color: Colors.amber.shade700
                          ),
                          const SizedBox(width: 8),
                          _buildStatCard(
                            label: 'Tanggal Merah', 
                            count: _holidayCount, 
                            color: Colors.indigo.shade600
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // --- FORM INPUT SEJAJAR ---
                      Card(
                        color: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                          side: BorderSide(color: Colors.grey.shade200, width: 1.5),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextField(
                                controller: _dateController,
                                readOnly: true,
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xff1e293b)),
                                onTap: () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: _selectedDate,
                                    firstDate: DateTime(2025),
                                    lastDate: DateTime(2030),
                                    locale: const Locale('id', 'ID'),
                                  );
                                  if (picked != null) _onDateChanged(picked);
                                },
                                decoration: const InputDecoration(
                                  labelText: 'Tanggal Kerja',
                                  labelStyle: TextStyle(color: Colors.grey, fontSize: 13),
                                  prefixIcon: Icon(Icons.calendar_today_rounded, color: Colors.grey),
                                  suffixIcon: Icon(Icons.chevron_right_rounded, color: Colors.grey),
                                  border: InputBorder.none,
                                ),
                              ),
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 2.0),
                                child: Divider(height: 1, color: Color(0xfff1f5f9)),
                              ),

                              DropdownButtonFormField<String>(
                                value: _dayType,
                                dropdownColor: Colors.white,
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xff1e293b), fontSize: 15),
                                decoration: InputDecoration(
                                  labelText: 'Kategori Hari',
                                  labelStyle: const TextStyle(color: Colors.grey, fontSize: 13),
                                  prefixIcon: Icon(Icons.layers_outlined, color: _getColorForType(_dayType)),
                                  border: InputBorder.none,
                                ),
                                items: const [
                                  DropdownMenuItem(value: 'Weekday', child: Text('Senin - Jumat (Normal)')),
                                  DropdownMenuItem(value: 'Weekend', child: Text('Sabtu - Minggu')),
                                  DropdownMenuItem(value: 'Holiday', child: Text('Tanggal Merah / Libur')),
                                ],
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() {
                                      _dayType = value;
                                      _customRateController.text = _defaultRates[value]!.toStringAsFixed(0);
                                    });
                                  }
                                },
                              ),
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 2.0),
                                child: Divider(height: 1, color: Color(0xfff1f5f9)),
                              ),

                              TextField(
                                controller: _customRateController,
                                keyboardType: TextInputType.number,
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xff1e293b), fontSize: 15),
                                decoration: InputDecoration(
                                  labelText: 'Nominal Gaji (Bisa Diedit)',
                                  labelStyle: const TextStyle(color: Colors.grey, fontSize: 13),
                                  prefixIcon: Icon(Icons.payments_outlined, color: _getColorForType(_dayType)),
                                  prefixText: 'Rp ',
                                  prefixStyle: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xff1e293b), fontSize: 15),
                                  border: InputBorder.none,
                                ),
                              ),
                              const SizedBox(height: 16),

                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _getColorForType(_dayType),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  minimumSize: const Size.fromHeight(52),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                ),
                                onPressed: _addWorkDay,
                                child: const Text('Simpan Hari Kerja', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // --- RIWAYAT INPUT ---
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('RIWAYAT INPUT', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.5)),
                          if (_workDays.isNotEmpty)
                            TextButton(
                              onPressed: () {
                                setState(() => _workDays.clear());
                                _saveData();
                              },
                              child: const Text('Hapus Semua', style: TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.bold)),
                            )
                        ],
                      ),
                      const SizedBox(height: 8),
                      
                      _workDays.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.only(top: 40.0),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.assignment_turned_in_outlined, size: 48, color: Colors.grey.shade300),
                                    const SizedBox(height: 12),
                                    Text('Belum ada data tercatat', style: TextStyle(color: Colors.grey.shade400, fontWeight: FontWeight.w500)),
                                  ],
                                ),
                              ),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _workDays.length,
                              itemBuilder: (context, index) {
                                final item = _workDays[index];
                                final cardColor = _getColorForType(item['type']);
                                
                                return Container(
                                  margin: const EdgeInsets.symmetric(vertical: 6),
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: Colors.grey.shade100, width: 1),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(color: cardColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                                        child: Icon(Icons.check_circle_outline_rounded, color: cardColor, size: 22),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              DateFormat('EEEE, dd MMM yyyy', 'id_ID').format(item['date']),
                                              style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xff1e293b), fontSize: 15),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              _getLabelForType(item['type']),
                                              style: TextStyle(color: Colors.grey.shade500, fontSize: 12, fontWeight: FontWeight.w500),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            _formatRupiah(item['rate']),
                                            style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xff1e293b), fontSize: 15),
                                          ),
                                          const SizedBox(height: 2),
                                          GestureDetector(
                                            onTap: () {
                                              setState(() {
                                                _workDays.removeAt(index);
                                              });
                                              _saveData();
                                            },
                                            child: Text(
                                              'Hapus',
                                              style: TextStyle(color: Colors.red.shade400, fontSize: 12, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                        ],
                                      )
                                    ],
                                  ),
                                );
                              },
                            ),
                      const SizedBox(height: 24),
                      
                      // Credit Developer
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Center(
                          child: Text(
                            '© 2026 Muh Radifansyah R',
                            style: TextStyle(
                              color: Colors.grey, 
                              fontSize: 11, 
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}