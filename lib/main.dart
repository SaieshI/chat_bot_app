import 'package:chat_bot_app/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Message Board App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class SplashScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    Future.delayed(Duration(seconds: 2), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => Authentication()),
      );
    });
    return Scaffold(
      body: Center(
        child: Text('Welcome to Chatbot App', style: TextStyle(fontSize: 24)),
      ),
    );
  }
}

class Authentication extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.hasData) return HomeScreen();
        return LoginScreen();
      },
    );
  }
}

class LoginScreen extends StatefulWidget {
  @override
  State<LoginScreen> createState() => LoginScreenState();
}

class LoginScreenState extends State<LoginScreen> {
  final email = TextEditingController();
  final password = TextEditingController();
  final loggedIn = true;
  final firstName = TextEditingController();
  final lastName = TextEditingController();

  Future<void> login() async {
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email.text.trim(),
        password: password.text.trim(),
      );
    } catch (e) {
      errorMessage(e.toString());
    }
  }

  Future<void> makeAccount() async {
    try {
      final userLogin = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: email.text.trim(),
            password: password.text.trim(),
          );
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userLogin.user!.uid)
          .set({
            'first_name': firstName.text.trim(),
            'last_name': lastName.text.trim(),
            'role': 'student',
            'registered_at': Timestamp.now(),
          });
    } catch (e) {
      errorMessage(e.toString());
    }
  }

  void errorMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context){
    return Scaffold(
      appBar: AppBar(title: Text(loggedIn ? 'Login' : 'Register')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (!loggedIn)
              TextField(controller: firstName, decoration: InputDecoration(labelText: 'First Name')),
            if (!loggedIn)
              TextField(controller: lastName, decoration: InputDecoration(labelText: 'Last Name')),
            TextField(controller: email, decoration: InputDecoration(labelText: 'E-Mail')),
            TextField(controller: password, decoration: InputDecoration(labelText: 'Password'), obscureText: true),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: loggedIn ? login : makeAccount,
              child: Text(loggedIn ? 'Login' : 'Register'),
            )
            TextButton(
              onPressed: () => setState(() => loggedIn = !loggedIn),
              child: Text(loggedIn ? 'No account? Register' : 'Have account? Login'),
            )
          ],
        ),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget{
  final boards = [
    {'name' : 'General', 'icon': Icons.forum},
    {'name' : 'Technology', 'icon': Icons.phone},
    {'name' : 'Games', 'icon' : Icons.gamepad},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Discussion Boards')),
      drawer: Drawer(
        child: ListView(
          children: [
            DrawerHeader(child: Text('Main Menu')), 
            ListTile(
              title: Text('Discussion Boards'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              title: Text('Profile'),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => UserProfile())),
            ),
            ListTile(
              title: Text('Settings'),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => UserSettings())),
            ),
          ],
        ),
      ),
      body: ListView.builder(
        itemCount: boards.length,
        itemBuilder: (context, index) {
          return ListTile(
            leading: Icon(boards[index]['icon'] as IconData),
            title: Text(boards[index]['name']!),
            onTap: () => Navigator.push(
              context, 
              MaterialPageRoute(builder: (_) => MessageScreen(boardName : boards[index]['name']!),),
              ),
          );
        },
      ),
    );
  }
}

class MessageScreen extends StatefulWidget{
  final String boardName;
  MessageScreen({required this.boardName});

  @override
  State<MessageScreen> createState() => MessageScreenState(); 
}

class MessageScreenState extends State<MessageScreen> {
  final message = TextEditingController();
  final user = FirebaseAuth.instance.currentUser!;
  late final String showUserName;

  @override
  void initState() {
    super.initState();
    FirebaseFirestore.instance.collection('users').doc(user.uid).get().then((doc) {
      showUserName = '${doc['first_name']} ${doc['last_name']}';
    });
  }

  void sendMessage() async{
    if (message.text.trim().isEmpty) return; 
    await FirebaseFirestore.instance.collection('message').add({
      'text' : message.text.trim(), 
      'timestap' : Timestamp.now(),
      'sender' : user.email, 
      'board' : widget.boardName,
    });
    message.clear();
  }

  @override
  Widget build(BuildContext context){
    return Scaffold(
      appBar: AppBar(title: Text(widget.boardName)),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder(
              stream: FirebaseFirestore.instance
                .collection('messages')
                .where('board', isEqualTo: widget.boardName)
                .orderBy('timestamp')
                .snapshots(), 
              builder: (context, snapshot) {
                if (!snapshot.hasData) return Center(child: CircularProgressIndicator());
                final docs = snapshot.data!.docs;
                return ListView(
                  children: docs
                      .map((doc) => ListTile(
                            title: Text(doc['text']),
                            subtitle: Text('${doc['sender']} - ${doc['timestamp'].toDate()}'),
                          ))
                      .toList(),
                );
              },
            ),
          ),
          Row(
            children: [
              Expanded(child: TextField(controller: message, decoration: InputDecoration(hintText: 'Enter Message'))),
              IconButton(icon: Icon(Icons.send), onPressed: sendMessage),
            ],
          )
        ],
      ),
    );
  }
}

class UserProfile extends StatefulWidget{
  final user = FirebaseAuth.instance.currentUser!; 
  @override
  Widget build(BuildContext context){
    return Scaffold(
      appBar: AppBar(title: Text('Profile')),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('users').doc(user.uid).get(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return CircularProgressIndicator();
          final data = snapshot.data!;
          return ListTile(
            title: Text('${data['first_name']} ${data['last_name']}'),
            subtitle: Text('Email: ${user.email}'),
          );
        },
      ),
    );
  }
}

class UserSettings extends StatelessWidget{
  void logout(BuildContext context) async{
    await FirebaseAuth.instance.signOut(); 
    Navigator.pushAndRemoveUntil(
      context, MaterialPageRoute(builder: (_) => LoginScreen()), (route) => false
    );
  }

  @override
  Widget build(BuildContext context){
    return Scaffold(
      appBar: AppBar(title: Text('Settings')),
      body: ListTile(
        title: Text('Logout'),
        onTap: () => logout(context),
      ),
    );
  }
}
