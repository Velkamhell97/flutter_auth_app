import 'package:flutter/material.dart';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';


class User {
  final String name;
  final String? picture;
  final String email;

  const User({required this.name, required this.picture, required this.email});

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      name: json["name"],
      picture: json["picture"],
      email: json["email"]
    );
  }
}

class AuthPage extends StatefulWidget {
  const AuthPage({Key? key}) : super(key: key);

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      'email',
      // 'https://www.googleapis.com/auth/contacts.readonly',
    ],
  );

  final List<AppleIDAuthorizationScopes> _appleScopes = [
    AppleIDAuthorizationScopes.email,
    AppleIDAuthorizationScopes.fullName
  ];

  static const _appleClientId = "CLIENT_ID";
  //-recordar porner el de heroku
  static const _appleReturnUrl = "http://192.168.0.112:8080/api/auth/apple-callback";

  GoogleSignInAccount? _currentUser;
  User? _user;
  bool _loading = true;

  final dio = Dio(BaseOptions(contentType: 'application/x-www-form-urlencoded'));

  @override
  void initState() {
    super.initState();

    _googleSignIn.onCurrentUserChanged.listen((account) {
      setState(() {
        _currentUser = account;
      });
    });

    WidgetsBinding.instance!.addPostFrameCallback((_) async { 
      final googleUser = await _googleSignIn.signInSilently();

      if(googleUser != null) {
        setState(() {
          _user = User(
            name: googleUser.displayName!,
            picture: googleUser.photoUrl!, 
            email: googleUser.email
          );
        });
      }

      setState(() => _loading = false);
    });
    //Intenta logearse con un usuario previamente autenticado (como una persistencia)
  }

  Future<User> _authenticateGoogle(String token) async {
    const endpoint = 'http://192.168.0.112:8080/api/auth/google-signin';

    final resp = await dio.post(endpoint, data: {'idToken':token });
    final user = User.fromJson(resp.data);

    return user;
  }

  Future<User> _authenticateApple(AuthorizationCredentialAppleID  credentials) async {
    //-recordar que tiene que ser el de heroku para apple
    const endpoint = 'http://192.168.0.112:8080/api/auth/apple-signin';

    final resp = await Dio().post(endpoint, 
      queryParameters: {
        'code': credentials.authorizationCode,
        'firstName': credentials.givenName, 
        'lastName': credentials.familyName,
        'useBundleId': Platform.isIOS ? 'true' : 'false',
        // 'state': credentials.state ?? 'null'
      },
    );
    final user = User.fromJson(resp.data);

    return user;
  }

  Future<void> _signinGoogle() async {
    try {
      setState(() => _loading = true);
      final googleUser = await _googleSignIn.signIn();

      if(googleUser != null){
        final googleKey = await googleUser.authentication;
        final user = await _authenticateGoogle(googleKey.idToken!);

        setState(() {
          _user = user;
          _loading = false;
        });
      }
    } catch (error) {
      _googleSignIn.signOut();
      print(error);
    }
  }

  Future<void> _signinApple() async {
    try {
      setState(() => _loading = true);
      final appleCredentials = await SignInWithApple.getAppleIDCredential(
        scopes: _appleScopes,
        webAuthenticationOptions: WebAuthenticationOptions(
          clientId: _appleClientId, 
          redirectUri: Uri.parse(_appleReturnUrl)
        )
      );

      final user = await _authenticateApple(appleCredentials);

      setState(() {
        _user = user;
        _loading = false;
      });
    } catch (error) {
      print(error);
    }
  }

  void _signoutGoogle() {
    setState(() => _user = null);
    _googleSignIn.disconnect();
  }

  void _signoutApple() {
    setState(() => _user = null);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Google Signin'),
        actions: [
          IconButton(
            onPressed: _signoutGoogle, 
            icon: const FaIcon(FontAwesomeIcons.arrowRightFromBracket)
        )
        ],
      ),
      body: Center(
        // child: Builder( // solo con google signin
        //   builder: (context) {
        //     if(_currentUser == null){
        //       return _LoginButton(onPress: _signin);
        //     }
        //
        //     return Column(
        //       mainAxisAlignment: MainAxisAlignment.center,
        //       children: [
        //         ListTile(
        //           leading: GoogleUserCircleAvatar(
        //             identity: _currentUser!,
        //           ),
        //           title: Text(_currentUser!.displayName ?? 'No name'),
        //           subtitle: Text(_currentUser!.email),
        //         )
        //       ],
        //     );
        //   },
        // ),

        child: Builder(
          builder: (context) {
            if(_loading) return const _LoadingOverlay();

            if(_user == null) {
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _GoogleButton(onPress: _signinGoogle),
                  const SizedBox(height: 10.0),
                  _AppleButton(onPress: _signinGoogle)
                ],
              );
            }
            
            return ListTile(
              leading: CircleAvatar(
                backgroundImage: _user!.picture == null ? null : NetworkImage(_user!.picture!)
              ),
              title: Text(_user!.name),
              subtitle: Text(_user!.email),
            );
          },
        ),
      )
    );
  }
}

class _LoadingOverlay extends StatelessWidget {
  const _LoadingOverlay({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const SizedBox.expand(
      child: DecoratedBox(
        decoration: BoxDecoration(color: Colors.black38),
        child: Center(child: CircularProgressIndicator(color: Colors.white)),
      ),
    );
  }
}

class _GoogleButton extends StatelessWidget {
  final VoidCallback onPress;

  const _GoogleButton({Key? key, required this.onPress}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;

    return SizedBox(
      width: size.width * 0.5,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          primary: Colors.black,
          padding: const EdgeInsets.symmetric(vertical: 10.0)
        ),
        onPressed: onPress, 
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Text('Signin with'),
            SizedBox(width: 10.0),
            FaIcon(FontAwesomeIcons.google)
          ],
        ) 
      ),
    );
  }
}

class _AppleButton extends StatelessWidget {
  final VoidCallback onPress;

  const _AppleButton({Key? key, required this.onPress}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;

    return SizedBox(
      width: size.width * 0.5,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          primary: Colors.black,
          padding: const EdgeInsets.symmetric(vertical: 10.0)
        ),
        onPressed: onPress, 
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Text('Signin with'),
            SizedBox(width: 10.0),
            FaIcon(FontAwesomeIcons.apple)
          ],
        ) 
      ),
    );
  }
}