import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:dio/dio.dart';
import '../../../data/services/api_service.dart';
import '../../../logic/pos_controller.dart';
import 'pin_code_screen.dart';
import '../main_navigation_screen.dart';

class StaffSelectionPage extends StatefulWidget {
  final String? cafeId;
  final bool isFromTerminal;
  
  const StaffSelectionPage({
    super.key, 
    this.cafeId,
    this.isFromTerminal = true,
  });

  @override
  State<StaffSelectionPage> createState() => _StaffSelectionPageState();
}

class _StaffSelectionPageState extends State<StaffSelectionPage> {
  List<dynamic> _staff = [];
  String _selectedRole = 'WAITER';
  bool _isLoading = true;
  dynamic _selectedStaff;
  String _enteredPin = "";

  @override
  void initState() {
    super.initState();
    _fetchStaff();
  }

  Future<void> _fetchStaff() async {
    try {
      final List<dynamic> staff;
      if (widget.cafeId != null) {
        staff = await ApiService().getStaffPublic(widget.cafeId!);
      } else {
        staff = await ApiService().getTerminalStaff();
      }
      
      if (mounted) {
        setState(() {
          _staff = staff;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (e is DioException && e.response?.statusCode == 401) return;
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onDigitPress(String digit) async {
    if (_selectedStaff == null) {
      Get.snackbar("Eslatma", "Oldin xodimni tanlang", backgroundColor: Colors.orange, colorText: Colors.white);
      return;
    }

    if (_enteredPin.length < 4) {
      setState(() => _enteredPin += digit);
      
      if (_enteredPin.length == 4) {
        _login();
      }
    }
  }

  void _onBackspace() {
    if (_enteredPin.isNotEmpty) {
      setState(() => _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1));
    }
  }

  Future<void> _login() async {
    try {
      final userId = _selectedStaff['id'].toString();
      final response = await ApiService().loginWithPin(
        userId, 
        _enteredPin,
        deviceId: Get.find<POSController>().currentTerminal.value?['id']?.toString() ?? "unknown_device",
        deviceName: Get.find<POSController>().currentTerminal.value?['name'] ?? "POS Terminal"
      );
      
      Get.find<POSController>().setCurrentUser(response['user']);
      Get.find<POSController>().authenticatePin(true);
      
      Get.offAllNamed('/main');
      Get.snackbar("Muvaffaqiyatli", "Xush kelibsiz, ${response['user']['name']}!", 
        backgroundColor: Colors.green, colorText: Colors.white);
    } catch (e) {
      String errorMsg = "PIN kod noto'g'ri";
      if (e is DioException) {
        final dynamic responseData = e.response?.data;
        if (responseData != null && responseData is Map && responseData.containsKey('detail')) {
          errorMsg = responseData['detail']?.toString() ?? errorMsg;
        }
      }
      Get.snackbar("Xato", errorMsg, backgroundColor: Colors.red, colorText: Colors.white);
      setState(() => _enteredPin = "");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: const Text('Xodimni tanlang', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.red),
            onPressed: () {
              final pos = Get.find<POSController>();
              if (widget.isFromTerminal) ApiService().clearTerminalToken();
              pos.setDeviceRole(null);
              pos.setWaiterCafeId(null);
              pos.setCurrentTerminal(null);
              pos.logout();
            },
          ),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth > 800) {
                return Row(
                  children: [
                    Expanded(flex: 3, child: _buildLeftStaffList()),
                    const VerticalDivider(width: 1, color: Color(0xFFE5E7EB)),
                    Expanded(flex: 2, child: _buildRightPinEntry()),
                  ],
                );
              } else {
                return Column(
                  children: [
                    _buildFilterBar(),
                    Expanded(child: _buildStaffGrid()),
                    if (_selectedStaff != null)
                      _buildBottomPinSheet(),
                  ],
                );
              }
            },
          ),
    );
  }

  Widget _buildLeftStaffList() {
    return Column(
      children: [
        _buildFilterBar(),
        Expanded(child: _buildStaffGrid()),
      ],
    );
  }

  Widget _buildRightPinEntry() {
    if (_selectedStaff == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.touch_app_outlined, size: 80, color: Colors.grey),
            SizedBox(height: 16),
            Text("PIN kodni terish uchun\nxodimni tanlang", 
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 18, fontWeight: FontWeight.w500)),
          ],
        ),
      );
    }

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildStaffAvatar(_selectedStaff, size: 100),
          const SizedBox(height: 20),
          Text(_selectedStaff['name'], style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
          Text(_selectedStaff['role'], style: const TextStyle(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.w600)),
          const SizedBox(height: 40),
          _buildPinIndicators(),
          const SizedBox(height: 40),
          _buildKeypad(),
        ],
      ),
    );
  }

  Widget _buildBottomPinSheet() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              _buildStaffAvatar(_selectedStaff, size: 50),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_selectedStaff['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    Text(_selectedStaff['role'], style: const TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
              IconButton(onPressed: () => setState(() => _selectedStaff = null), icon: const Icon(Icons.close)),
            ],
          ),
          const SizedBox(height: 20),
          _buildPinIndicators(),
          const SizedBox(height: 20),
          _buildKeypad(small: true),
        ],
      ),
    );
  }

  Widget _buildStaffAvatar(dynamic member, {double size = 70}) {
    IconData icon;
    Color color;
    switch (member['role']) {
      case 'WAITER': icon = Icons.flatware; color = Colors.blue; break;
      case 'CASHIER': icon = Icons.point_of_sale; color = Colors.green; break;
      case 'CAFE_ADMIN': icon = Icons.admin_panel_settings; color = Colors.purple; break;
      default: icon = Icons.person; color = Colors.grey;
    }
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
      child: Icon(icon, color: color, size: size * 0.5),
    );
  }

  Widget _buildPinIndicators() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (index) {
        bool isFilled = index < _enteredPin.length;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 10),
          width: 20, height: 20,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isFilled ? const Color(0xFFFF9500) : Colors.transparent,
            border: Border.all(color: isFilled ? const Color(0xFFFF9500) : Colors.grey.shade300, width: 2),
          ),
        );
      }),
    );
  }

  Widget _buildKeypad({bool small = false}) {
    double btnSize = small ? 60 : 75;
    return Column(
      children: [
        for (var row in [['1', '2', '3'], ['4', '5', '6'], ['7', '8', '9']])
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var digit in row)
                  _buildKeypadButton(digit, () => _onDigitPress(digit), size: btnSize),
              ],
            ),
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(width: btnSize + 12),
            _buildKeypadButton('0', () => _onDigitPress('0'), size: btnSize),
            Padding(
              padding: const EdgeInsets.only(left: 12),
              child: _buildKeypadButton('⌫', _onBackspace, isDelete: true, size: btnSize),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildKeypadButton(String label, VoidCallback onTap, {bool isDelete = false, double size = 75}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6),
      width: size, height: size,
      child: Material(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Center(
            child: Text(label, style: TextStyle(fontSize: size * 0.35, fontWeight: FontWeight.bold, color: isDelete ? Colors.red : Colors.black87)),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterBar() {
    final roles = [
      {'id': 'WAITER', 'name': 'Ofitsiant', 'icon': Icons.flatware},
      {'id': 'CASHIER', 'name': 'Kassir', 'icon': Icons.point_of_sale},
      {'id': 'CAFE_ADMIN', 'name': 'Admin', 'icon': Icons.admin_panel_settings},
    ];
    return Container(
      height: 70, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.white,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: roles.length,
        itemBuilder: (context, index) {
          final role = roles[index];
          final bool isSelected = _selectedRole == role['id'];
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ChoiceChip(
              label: Row(children: [
                Icon(role['icon'] as IconData, size: 18, color: isSelected ? Colors.white : Colors.grey),
                const SizedBox(width: 8),
                Text(role['name'] as String),
              ]),
              selected: isSelected,
              onSelected: (val) { if (val) setState(() => _selectedRole = role['id'] as String); },
              selectedColor: const Color(0xFFFF9500),
              labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black87, fontWeight: FontWeight.bold),
              backgroundColor: Colors.grey.shade100,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStaffGrid() {
    final filteredStaff = _staff.where((s) => s['role'] == _selectedRole).toList();
    if (filteredStaff.isEmpty && !_isLoading) {
      return const Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text('Xodimlar mavjud emas', style: TextStyle(fontSize: 16, color: Colors.grey)),
        ],
      ));
    }
    return GridView.builder(
      padding: const EdgeInsets.all(24),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 220, childAspectRatio: 0.85, crossAxisSpacing: 20, mainAxisSpacing: 20,
      ),
      itemCount: filteredStaff.length,
      itemBuilder: (context, index) {
        final member = filteredStaff[index];
        final isSelected = _selectedStaff?['id'] == member['id'];
        return GestureDetector(
          onTap: () => setState(() { _selectedStaff = member; _enteredPin = ""; }),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: isSelected ? Border.all(color: const Color(0xFFFF9500), width: 3) : null,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildStaffAvatar(member, size: 80),
                const SizedBox(height: 16),
                Text(member['name'], textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Text(member['role'], style: const TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        );
      },
    );
  }
}
