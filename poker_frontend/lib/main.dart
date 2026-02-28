import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:google_fonts/google_fonts.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PokerApp());
}

class PokerApp extends StatelessWidget {
  const PokerApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pro Poker Evaluator',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0B132B), // Deep dark premium blue
        primaryColor: const Color(0xFFE5B94E), // Gold accent
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFE5B94E),
          secondary: Color(0xFF1BA098),
          surface: Color(0xFF1C2541),
        ),
        textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF2E3856).withOpacity(0.5),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE5B94E), width: 1.5),
          ),
          labelStyle: const TextStyle(color: Colors.white70),
          hintStyle: const TextStyle(color: Colors.white38),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFE5B94E),
            foregroundColor: const Color(0xFF0B132B),
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            textStyle: GoogleFonts.outfit(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              letterSpacing: 1.1,
            ),
          ),
        ),
      ),
      home: const PokerHome(),
    );
  }
}

class PokerHome extends StatefulWidget {
  const PokerHome({Key? key}) : super(key: key);

  @override
  State<PokerHome> createState() => _PokerHomeState();
}

class _PokerHomeState extends State<PokerHome> {
  late TextEditingController holeCard1Controller;
  late TextEditingController holeCard2Controller;
  late TextEditingController communityCards1Controller;
  late TextEditingController communityCards2Controller;
  late TextEditingController communityCards3Controller;
  late TextEditingController communityCards4Controller;
  late TextEditingController communityCards5Controller;
  late TextEditingController numPlayersController;
  late TextEditingController simulationsController;

  String resultMessage = '';
  String resultValue = '';
  bool isLoading = false;

    String get backendUrl {
      final host = Uri.base.host;
      if (host.isEmpty || host == 'localhost' || host == '127.0.0.1') {
        return 'http://localhost:8080';
      }
      return Uri.base.origin;
    }

  @override
  void initState() {
    super.initState();
    holeCard1Controller = TextEditingController();
    holeCard2Controller = TextEditingController();
    communityCards1Controller = TextEditingController();
    communityCards2Controller = TextEditingController();
    communityCards3Controller = TextEditingController();
    communityCards4Controller = TextEditingController();
    communityCards5Controller = TextEditingController();
    numPlayersController = TextEditingController(text: '2');
    simulationsController = TextEditingController(text: '10000');
  }

  @override
  void dispose() {
    holeCard1Controller.dispose();
    holeCard2Controller.dispose();
    communityCards1Controller.dispose();
    communityCards2Controller.dispose();
    communityCards3Controller.dispose();
    communityCards4Controller.dispose();
    communityCards5Controller.dispose();
    numPlayersController.dispose();
    simulationsController.dispose();
    super.dispose();
  }

    Future<void> evaluate() async {
    setState(() {
      isLoading = true;
      resultMessage = '';
      resultValue = '';
    });

    try {
      final holeCards = [holeCard1Controller.text, holeCard2Controller.text]
          .where((c) => c.trim().isNotEmpty)
          .toList();

      if (holeCards.length != 2) {
        setState(() {
          resultMessage = 'Input Required';
          resultValue = 'Please enter exactly 2 hole cards (e.g. As, Kh)';
          isLoading = false;
        });
        return;
      }

      final community = [
        communityCards1Controller.text,
        communityCards2Controller.text,
        communityCards3Controller.text,
        communityCards4Controller.text,
        communityCards5Controller.text,
      ].where((c) => c.trim().isNotEmpty).toList();

      final response = await http.post(
        Uri.parse('$backendUrl/poker/evaluate'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'hole_cards': holeCards,
          'community_cards': community,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          resultMessage = 'Hand Ranked';
          resultValue = '${data['description']} (Rank: ${data['rank']})';
        });
      } else {
        setState(() {
          resultMessage = 'Error';
          resultValue = response.statusCode.toString();
        });
      }
    } catch (e) {
      setState(() {
        resultMessage = 'Request Failed';
        resultValue = e.toString();
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> monteCarlo() async {
    setState(() {
      isLoading = true;
      resultMessage = '';
      resultValue = '';
    });

    try {
      final holeCards = [holeCard1Controller.text, holeCard2Controller.text]
          .where((c) => c.trim().isNotEmpty)
          .toList();
      
      if (holeCards.length != 2) {
        setState(() {
          resultMessage = 'Input Required';
          resultValue = 'Please enter exactly 2 hole cards (e.g. As, Kh)';
          isLoading = false;
        });
        return;
      }

      final community = [
        communityCards1Controller.text,
        communityCards2Controller.text,
        communityCards3Controller.text,
        communityCards4Controller.text,
        communityCards5Controller.text,
      ].where((c) => c.trim().isNotEmpty).toList();

      final response = await http.post(
        Uri.parse('$backendUrl/poker/montecarlo'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'hole_cards': holeCards,
          'community_cards': community,
          'players': int.tryParse(numPlayersController.text) ?? 2,
          'simulations': int.tryParse(simulationsController.text) ?? 10000,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // Backend key is "win_probability", frontend was looking for "winProbability"
        final prob = ((data['win_probability'] ?? 0) * 100).toStringAsFixed(1);
        setState(() {
          resultMessage = 'Win Probability';
          resultValue = '$prob%';
        });
      } else {
        setState(() {
          resultMessage = 'Error';
          resultValue = response.statusCode.toString();
        });
      }
    } catch (e) {
      setState(() {
        resultMessage = 'Request Failed';
        resultValue = e.toString();
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Widget _buildCardInput(TextEditingController controller, String hint) {
    return Expanded(
      child: Center(
        child: Container(
          width: 60,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          child: TextField(
            controller: controller,
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(
                fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              hintText: hint,
              contentPadding: const EdgeInsets.symmetric(vertical: 20),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.casino, color: Color(0xFFE5B94E), size: 28),
            const SizedBox(width: 8),
            Text(
              'PRO POKER EVALUATOR',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
                fontSize: 20,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Hole Cards Section
              _buildSectionCard(
                title: 'HOLE CARDS',
                icon: Icons.style,
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildCardInput(holeCard1Controller, 'As'),
                        const SizedBox(width: 8),
                        _buildCardInput(holeCard2Controller, 'Kh'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Format: Ah, 10s, Kh, As',
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        color: Colors.white70,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Community Cards Section
              _buildSectionCard(
                title: 'COMMUNITY CARDS',
                icon: Icons.filter_none,
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildCardInput(communityCards1Controller, 'C1'),
                        _buildCardInput(communityCards2Controller, 'C2'),
                        _buildCardInput(communityCards3Controller, 'C3'),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildCardInput(communityCards4Controller, 'C4'),
                        _buildCardInput(communityCards5Controller, 'C5'),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Settings Section
              _buildSectionCard(
                title: 'SIMULATION SETTINGS',
                icon: Icons.settings_applications,
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: numPlayersController,
                        keyboardType: TextInputType.number,
                        style: GoogleFonts.dmSans(color: Colors.white, fontSize: 16),
                        decoration: const InputDecoration(
                          labelText: 'Players',
                          prefixIcon: Icon(Icons.people_alt, color: Colors.white54),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextField(
                        controller: simulationsController,
                        keyboardType: TextInputType.number,
                        style: GoogleFonts.dmSans(color: Colors.white, fontSize: 16),
                        decoration: const InputDecoration(
                          labelText: 'Simulations',
                          prefixIcon: Icon(Icons.science, color: Colors.white54),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: isLoading ? null : evaluate,
                      icon: const Icon(Icons.assessment),
                      label: const Text('EVALUATE'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1BA098),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: isLoading ? null : monteCarlo,
                      icon: const Icon(Icons.online_prediction),
                      label: const Text('MONTE CARLO'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Results Area
              if (isLoading)
                const Center(
                  child: CircularProgressIndicator(color: Color(0xFFE5B94E)),
                ),
              if (!isLoading && resultMessage.isNotEmpty)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFE5B94E), Color(0xFFD4AF37)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFE5B94E).withOpacity(0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Text(
                        resultMessage.toUpperCase(),
                        style: GoogleFonts.outfit(
                          color: const Color(0xFF0B132B),
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        resultValue,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(
                          color: const Color(0xFF0B132B),
                          fontWeight: FontWeight.w900,
                          fontSize: 28,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1C2541),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.05),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.white54, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: GoogleFonts.outfit(
                  color: Colors.white70,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}
