import 'package:flutter/material.dart';

class SelectUserTypeScreen extends StatelessWidget {
  const SelectUserTypeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Soft, modern colors
    const donorColor = Color(0xFF4B5C6B);
    const recipientColor = Color(0xFFD9E6DC);
    const hospitalColor = Color(0xFFF9EEE5);
    const bloodBankColor = Color(0xFFE8EEF6);
    const adminColor = Color(0xFFF3E9EE);
    const iconColor = Color(0xFF334155);
    const titleColor = Color(0xFF334155);

    // Reusable card widget for each role
    Widget roleCard({
      required Color color,
      required IconData icon,
      required String label,
      required VoidCallback onTap,
      Color? iconColorOverride,
      Color? textColor,
    }) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Container(
            width: double.infinity,
            height: 90,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.07),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                const SizedBox(width: 24),
                Icon(icon, color: iconColorOverride ?? iconColor, size: 38),
                const SizedBox(width: 24),
                Text(
                  label,
                  style: TextStyle(
                    color: textColor ?? iconColor,
                    fontSize: 19,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 16),
              // Logo and app title
              Column(
                children: [
                  Image.asset(
                    'lib/assets/images/logo.png',
                    width: 48,
                    height: 48,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    "LIFE DROP",
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: titleColor,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              const Text(
                "Select Your Role",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: titleColor,
                ),
              ),
              const SizedBox(height: 34),
              // Vertical list of role cards
              Expanded(
                child: ListView(
                  children: [
                    roleCard(
                      color: donorColor,
                      icon: Icons.bloodtype,
                      label: "Donor",
                      iconColorOverride: Colors.white,
                      textColor: Colors.white,
                      onTap: () => Navigator.pushNamed(context, '/donor_signup'),

                    ),
                    roleCard(
                      color: recipientColor,
                      icon: Icons.favorite,
                      label: "Recipient",
                      onTap: () => Navigator.pushNamed(context, '/recipient_signup'),
                    ),
                    roleCard(
                      color: hospitalColor,
                      icon: Icons.local_hospital,
                      label: "Hospital",
                      onTap: () => Navigator.pushNamed(context, '/hospital_signup'),
                    ),
                    roleCard(
                      color: bloodBankColor,
                      icon: Icons.local_drink, // Use a custom SVG for blood bag if needed
                      label: "Blood Bank",
                      onTap: () => Navigator.pushNamed(context, '/blood_bank_signup'),
                    ),
                    roleCard(
                      color: adminColor,
                      icon: Icons.settings,
                      label: "Admin",
                      onTap: () => Navigator.pushNamed(context, '/admin_signup'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
