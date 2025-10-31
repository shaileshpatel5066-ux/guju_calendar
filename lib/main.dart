import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:table_calendar/table_calendar.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await Hive.initFlutter();
  await Hive.openBox('tasks');
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "Guju Calendar",
      theme: ThemeData(
        primarySwatch: Colors.orange,
        textTheme: GoogleFonts.poppinsTextTheme(),
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasData) {
          return const HomePage();
        }
        return const LoginPage();
      },
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  TextEditingController phoneController = TextEditingController();
  TextEditingController otpController = TextEditingController();
  String verificationId = "";
  bool codeSent = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Login")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: phoneController,
              decoration: const InputDecoration(
                labelText: "Mobile Number",
                prefix: Text("+91 "),
              ),
            ),
            const SizedBox(height: 10),
            if (codeSent)
              TextField(
                controller: otpController,
                decoration: const InputDecoration(labelText: "Enter OTP"),
              ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                if (!codeSent) {
                  await FirebaseAuth.instance.verifyPhoneNumber(
                    phoneNumber: "+91${phoneController.text}",
                    verificationCompleted: (phoneAuthCredential) {},
                    verificationFailed: (error) {
                      ScaffoldMessenger.of(context)
                          .showSnackBar(SnackBar(content: Text(error.toString())));
                    },
                    codeSent: (id, _) {
                      setState(() {
                        codeSent = true;
                        verificationId = id;
                      });
                    },
                    codeAutoRetrievalTimeout: (_) {},
                  );
                } else {
                  PhoneAuthCredential cred = PhoneAuthProvider.credential(
                      verificationId: verificationId,
                      smsCode: otpController.text);
                  await FirebaseAuth.instance.signInWithCredential(cred);
                }
              },
              child: Text(codeSent ? "Verify OTP" : "Send OTP"),
            ),
          ],
        ),
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  CalendarFormat _format = CalendarFormat.month;
  DateTime _selectedDay = DateTime.now();
  Box tasksBox = Hive.box('tasks');
  TextEditingController taskController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Guju Calendar"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => FirebaseAuth.instance.signOut(),
          )
        ],
      ),
      body: Column(
        children: [
          TableCalendar(
            focusedDay: _selectedDay,
            firstDay: DateTime.utc(2020),
            lastDay: DateTime.utc(2030),
            calendarFormat: _format,
            selectedDayPredicate: (day) => isSameDay(day, _selectedDay),
            onDaySelected: (selected, _) {
              setState(() {
                _selectedDay = selected;
              });
            },
          ),
          Expanded(
            child: ValueListenableBuilder(
              valueListenable: tasksBox.listenable(),
              builder: (context, box, _) {
                List tasks = box.get(_selectedDay.toString(), defaultValue: []);
                return ListView.builder(
                  itemCount: tasks.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      title: Text(tasks[index]),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () {
                          tasks.removeAt(index);
                          box.put(_selectedDay.toString(), tasks);
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: taskController,
                    decoration: const InputDecoration(
                      hintText: "Add task",
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () {
                    List tasks = tasksBox.get(_selectedDay.toString(), defaultValue: []);
                    tasks.add(taskController.text);
                    tasksBox.put(_selectedDay.toString(), tasks);
                    taskController.clear();
                  },
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}
