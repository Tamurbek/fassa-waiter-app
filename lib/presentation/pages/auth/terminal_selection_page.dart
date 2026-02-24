import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../data/services/api_service.dart';
import '../../../logic/pos_controller.dart';
import 'staff_selection_page.dart';

class TerminalSelectionPage extends StatefulWidget {
  const TerminalSelectionPage({super.key});

  @override
  State<TerminalSelectionPage> createState() => _TerminalSelectionPageState();
}

class _TerminalSelectionPageState extends State<TerminalSelectionPage> {
  final _apiService = ApiService();
  final _posController = Get.find<POSController>();
  List<dynamic> _terminals = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchTerminals();
  }

  Future<void> _fetchTerminals() async {
    try {
      final terminals = await _apiService.getTerminals();
      setState(() {
        _terminals = terminals;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      Get.snackbar('Xato', 'Terminallarni yuklab bo\'lmadi');
    }
  }

  void _showPasswordDialog(Map<String, dynamic> terminal) {
    final passwordController = TextEditingController();
    bool isAuthenticating = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: Text('${terminal['name']} terminaliga ulanish'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Terminal parolini kiriting'),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Parol',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Bekor qilish'),
            ),
            ElevatedButton(
              onPressed: isAuthenticating ? null : () async {
                if (passwordController.text.isEmpty) return;
                
                setModalState(() => isAuthenticating = true);
                try {
                  final response = await _apiService.loginTerminal(
                    terminal['username'],
                    passwordController.text,
                  );
                  
                  _posController.setCurrentTerminal(response['terminal']);
                  
                  Navigator.pop(context); // Close dialog
                  Get.offAllNamed('/staff-selection');
                  Get.snackbar('Muvaffaqiyatli', '${terminal['name']} terminaliga ulandi', 
                    backgroundColor: Colors.green, colorText: Colors.white);
                } catch (e) {
                  setModalState(() => isAuthenticating = false);
                  Get.snackbar('Xatolik', 'Parol noto\'g\'ri', 
                    backgroundColor: Colors.red, colorText: Colors.white);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF9500),
                foregroundColor: Colors.white,
              ),
              child: isAuthenticating 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Ulanish'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Terminalni tanlang'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      backgroundColor: const Color(0xFFF3F4F6),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _terminals.isEmpty
              ? const Center(child: Text('Faol terminallar topilmadi'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _terminals.length,
                  itemBuilder: (context, index) {
                    final terminal = _terminals[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF9500).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.monitor, color: Color(0xFFFF9500)),
                        ),
                        title: Text(
                          terminal['name'],
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                        subtitle: Text('ID: ${terminal['username']}'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _showPasswordDialog(terminal),
                      ),
                    );
                  },
                ),
    );
  }
}
