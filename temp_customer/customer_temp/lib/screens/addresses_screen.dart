import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/address_provider.dart';

class AddressesScreen extends StatefulWidget {
  const AddressesScreen({super.key});
  @override
  State<AddressesScreen> createState() => _AddressesScreenState();
}

class _AddressesScreenState extends State<AddressesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<AddressProvider>().loadAddresses());
  }

  @override
  Widget build(BuildContext context) {
    final addrProv = context.watch<AddressProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('My Addresses')),
      body: addrProv.addresses.isEmpty
          ? const Center(child: Text('No addresses saved'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: addrProv.addresses.length,
              itemBuilder: (_, i) {
                final a = addrProv.addresses[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: Icon(a.label == 'Home' ? Icons.home : a.label == 'Work' ? Icons.work : Icons.location_on, color: const Color(0xFF2563EB)),
                    title: Text(a.label, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(a.address, maxLines: 2, overflow: TextOverflow.ellipsis),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () async {
                        final confirm = await showDialog(context: context, builder: (_) => AlertDialog(
                          title: const Text('Delete Address?'),
                          content: const Text('Are you sure?'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
                          ],
                        ));
                        if (confirm == true) addrProv.deleteAddress(a.id);
                      },
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF2563EB),
        onPressed: () => _addAddress(context),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  void _addAddress(BuildContext context) {
    final labelController = TextEditingController(text: 'Home');
    final addressController = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Add Address', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(controller: labelController, decoration: const InputDecoration(labelText: 'Label (Home/Work)', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: addressController, maxLines: 2, decoration: const InputDecoration(labelText: 'Address', border: OutlineInputBorder())),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
                onPressed: () async {
                  if (addressController.text.isNotEmpty) {
                    await context.read<AddressProvider>().addAddress(label: labelController.text, address: addressController.text);
                    if (context.mounted) Navigator.pop(context);
                  }
                },
                child: const Text('Save Address'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
