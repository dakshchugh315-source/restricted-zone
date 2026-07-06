import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart'; // <-- NAYA IMPORT

// Enum ko replace kar de isse:
enum RewardAction { oneLife, threeLives, threeHints }

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await MobileAds.instance.initialize();
  runApp(const MeowdokuApp());
}

class MeowdokuApp extends StatelessWidget {
  const MeowdokuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Cameloku 🐫',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.amber),
      ),
      home: const GameBoard(),
    );
  }
}

class GameLevel {
  final int size;
  final List<List<int>> regions;
  final List<List<bool>> solution;
  GameLevel(this.size, this.regions, this.solution);
}

class GameBoard extends StatefulWidget {
  const GameBoard({super.key});
  @override
  State<GameBoard> createState() => _GameBoardState();
}

class _GameBoardState extends State<GameBoard> {
  int lives = 3;
  bool gameOver = false;
  int currentLevelIndex = 0;
  bool isLoading = true;
  int diamonds = 0;
  int hints = 3;
  // Multi-ad feature progress track karne ke liye
  int multiAdProgress = 0; 

  List<GameLevel> levels = [];
  late List<List<int>> playerState;

  BannerAd? _bannerAd;
  final AudioPlayer _camelSoundPlayer = AudioPlayer();
  final AudioPlayer _loseHeartPlayer = AudioPlayer();
  final AudioPlayer _levelUpPlayer = AudioPlayer();
  bool _isBannerAdLoaded = false;
  RewardedAd? _rewardedAd;
  InterstitialAd? _interstitialAd;

  String tutorialMessage =
      "Welcome! 🐫 Tap any empty box to place your first camel.";
  int tutorialStep = 0; 
  Set<String> highlightedCells = {};

  final List<Color> regionColors = [
    Colors.blue.shade200,
    Colors.green.shade200,
    Colors.orange.shade200,
    Colors.purple.shade200,
    Colors.pink.shade200,
    Colors.teal.shade200,
    Colors.red.shade200,
  ];

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    await _loadGameData(); 
    await _loadLevelsData(); 
    _loadBannerAd();
    _loadRewardedAd();
    _loadInterstitialAd();
  }

  void _useHint() {
    if (gameOver || isLoading) return;

    if (hints > 0) {
      int n = levels[currentLevelIndex].size;
      for (int r = 0; r < n; r++) {
        for (int c = 0; c < n; c++) {
          if (levels[currentLevelIndex].solution[r][c] && playerState[r][c] != 1) {
            setState(() {
              playerState[r][c] = 1; // Camel place kar diya
              hints--;
            });
            _playCamelSound();
            _saveGameData();
            _checkWinCondition();
            return;
          }
        }
      }
    } else {
      _showNeedHintsDialog();
    }
  }

  void _showNeedHintsDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Out of Hints! 💡", style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text("Watch a quick ad to get 3 more hints?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _triggerRewardedAd(RewardAction.threeHints);
            },
            child: const Text("Watch Ad (+3 Hints)"),
          ),
        ],
      ),
    );
  }

  Future<void> _loadGameData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      currentLevelIndex = prefs.getInt('saved_level') ?? 0;
      diamonds = prefs.getInt('saved_diamonds') ?? 0;
      hints = prefs.getInt('saved_hints') ?? 3;
    });
  }

  Future<void> _saveGameData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('saved_level', currentLevelIndex);
    await prefs.setInt('saved_diamonds', diamonds);
    await prefs.setInt('saved_hints', hints);
  }

  void _loadBannerAd() {
    _bannerAd = BannerAd(
      adUnitId: 'ca-app-pub-3940256099942544/6300978111', // TEST ID
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          setState(() {
            _isBannerAdLoaded = true;
          });
        },
        onAdFailedToLoad: (ad, err) {
          ad.dispose();
        },
      ),
    )..load();
  }

  void _loadRewardedAd() {
    RewardedAd.load(
      adUnitId: 'ca-app-pub-3940256099942544/5224354917', // TEST ID
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
        },
        onAdFailedToLoad: (err) {},
      ),
    );
  }

  void _loadInterstitialAd() {
    InterstitialAd.load(
      adUnitId: 'ca-app-pub-3940256099942544/1033173712', // TEST ID
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
        },
        onAdFailedToLoad: (err) {
          print('Interstitial Failed: ${err.message}');
        },
      ),
    );
  }

  // Rewarded Ad Trigger for Glossy Buttons
  void _triggerRewardedAd(RewardAction action) {
    if (_rewardedAd != null) {
      _rewardedAd!.show(
        onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
          setState(() {
            if (action == RewardAction.oneLife) {
              lives = 1;
            } else if (action == RewardAction.threeLives) {
              lives = 3;
            } else if (action == RewardAction.threeHints) { 
              hints += 3;
              _saveGameData();
            } 
            gameOver = false;
          });
        },
      );
      _rewardedAd = null;
      _loadRewardedAd();
    } else {
      // Ad fail/not loaded fallback
      setState(() {
        lives = (action == RewardAction.threeLives) ? 3 : 1;
        gameOver = false;
      });
      _loadRewardedAd();
    }
  }

  void _goToNextLevelWithAdCheck() {
    if ((currentLevelIndex + 1) % 3 == 0 && _interstitialAd != null) {
      _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          _loadInterstitialAd();
          _startNextLevel();
        },
        onAdFailedToShowFullScreenContent: (ad, err) {
          ad.dispose();
          _loadInterstitialAd();
          _startNextLevel();
        },
      );
      _interstitialAd!.show();
    } else {
      _startNextLevel();
    }
  }

  void _startNextLevel() {
    setState(() {
      currentLevelIndex++;
      _saveGameData(); 
      _loadLevel();
    });
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    _rewardedAd?.dispose();
    _interstitialAd?.dispose();
    _camelSoundPlayer.dispose(); // <-- YAHAN SE ADD
    _loseHeartPlayer.dispose();
    _levelUpPlayer.dispose();
    super.dispose();
  }

  Future<void> _loadLevelsData() async {
    try {
      final String jsonString = await rootBundle.loadString(
        'assets/levels.json',
      );
      final List<dynamic> jsonResponse = json.decode(jsonString);
      setState(() {
        levels = jsonResponse.map((level) {
          return GameLevel(
            level['size'] as int,
            (level['regions'] as List)
                .map((row) => List<int>.from(row))
                .toList(),
            (level['solution'] as List)
                .map((row) => List<bool>.from(row))
                .toList(),
          );
        }).toList();
        isLoading = false;
        _loadLevel();
      });
    } catch (e) {
      print("Error loading JSON: $e");
    }
  }

  void _loadLevel() {
    if (levels.isEmpty) return;
    int n = levels[currentLevelIndex].size;
    setState(() {
      // 0: Empty, 1: Camel Placed, 2: Cross/Selected, 3: Failed/Locked
      playerState = List.generate(n, (_) => List.filled(n, 0));
      lives = 3;
      gameOver = false;
      multiAdProgress = 0;
      highlightedCells.clear();
      tutorialStep = 0;
      if (currentLevelIndex == 0) {
        tutorialMessage =
            "Welcome! 🐫 Tap any empty box to place your first camel.";
      }
    });
  }

  int _countPlacedCamels() {
    int count = 0;
    for (var row in playerState) {
      for (var cell in row) {
        if (cell == 1) count++;
      }
    }
    return count;
  }

  void _playCamelSound() async {
    await _camelSoundPlayer.play(AssetSource('camel_sound.mp3'));
  }

  void _playLoseHeartSound() async {
    await _loseHeartPlayer.play(AssetSource('lose_heart.mp3'));
  }

  void _playLevelUpSound() async {
    await _levelUpPlayer.play(AssetSource('level_up.mp3'));
  }

  void _highlightRowAndCol(int r, int c) {
    highlightedCells.clear();
    int n = levels[currentLevelIndex].size;
    for (int i = 0; i < n; i++) {
      highlightedCells.add("$r,$i"); 
      highlightedCells.add("$i,$c"); 
    }
  }

  void _highlightAdjacent(int r, int c) {
    highlightedCells.clear();
    for (int i = -1; i <= 1; i++) {
      for (int j = -1; j <= 1; j++) {
        highlightedCells.add("${r + i},${c + j}");
      }
    }
  }

  void _highlightRegion(int r, int c) {
    highlightedCells.clear();
    int regionId = levels[currentLevelIndex].regions[r][c];
    int n = levels[currentLevelIndex].size;
    for (int i = 0; i < n; i++) {
      for (int j = 0; j < n; j++) {
        if (levels[currentLevelIndex].regions[i][j] == regionId) {
          highlightedCells.add("$i,$j");
        }
      }
    }
  }

  // NAYA: Long press handle karne ke liye function
  void _handleLongPress(int row, int col) {
    if (gameOver || isLoading) return;

    // Sirf unlocked cells par hi long press kaam karega
    if (playerState[row][col] == 1 || playerState[row][col] == 3) {
      return; 
    }

    setState(() {
      if (playerState[row][col] == 2) {
        // Agar pehle se cross tha, toh clear kar do (wapas 0)
        playerState[row][col] = 0;
      } else if (playerState[row][col] == 0) {
        // Shortcut: Agar direct empty box pe hold kiya toh cross lag jayega
        playerState[row][col] = 2;
      }
    });
  }

  void _handleTap(int row, int col) {
    if (gameOver || isLoading) return;

    // LOCKING LOGIC. Agar block mein sahi camel aa gaya (1) ya heart chala gaya (3), usko disable karo
    if (playerState[row][col] == 1 || playerState[row][col] == 3) {
      if (currentLevelIndex == 0 && playerState[row][col] == 1) {
        setState(() {
          tutorialMessage = "You already found this one! Look for the remaining camels.";
        });
      }
      return; 
    }

    setState(() {
      // -----------------------------------------
      // NORMAL GAME LOGIC (Levels 1 and onwards)
      // -----------------------------------------
      if (currentLevelIndex > 0) {
        if (playerState[row][col] == 0) {
          playerState[row][col] = 2; // Cross
        } else if (playerState[row][col] == 2) {
          if (levels[currentLevelIndex].solution[row][col]) {
            playerState[row][col] = 1; 
            // Camel placed
            _playCamelSound();
            _checkWinCondition();
          } else {
            lives--;
            _playLoseHeartSound();
            playerState[row][col] = 3; 
            // 3 set kiya taaki lock/fade ho jaye
            if (lives <= 0) {
              gameOver = true;
              _showGameOverDialog();
            }
          }
        }
        return; 
      }

      if (playerState[row][col] == 0) {
        playerState[row][col] = 2; // Cross

        if (tutorialStep == 0) {
          tutorialStep = 1;
          tutorialMessage = "Good! '❌' means you marked it empty.\nNow tap it AGAIN if you think a Camel belongs here! 🐫";
        }
      } 
      else if (playerState[row][col] == 2) {
        if (levels[currentLevelIndex].solution[row][col]) {
          playerState[row][col] = 1; // Camel placed
          _playCamelSound();

          int total = _countPlacedCamels();

          if (total == 1) {
            tutorialStep = 2;
            tutorialMessage = "Yay! 🎉 Rule 1: ONE camel per Row & Column.\nSee the highlighted blocks? You can't place camels there. Find the next one!";
            _highlightRowAndCol(row, col);
          } 
          else if (total == 2) {
            tutorialStep = 3;
            tutorialMessage = "Great! 🛑 Rule 2: Camels CANNOT touch each other, not even diagonally! Find the 3rd camel.";
            _highlightAdjacent(row, col);
          } 
          else if (total == 3) {
            tutorialStep = 4;
            tutorialMessage = "Rule 3: Only 1 camel per Color! 🎨 Find the last one!";
            _highlightRegion(row, col);
          } 
          else {
            tutorialStep = 5;
            tutorialMessage = "Perfect! All rules cleared. Now the real game begins! 🚀";
            highlightedCells.clear();
            Future.delayed(const Duration(seconds: 2), () {
              if (mounted) _goToNextLevelWithAdCheck();
            });
          }
          
          _checkWinCondition(); 
        } else {
          tutorialMessage = "Oops! ❌ No camel here. Choose another block!";
          // Tutorial mein lives nahi kaat rahe, bas usko reset kar rahe taaki sikh sake
          playerState[row][col] = 0; 
        }
      } 
    });
  }

  void _checkWinCondition() {
    int n = levels[currentLevelIndex].size;
    int camelsPlaced = _countPlacedCamels();

    if (camelsPlaced == n) {
      gameOver = true;
      _playLevelUpSound();
      setState(() {
        diamonds += 7;
      });
      _saveGameData(); 

      if (currentLevelIndex < levels.length - 1) {
        _showLevelClearedDialog();
      } else {
        _showGameCompletedDialog();
      }
    }
  }

  void _showLevelClearedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Level Cleared! 🎉", style: TextStyle(fontWeight: FontWeight.bold)),
          content: const Text("You earned 7 💎! Ready for the next one?", style: TextStyle(fontSize: 16)),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _goToNextLevelWithAdCheck();
              },
              child: const Text("Next Level ➡️"),
            ),
          ],
        );
      },
    );
  }

  void _showGameCompletedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Center(
            child: Text("Oasis Reached! 🌴🏆", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24))
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Incredible! You've mastered the desert and completed all levels! 🐫👑", 
                textAlign: TextAlign.center, 
                style: TextStyle(fontSize: 16)
              ),
              SizedBox(height: 12),
              Text("Reward: 7 💎 added!", 
                textAlign: TextAlign.center, 
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue)
              ),
            ],
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12)
              ),
              onPressed: () {
                Navigator.of(context).pop();
                setState(() {
                  currentLevelIndex = 0;
                  _saveGameData();
                  _loadLevel();
                });
              },
              child: const Text("Play Again 🔄", style: TextStyle(fontSize: 18, color: Colors.black87, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _showGameOverDialog() {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.8), 
      // Dark overlay
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 6.0, sigmaY: 6.0), 
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Out of Hearts",
                    style: TextStyle(
                      fontSize: 42,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      shadows: [
                        Shadow(color: Colors.lightBlue.shade200, blurRadius: 20) 
                      ]
                    ),
                  ),
                  const SizedBox(height: 30),
                  
                  Image.asset('assets/robot.png', height: 280,
                    errorBuilder: (context, error, stackTrace) => const Icon(Icons.smart_toy, size: 150, color: Colors.white),
                  ), 
                  
                  const SizedBox(height: 20),
                  
                  const Text(
                    "💔 Hearts Remaining: 0",
                    style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  
                  const Text(
                    "The heart has shattered. Try to\nrebuild it.",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.white70),
                  ),
                  const SizedBox(height: 30),

                  if (multiAdProgress == 0)
                    _buildGlossyButton(
                      text: "REBUILD (+1 Life)",
                      icon: Icons.play_arrow_rounded,
                      onPressed: () {
                        Navigator.pop(context);
                        _triggerRewardedAd(RewardAction.oneLife);
                      }
                    ),
                  
                  if (multiAdProgress > 0)
                    _buildGlossyButton(
                      text: "REBUILD (+3 Lives) ▶️",
                      icon: Icons.play_arrow_rounded,
                      onPressed: () {
                        Navigator.pop(context);
                        _triggerRewardedAd(RewardAction.threeLives);
                      }
                    ),
                  
                  const SizedBox(height: 12),

                  if (multiAdProgress == 0)
                    _buildGlossyButton(
                      text: "SUPER REBUILD (+3 Lives) 🎁",
                      icon: Icons.ondemand_video_rounded,
                      color: Colors.purple.shade400,
                      onPressed: () {
                        Navigator.pop(context);
                        _triggerRewardedAd(RewardAction.threeLives);
                      }
                    ),
                    
                  const SizedBox(height: 12),

                  if (diamonds >= 20)
                    _buildGlossyButton(
                      text: "PAY 20💎 TO REBUILD",
                      icon: Icons.diamond_rounded,
                      color: Colors.teal.shade400,
                      onPressed: () {
                        Navigator.pop(context);
                        setState(() { diamonds -= 20; lives = 1; gameOver = false; });
                        _saveGameData();
                      }
                    ),

                  const SizedBox(height: 20),

                  // Puraana TextButton delete kar ke ye daal de:
                  _buildGlossyButton(
                    text: "RESTART LEVEL 🔄",
                    icon: Icons.refresh,
                    color: Colors.grey.shade600,
                    onPressed: () {
                      Navigator.pop(context);
                      _loadLevel();
                    }
                  ),
                ],
              ),
            ),
          ),
        );
      }
    );
  }

  Widget _buildGlossyButton({required String text, required IconData icon, required VoidCallback onPressed, Color? color}) {
    Color baseColor = color ?? Colors.blue.shade400;
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 300,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [baseColor.withOpacity(0.6), baseColor],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.circular(30), 
          border: Border.all(color: Colors.white.withOpacity(0.9), width: 1.5),
          boxShadow: [
            BoxShadow(color: baseColor.withOpacity(0.5), blurRadius: 12, spreadRadius: 2) 
          ]
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 8),
            Text(
              text, 
              style: const TextStyle(
                fontSize: 18, 
                fontWeight: FontWeight.bold, 
                color: Colors.white, 
                shadows: [Shadow(color: Colors.black45, blurRadius: 3)] 
              )
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRuleCard(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13, 
          // Thoda chota kiya taaki 6 cards fit ho sake
          color: Colors.grey.shade800,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Colors.amber)),
      );
    }

    int n = levels[currentLevelIndex].size;
    var currentLevelData = levels[currentLevelIndex];

    return Container(
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/desert.jpg'),
          fit: BoxFit.cover,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(
            'Level ${currentLevelIndex + 1}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          backgroundColor: Colors.amber.shade400.withOpacity(0.85),
          elevation: 0,
          actions: [
            // <-- HINT BUTTON YAHAN AAYEGA
            TextButton.icon(
              onPressed: _useHint,
              icon: const Icon(Icons.lightbulb, color: Colors.white, size: 28),
              label: Text(
                '$hints',
                style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Text(
                  '💎 $diamonds',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadLevelsData,
            ),
          ],
        ),
        body: Column(
          children: [
            if (currentLevelIndex == 0)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.all(12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade400, width: 2),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.school, color: Colors.blue, size: 30),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        tutorialMessage,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // NAYA SPACING: App bar aur rules ke beech gap bada diya
            const SizedBox(height: 16), 

            if (currentLevelIndex != 0)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    _buildRuleCard("🎨 Only 1 Camel per Color"),
                    _buildRuleCard("📏 Only 1 per Row & Column"),
                    _buildRuleCard("🛑 Camels can't touch (Even Diagonally)"),
                  ],
                ),
              ),

            // Grid aur rules ke beech ka gap
            const SizedBox(height: 16),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, (index) {
                return Icon(
                  index < lives ? Icons.favorite : Icons.favorite_border,
                  color: Colors.red,
                  size: 42,
                );
              }),
            ),

            const SizedBox(height: 16),

            // YAHAN MAIN GRID VIEW LOGIC HAI JISME HIGHLIGHT, FADE AUR LONG PRESS INTEGRATED HAI
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6.0),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: GridView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: n,
                        crossAxisSpacing: 3,
                        mainAxisSpacing: 3,
                      ),
                      itemCount: n * n,
                      itemBuilder: (context, index) {
                        int row = index ~/ n;
                        int col = index % n;
                        int regionId = currentLevelData.regions[row][col];
                        int cellState = playerState[row][col];

                        bool isHighlighted = highlightedCells.contains("$row,$col");
                        
                        double cellOpacity = 0.85;
                        Color borderColor = Colors.black45;
                        double borderWidth = 1.0;

                        if (isHighlighted) {
                          borderColor = Colors.redAccent;
                          borderWidth = 3.5;
                          cellOpacity = 0.4;
                        } 
                        else if (cellState == 3) {
                          cellOpacity = 0.4; // Faded
                        }
                        else if (cellState == 1) {
                          cellOpacity = 1.0; 
                        }

                        String cellContent = '';
                        if (cellState == 1) cellContent = '🐫';
                        if (cellState == 2) cellContent = '❌';
                        if (cellState == 3) cellContent = '💔'; 

                        return GestureDetector(
                          onTap: () => _handleTap(row, col),
                          // NAYA: Long press yahan bind kar diya
                          onLongPress: () => _handleLongPress(row, col),
                          child: Container(
                            decoration: BoxDecoration(
                              color: regionColors[regionId].withOpacity(cellOpacity),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: borderColor,
                                width: borderWidth,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                cellContent,
                                style: const TextStyle(fontSize: 34),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
            // --- NEECHE WALE CONTROLS ---
            const SizedBox(height: 16), 
            // Grid aur controls ke beech ka gap
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Wrap(
                spacing: 6,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  _buildRuleCard("👆 1st Tap: Mark Empty ❌"),
                  _buildRuleCard("🐫 2nd Tap: Place Camel"),
                  _buildRuleCard("⏱️ Long press: Clear Box"),
                ],
              ),
            ),
            const SizedBox(height: 16), 
            // Controls aur Ad ke beech ka gap
            
            if (_isBannerAdLoaded)
              SizedBox(
                height: _bannerAd!.size.height.toDouble(),
                width: _bannerAd!.size.width.toDouble(),
                child: AdWidget(ad: _bannerAd!),
              )
            else
              const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }
}