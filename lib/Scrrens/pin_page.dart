import 'package:datavault/Scrrens/Stoarge.dart';
import 'package:datavault/Scrrens/home.dart';
import 'package:datavault/Scrrens/send_message.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';

final logger = Logger();

class PinCheckPage extends StatefulWidget {
  const PinCheckPage({super.key});

  @override
  _PinCheckPageState createState() => _PinCheckPageState();
}

class _PinCheckPageState extends State<PinCheckPage> {
  String? savedPin;

  @override
  void initState() {
    super.initState();
    _loadSavedPin();
  }

  Future<void> _loadSavedPin() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      savedPin = prefs.getString('userPin');
    });
  }

  @override
  Widget build(BuildContext context) {
    return savedPin == null ? SetPinPage() : EnterPinPage(savedPin: savedPin!);
  }
}

class SetPinPage extends StatefulWidget {
  const SetPinPage({super.key});

  @override
  SetPinPageState createState() => SetPinPageState();
}

class SetPinPageState extends State<SetPinPage> {
  String currentPin = "";

  Future<void> _savePin() async {
    if (currentPin.length == 4) {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('userPin', currentPin);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('PIN Set Successfully!')));
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => EnterPinPage(savedPin: currentPin),
        ),
      );
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Please enter a 4-digit PIN')));
    }
  }

  void _onKeyPressed(String key) {
    setState(() {
      if (key == 'back') {
        if (currentPin.isNotEmpty) {
          currentPin = currentPin.substring(0, currentPin.length - 1);
        }
      } else {
        if (currentPin.length < 4) currentPin += key;
      }
    });
    if (currentPin.length == 4) _savePin();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Set Your PIN'),
        backgroundColor: Colors.blueGrey[600],
      ),
      backgroundColor: Colors.grey[300],
      body: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          PinCircles(pinLength: currentPin.length),
          Keypad(onKeyPressed: _onKeyPressed),
        ],
      ),
    );
  }
}

class EnterPinPage extends StatefulWidget {
  final String savedPin;
  const EnterPinPage({super.key, required this.savedPin});

  @override
  EnterPinPageState createState() => EnterPinPageState();
}

class EnterPinPageState extends State<EnterPinPage> {
  String enteredPin = "";
  final LocalAuthentication auth = LocalAuthentication();
  // bool _isAuthenticating = false;

  @override
  void initState() {
    super.initState();
    _authenticate(); // Call biometric on start (optional)
  }

  Future<void> _authenticate() async {
    bool authenticated = false;
    try {
      authenticated = await auth.authenticate(
        localizedReason: 'Use fingerprint to unlock',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
    } catch (e) {
      logger.e("Biometric auth error", error: e); // ✅ Logging instead of print
    }
    if (!mounted) return;
    if (authenticated) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => Home()),
      );
    }
  }

  void _onKeyPressed(String key) {
    setState(() {
      if (key == 'back') {
        if (enteredPin.isNotEmpty) {
          enteredPin = enteredPin.substring(0, enteredPin.length - 1);
        }
      } else {
        if (enteredPin.length < 4) enteredPin += key;
      }
    });
    if (enteredPin.length == 4) _checkPin();
  }

  void _checkPin() {
    if (enteredPin == widget.savedPin) {
      ScaffoldMessenger.of(context);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => Home()),
      );
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Incorrect PIN!')));
      setState(() {
        enteredPin = "";
      });
    }
  }

  Future<void> _resetPin() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('userPin');
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => SetPinPage()),
    );
  }

  void _showResetDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text("Reset PIN"),
            content: Text("Are you sure you want to reset your PIN?"),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text("Cancel"),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _resetPin();
                },
                child: Text("Reset"),
              ),
            ],
          ),
    );
  }

  Widget _buildForgotPin() {
    return TextButton(
      onPressed: _showResetDialog,
      child: Text(
        "Forgot PIN?",
        style: TextStyle(color: Color.fromARGB(255, 44, 156, 200)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Enter Your PIN'),
        backgroundColor: Colors.blueGrey[600],
      ),
      backgroundColor: Colors.grey[300],
      body: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          PinCircles(pinLength: enteredPin.length),
          Keypad(onKeyPressed: _onKeyPressed),

          // 👇 Add this IconButton here
          IconButton(
            icon: Icon(
              Icons.fingerprint,
              size: 40,
              color: Colors.blueGrey[600],
            ),
            onPressed: _authenticate,
          ),

          _buildForgotPin(),
        ],
      ),
    );
  }
}

class PinCircles extends StatelessWidget {
  final int pinLength;
  const PinCircles({super.key, required this.pinLength});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        4,
        (i) => Container(
          margin: EdgeInsets.symmetric(horizontal: 8),
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color:
                i < pinLength
                    ? Colors.blueGrey[600]
                    : const Color.fromARGB(255, 199, 199, 199),
          ),
        ),
      ),
    );
  }
}

class Keypad extends StatelessWidget {
  final Function(String) onKeyPressed;
  const Keypad({super.key, required this.onKeyPressed});

  Widget _buildKeypadButton(String text) {
    return InkWell(
      onTap: () => onKeyPressed(text),
      borderRadius: BorderRadius.circular(50),
      child: Container(
        alignment: Alignment.center,
        width: 70,
        height: 70,
        child:
            text == 'back'
                ? Icon(Icons.backspace, size: 30)
                : Text(
                  text,
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var row in [
          ["1", "2", "3"],
          ["4", "5", "6"],
          ["7", "8", "9"],
          ["", "0", "back"],
        ])
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children:
                row.map((text) {
                  if (text.isEmpty) return SizedBox(width: 70, height: 70);
                  return _buildKeypadButton(text);
                }).toList(),
          ),
      ],
    );
  }
}
