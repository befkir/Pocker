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
  final TextEditingController numPlayersController = TextEditingController(text: '2');
  final TextEditingController simulationsController = TextEditingController(text: '10000');

  String resultMessage = '';
  String resultValue = '';
  bool isLoading = false;

  List<String?> holeCards = [null, null];
  List<String?> communityCards = [null, null, null, null, null];
  
  final List<String> suits = ['H', 'D', 'C', 'S'];
  final List<String> ranks = ['2', '3', '4', '5', '6', '7', '8', '9', 'T', 'J', 'Q', 'K', 'A'];

  @override
  void dispose() {
    numPlayersController.dispose();
    simulationsController.dispose();
    super.dispose();
  }

  String get backendUrl {
    final host = Uri.base.host;
    if (host.isEmpty || host == 'localhost' || host == '127.0.0.1') {
      return 'http://localhost:8080';
    }
    return Uri.base.origin;
  }

  void _openCardPicker(int index, bool isHoleCard) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'SELECT CARD',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 6,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 0.7,
                  ),
                  itemCount: 52,
                  itemBuilder: (context, i) {
                    final suit = suits[i ~/ 13];
                    final rank = ranks[i % 13];
                    final card = '$rank$suit'; // Changed to RankSuit format
                    
                    // Check if already selected
                    final isSelected = holeCards.contains(card) || communityCards.contains(card);
                    
                    return InkWell(
                      onTap: isSelected ? null : () {
                        setState(() {
                          if (isHoleCard) {
                            holeCards[index] = card;
                          } else {
                            communityCards[index] = card;
                          }
                        });
                        Navigator.pop(context);
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.white10 : const Color(0xFF16213E),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected ? Colors.transparent : Colors.white24,
                          ),
                        ),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                rank == 'T' ? '10' : rank,
                                style: GoogleFonts.dmSans(
                                  color: isSelected ? Colors.white24 : _getSuitColor(suit),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              _getSuitIcon(suit, isSelected ? Colors.white24 : _getSuitColor(suit)),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  setState(() {
                    if (isHoleCard) {
                      holeCards[index] = null;
                    } else {
                      communityCards[index] = null;
                    }
                  });
                  Navigator.pop(context);
                },
                child: Text('CLEAR SLOT', style: GoogleFonts.dmSans(color: Colors.redAccent)),
              ),
            ],
          ),
        );
      },
    );
  }

  Color _getSuitColor(String suit) {
    if (suit == 'H' || suit == 'D') return Colors.redAccent;
    return Colors.white70;
  }

  Widget _getSuitIcon(String suit, Color color) {
    IconData icon;
    switch (suit) {
      case 'H': icon = Icons.favorite; break;
      case 'D': icon = Icons.diamond; break;
      case 'C': icon = Icons.auto_awesome_mosaic; break; // Placeholder for Club
      case 'S': icon = Icons.spa; break; // Placeholder for Spade
      default: icon = Icons.help;
    }
    return Icon(icon, color: color, size: 14);
  }

    Future<void> evaluate() async {
    setState(() {
      isLoading = true;
      resultMessage = '';
      resultValue = '';
    });

    try {
      final selectedHole = holeCards.whereType<String>().toList();
      if (selectedHole.length != 2) {
        setState(() {
          resultMessage = 'Input Required';
          resultValue = 'Please select exactly 2 hole cards.';
          isLoading = false;
        });
        return;
      }

      final selectedCommunity = communityCards.whereType<String>().toList();

      final response = await http.post(
        Uri.parse('$backendUrl/poker/evaluate'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'hole_cards': selectedHole,
          'community_cards': selectedCommunity,
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
      final selectedHole = holeCards.whereType<String>().toList();
      if (selectedHole.length != 2) {
        setState(() {
          resultMessage = 'Input Required';
          resultValue = 'Please select exactly 2 hole cards.';
          isLoading = false;
        });
        return;
      }

      final selectedCommunity = communityCards.whereType<String>().toList();

      final response = await http.post(
        Uri.parse('$backendUrl/poker/montecarlo'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'hole_cards': selectedHole,
          'community_cards': selectedCommunity,
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

    Widget _buildCardSlot(int index, bool isHoleCard) {
    final card = isHoleCard ? holeCards[index] : communityCards[index];
    final hasCard = card != null;
    final suit = hasCard ? card.substring(card.length - 1) : '';
    final rank = hasCard ? card.substring(0, card.length - 1) : '';

    return GestureDetector(
      onTap: () => _openCardPicker(index, isHoleCard),
      child: Container(
        width: 60,
        height: 80,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: hasCard ? const Color(0xFF16213E) : Colors.white10,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasCard ? _getSuitColor(suit).withOpacity(0.5) : Colors.white24,
            width: 2,
          ),
        ),
        child: Center(
          child: hasCard
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      rank == 'T' ? '10' : rank,
                      style: GoogleFonts.dmSans(
                        color: _getSuitColor(suit),
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                    _getSuitIcon(suit, _getSuitColor(suit)),
                  ],
                )
              : const Icon(Icons.add, color: Colors.white24, size: 24),
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
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildCardSlot(0, true),
                    const SizedBox(width: 8),
                    _buildCardSlot(1, true),
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
                        _buildCardSlot(0, false),
                        _buildCardSlot(1, false),
                        _buildCardSlot(2, false),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildCardSlot(3, false),
                        _buildCardSlot(4, false),
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
