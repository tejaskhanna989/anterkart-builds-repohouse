import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/api_config.dart';
import '../models/review_deletion.dart';
import '../providers/auth_provider.dart';
import '../providers/product_provider.dart';
import '../theme/app_theme.dart';
import 'addresses_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  List<ReviewDeletion> _deletionRequests = [];
  bool _loadingRequests = false;
  int? _loadedForCustomer;
  final Set<int> _handling = {};

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final authCustomer = auth.customer;
    if (auth.isLoggedIn && authCustomer != null && _loadedForCustomer != authCustomer.id) {
      _loadedForCustomer = authCustomer.id;
      _deletionRequests = [];
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadDeletionRequests());
    }
    final name = authCustomer?.name ?? 'Guest';
    final email = authCustomer?.email ?? '';
    final phone = authCustomer?.phone ?? '';
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.blueDark, AppColors.blue, Color(0xFF3B7BFF)],
              ),
            ),
            child: Row(
              children: [
                Stack(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                      child: CircleAvatar(
                        radius: 36,
                        backgroundColor: Colors.white,
                        child: Text(
                          name.isNotEmpty ? name[0].toUpperCase() : 'A',
                          style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: AppColors.blue),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: const BoxDecoration(color: AppColors.orange, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)]),
                        child: const Icon(Icons.edit, size: 14, color: Colors.white),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.3)),
                      if (email.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(email, style: const TextStyle(fontSize: 13, color: Colors.white70), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                      if (phone.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text('+91 $phone', style: const TextStyle(fontSize: 13, color: Colors.white70)),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_loadingRequests || _deletionRequests.isNotEmpty)
            _deletionSection(context, auth),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(
              children: [
                _group('Orders & Delivery', [
                  _tile(Icons.receipt_long_outlined, AppColors.blue, 'My Orders', () => Navigator.pushNamed(context, '/orders'), 'Order history & tracking'),
                  _tile(Icons.location_on_outlined, AppColors.orange, 'My Addresses', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddressesScreen())), 'Saved delivery locations'),
                ]),
                _group('Account', [
                  _tile(Icons.person_outline, AppColors.blue, 'Edit Profile', () => _editProfile(context), 'Update name & phone'),
                  _tile(Icons.storefront_outlined, AppColors.orange, 'Become a Vendor', () => _launchVendorRegistration(context), 'Sell your products on Otamzo'),
                  _tile(Icons.help_outline, AppColors.blue, 'Help & Support', () => _showSupport(context), 'Contact us anytime'),
                ]),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Color(0xFFEED2D2), width: 1.2),
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () async {
                      await context.read<AuthProvider>().logout();
                      if (context.mounted) Navigator.pushReplacementNamed(context, '/login');
                    },
                    icon: const Icon(Icons.logout, color: Colors.red),
                    label: const Text('Logout', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadDeletionRequests() async {
    if (_loadingRequests) return;
    setState(() => _loadingRequests = true);
    final requests = await context.read<ProductProvider>().fetchReviewDeletions();
    if (!mounted) return;
    setState(() { _deletionRequests = requests; _loadingRequests = false; });
  }

  Future<void> _respond(ReviewDeletion request, bool confirm) async {
    final provider = context.read<ProductProvider>();
    setState(() => _handling.add(request.id));
    final err = await provider.respondReviewDeletion(request.id, confirm: confirm);
    if (!mounted) return;
    setState(() => _handling.remove(request.id));
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      return;
    }
    setState(() => _deletionRequests.removeWhere((r) => r.id == request.id));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(confirm ? 'Your review has been deleted' : 'Your review stays as it is')),
    );
  }

  Widget _deletionSection(BuildContext context, AuthProvider auth) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF0D9A0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(color: AppColors.orange, shape: BoxShape.circle),
                child: const Icon(Icons.notifications_active_outlined, size: 18, color: Colors.white),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text('Review deletion requests', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.ink)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'The store has asked to remove ${_deletionRequests.isEmpty ? 'a' : 'your'} review${_deletionRequests.length == 1 ? '' : 's'}. Do you agree?',
            style: const TextStyle(fontSize: 12.5, color: Color(0xFF6B5B2A)),
          ),
          const SizedBox(height: 12),
          if (_loadingRequests)
            const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Center(child: CircularProgressIndicator(strokeWidth: 2.5)))
          else
            ..._deletionRequests.map((req) => _deletionCard(req)),
        ],
      ),
    );
  }

  Widget _deletionCard(ReviewDeletion req) {
    final busy = _handling.contains(req.id);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF0E2C0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(req.productName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.ink), maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              if (req.date.isNotEmpty)
                Text(req.date, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: List.generate(5, (i) {
              final filled = i < req.rating;
              return Icon(filled ? Icons.star : Icons.star_border, color: filled ? Colors.amber : Colors.grey.shade300, size: 15);
            }),
          ),
          if (req.comment.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('"${req.comment}"', style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary, fontStyle: FontStyle.italic), maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 38,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Color(0xFFEECBCB), width: 1.2),
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 38),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: busy ? null : () => _confirmDelete(req),
                    child: busy
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Yes, delete it', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 38,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.blue,
                      side: const BorderSide(color: Color(0xFFBBD1FF), width: 1.2),
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 38),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: busy ? null : () => _respond(req, false),
                    child: busy
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('No, keep it', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _confirmDelete(ReviewDeletion req) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Delete review on ${req.productName}?'),
        content: const Text('The store asked to remove your review and your rating. Once deleted it cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _respond(req, true);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _group(String title, List<Widget> tiles) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
          child: Text(title.toUpperCase(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: 0.5)),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFEFEFEF)),
          ),
          child: Column(children: tiles),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _tile(IconData icon, Color color, String label, VoidCallback onTap, String subtitle) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(color: color.withOpacity( 0.12), borderRadius: BorderRadius.circular(13)),
          child: Icon(icon, color: color, size: 22),
        ),
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        trailing: const Icon(Icons.chevron_right, color: Color(0xFFBBBBBB)),
      ),
    );
  }

  void _editProfile(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final nameController = TextEditingController(text: auth.customer?.name ?? '');
    final phoneController = TextEditingController(text: auth.customer?.phone ?? '');
    final formKey = GlobalKey<FormState>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(context).viewInsets.bottom + 24),
        child: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.lightGrey, borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 20),
                const Text('Edit Profile', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 20),
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Name', prefixIcon: Icon(Icons.person_outline, color: AppColors.blue)),
                  validator: (v) => v != null && v.trim().isNotEmpty ? null : 'Name required',
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Phone', prefixIcon: Icon(Icons.phone_outlined, color: AppColors.blue)),
                  validator: (v) => v != null && v.length >= 10 ? null : 'Enter valid phone',
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      if (!formKey.currentState!.validate()) return;
                      auth.updateProfile(name: nameController.text, phone: phoneController.text);
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated')));
                    },
                    child: const Text('Save Changes'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _launchVendorRegistration(BuildContext context) async {
    final uri = Uri.parse('${ApiConfig.baseUrl.replaceAll('/api/mobile', '')}/vendor-register.php');
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open the vendor registration page')));
    }
  }

  void _showSupport(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Help & Support', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.orange.withOpacity( 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: const BoxDecoration(color: AppColors.orange, shape: BoxShape.circle),
                    child: const Icon(Icons.schedule, size: 20, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Support isn\'t available right now.\nPlease try again later.',
                      style: TextStyle(color: AppColors.ink, fontWeight: FontWeight.w600, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Got it'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
