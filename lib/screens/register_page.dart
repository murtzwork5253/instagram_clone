// import 'package:flutter/material.dart';
// import 'package:fluttertoast/fluttertoast.dart';
// import 'package:Instagram/screens/auth/login_page.dart';
//
// class RegisterPage extends StatefulWidget {
//   const RegisterPage({super.key});
//
//   @override
//   State<StatefulWidget> createState() => _RegisterPageState();
// }
//
// class _RegisterPageState extends State<StatefulWidget> {
//   final TextEditingController emailController = TextEditingController();
//   final TextEditingController _passwordController = TextEditingController();
//   final TextEditingController usernameController = TextEditingController();
//   final TextEditingController _confirmPasswordController =
//       TextEditingController();
//   final _formKey = GlobalKey<FormState>();
//   bool _obscurePassword = true;
//   bool _isLoading = false;
//
//   // void _register() async {
//   //   if (_formKey.currentState!.validate()) {
//   //     if (_passwordController.text != _confirmPasswordController.text) {
//   //       Fluttertoast.showToast(msg: "Passwords do not match");
//   //       return;
//   //     }
//   //     setState(() {
//   //       _isLoading = true;
//   //     });
//   //     try {
//   //       final UserCredential authResult = await FirebaseAuth.instance.createUserWithEmailAndPassword(
//   //         email: emailController.text.trim(),
//   //         password: _passwordController.text.trim(),
//   //       );
//   //
//   //       final String uid = authResult.user!.uid;
//   //
//   //       await FirebaseFirestore.instance.collection('users').doc(uid).set({
//   //         'email': emailController.text.trim(),
//   //         'username': usernameController.text.trim(),
//   //         'createdAt' : Timestamp.now(),
//   //       });
//   //       Fluttertoast.showToast(msg: "Registration Successful");
//   //
//   //       Navigator.pushReplacement(context, MaterialPageRoute(builder: (context)=>LoginPage()),);
//   //     }
//   //     on FirebaseAuthException catch (e){
//   //       String errorMessage = "Registration Failed";
//   //
//   //       if(e.code=='weak-password'){
//   //         errorMessage="Password should be at least 6 characters.";
//   //       }
//   //       else if(e.code ==  'email-already-in-use'){
//   //         errorMessage = "Email is already in use.";
//   //       }
//   //       else if(e.code == 'invalid-email'){
//   //         errorMessage = "Invalid Email Address";
//   //       }
//   //
//   //       Fluttertoast.showToast(msg: errorMessage);
//   //     }
//   //     finally {
//   //       setState(() {
//   //         _isLoading = false;
//   //       });
//   //     }
//   //   }
//   // }
//
//   void dispose() {
//     emailController.dispose();
//     usernameController.dispose();
//     _passwordController.dispose();
//     _confirmPasswordController.dispose();
//     super.dispose();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return SafeArea(
//       child: Scaffold(
//         resizeToAvoidBottomInset: true,
//         appBar: AppBar(),
//         body: SingleChildScrollView(
//           padding: const EdgeInsets.symmetric(horizontal:20),
//           child: Center(
//             child: Form(
//               key: _formKey,
//               child: Column(
//                 mainAxisAlignment: MainAxisAlignment.center,
//                 children: [
//                   Image.asset("assets/images/instagram.png"),
//                   SizedBox(height: 70),
//                   Container(
//                     width: 343,
//                     height: 50,
//                     decoration: BoxDecoration(
//                       color: Color(0xFF121212),
//                       border: Border.all(color: Colors.white24),
//                       borderRadius: BorderRadius.circular(5),
//                     ),
//                     child: TextFormField(
//                       validator: (value){
//                         if(value==null || value.isEmpty){
//                           return "Email is required";
//                         }
//                         else if(!value.contains('@')){
//                           return "Invalid Email Address";
//                         }
//                         return null;
//                       },
//                       controller: emailController,
//                       keyboardType: TextInputType.emailAddress,
//                       showCursor: true,
//                       onFieldSubmitted: (value) {
//                         FocusScope.of(context).requestFocus(FocusNode());
//                         if (_formKey.currentState!.validate()) {
//                           _formKey.currentState!.save();
//                         }
//                       },
//                       decoration: InputDecoration(
//                         hintText: "Email",
//                         prefixIcon: Icon(Icons.email),
//                         border: OutlineInputBorder(
//                           borderSide: Divider.createBorderSide(context),
//                         ),
//                         focusedBorder: OutlineInputBorder(
//                           borderSide: Divider.createBorderSide(context),
//                         ),
//                         contentPadding: const EdgeInsets.all(8),
//                         enabledBorder: OutlineInputBorder(
//                           borderSide: Divider.createBorderSide(context),
//                         ),
//                         hintStyle: TextStyle(
//                           fontWeight: FontWeight.normal,
//                           color: Color(0xFFFFFFFF),
//                           fontSize: 14,
//                         ),
//                       ),
//                     ),
//                   ),
//                   SizedBox(height: 30),
//                   Container(
//                     width: 343,
//                     height: 50,
//                     decoration: BoxDecoration(
//                       color: Color(0xFF121212),
//                       border: Border.all(color: Colors.white24),
//                       borderRadius: BorderRadius.circular(5),
//                     ),
//                     child: TextFormField(
//                       controller: usernameController,
//                       keyboardType: TextInputType.name,
//                       showCursor: true,
//                       validator: (value){
//                         if(value==null || value.isEmpty){
//                           return "Please enter username";
//                         }
//                         return null;
//                       },
//                       onFieldSubmitted: (value) {
//                         FocusScope.of(context).requestFocus(FocusNode());
//                         if (_formKey.currentState!.validate()) {
//                           _formKey.currentState!.save();
//                         }
//                       },
//                       decoration: InputDecoration(
//                         hintText: "Username",
//                         prefixIcon: Icon(Icons.person),
//                         border: OutlineInputBorder(
//                           borderSide: Divider.createBorderSide(context),
//                         ),
//                         focusedBorder: OutlineInputBorder(
//                           borderSide: Divider.createBorderSide(context),
//                         ),
//                         enabledBorder: OutlineInputBorder(
//                           borderSide: Divider.createBorderSide(context),
//                         ),
//                         contentPadding: const EdgeInsets.all(8),
//                         hintStyle: TextStyle(
//                           fontWeight: FontWeight.normal,
//                           color: Color(0xFFFFFFFF),
//                           fontSize: 14,
//                         ),
//                       ),
//                     ),
//                   ),
//                   SizedBox(height: 30),
//                   Container(
//                     width: 343,
//                     height: 50,
//                     decoration: BoxDecoration(
//                       color: Color(0xFF121212),
//                       border: Border.all(color: Colors.white24),
//                       borderRadius: BorderRadius.circular(5),
//                     ),
//                     child: TextFormField(
//                       controller: _passwordController,
//                       keyboardType: TextInputType.text,
//                       obscureText: _obscurePassword,
//                       showCursor: true,
//                       validator: (value){
//                         if(value==null || value.isEmpty){
//                           return "Please enter password";
//                         }
//                         else if(value.length<6){
//                           return "Password should be at least 6 characters";
//                         }
//                         return null;
//                       },
//                       onFieldSubmitted: (value) {
//                         FocusScope.of(context).requestFocus(FocusNode());
//                         if (_formKey.currentState!.validate()) {
//                           _formKey.currentState!.save();
//                         }
//                       },
//                       decoration: InputDecoration(
//                         hintText: "Password",
//                         prefixIcon: Icon(Icons.lock),
//                         suffixIcon: IconButton(
//                           onPressed: () {
//                             setState(() {
//                               _obscurePassword = !_obscurePassword;
//                             });
//                           },
//                           splashRadius: 5,
//                           icon: Icon(
//                             _obscurePassword
//                                 ? Icons.visibility
//                                 : Icons.visibility_off,
//                           ),
//                         ),
//                         border: OutlineInputBorder(
//                           borderSide: Divider.createBorderSide(context),
//                         ),
//                         focusedBorder: OutlineInputBorder(
//                           borderSide: Divider.createBorderSide(context),
//                         ),
//                         enabledBorder: OutlineInputBorder(
//                           borderSide: Divider.createBorderSide(context),
//                         ),
//                         contentPadding: const EdgeInsets.all(8),
//                         hintStyle: TextStyle(
//                           fontWeight: FontWeight.normal,
//                           color: Color(0xFFFFFFFF),
//                           fontSize: 14,
//                         ),
//                       ),
//                     ),
//                   ),
//                   SizedBox(height: 30),
//                   Container(
//                     width: 343,
//                     height: 50,
//                     decoration: BoxDecoration(
//                       color: Color(0xFF121212),
//                       border: Border.all(color: Colors.white24),
//                       borderRadius: BorderRadius.circular(5),
//                     ),
//                     child: TextFormField(
//                       controller: _confirmPasswordController,
//                       keyboardType: TextInputType.text,
//                       obscureText: _obscurePassword,
//                       showCursor: true,
//                       validator: (value){
//                         if(value==null || value.isEmpty){
//                           return " Please enter password";
//                         }else if(value!=_passwordController.text){
//                           return "Passwords do not match";
//                         }
//                         return null;
//                       },
//                       onFieldSubmitted: (value) {
//                         FocusScope.of(context).requestFocus(FocusNode());
//                         if (_formKey.currentState!.validate()) {
//                           _formKey.currentState!.save();
//                         }
//                       },
//                       decoration: InputDecoration(
//                         hintText: "Confirm Password",
//                         prefixIcon: Icon(Icons.lock),
//                         suffixIcon: IconButton(
//                           onPressed: () {
//                             setState(() {
//                               _obscurePassword = !_obscurePassword;
//                             });
//                           },
//                           splashRadius: 5,
//                           icon: Icon(
//                             _obscurePassword
//                                 ? Icons.visibility
//                                 : Icons.visibility_off,
//                           ),
//                         ),
//                         border: OutlineInputBorder(
//                           borderSide: Divider.createBorderSide(context),
//                         ),
//                         focusedBorder: OutlineInputBorder(
//                           borderSide: Divider.createBorderSide(context),
//                         ),
//                         enabledBorder: OutlineInputBorder(
//                           borderSide: Divider.createBorderSide(context),
//                         ),
//                         contentPadding: const EdgeInsets.all(8),
//                         hintStyle: TextStyle(
//                           fontWeight: FontWeight.normal,
//                           color: Color(0xFFFFFFFF),
//                           fontSize: 14,
//                         ),
//                       ),
//                     ),
//                   ),
//                   SizedBox(height: 50),
//                   SizedBox(
//                     width: 343,
//                     height: 44,
//                     child: ElevatedButton(
//                       onPressed: _isLoading ? null : _register,
//                       style: ElevatedButton.styleFrom(
//                         backgroundColor: Colors.blue,
//                         foregroundColor: Colors.white,
//                         shape: RoundedRectangleBorder(
//                           borderRadius: BorderRadius.circular(5),
//                         ),
//                       ),
//                       child: _isLoading
//                           ? const CircularProgressIndicator(
//                         color: Colors.white,
//                       )
//                           : const Text(
//                         "Sign up",
//                         style: TextStyle(fontSize: 18),
//                       ),
//                     ),
//                   ),
//                   SizedBox(height: 80),
//                   Row(
//                     children: [
//                       Expanded(
//                         child: Divider(color: Colors.white24, thickness: 1),
//                       ),
//                       Padding(
//                         padding: const EdgeInsets.symmetric(horizontal: 10),
//                         child: Text(
//                           "OR",
//                           style: TextStyle(color: Colors.white24),
//                         ),
//                       ),
//                       Expanded(
//                         child: Divider(color: Colors.white24, thickness: 1),
//                       ),
//                     ],
//                   ),
//                   SizedBox(height: 40),
//                   Row(
//                     mainAxisAlignment: MainAxisAlignment.center,
//                     children: [
//                       Text("Already have an account?",style: TextStyle(fontSize: 16,color: Colors.grey),),
//                       TextButton(
//                         style: TextButton.styleFrom(
//                           foregroundColor: Colors.blue,
//                           shape: RoundedRectangleBorder(
//                             borderRadius: BorderRadius.circular(5),
//                           ),
//                         ),
//                         clipBehavior: Clip.hardEdge,
//                         onPressed: () {
//                           Navigator.pushReplacement(
//                             context,
//                             MaterialPageRoute(builder: (context) => LoginPage()),
//                           );
//                         },
//                         child: Text("Log in",style: TextStyle(fontSize: 16,fontWeight: FontWeight.bold),),
//                       ),
//                     ],
//                   ),
//                 ],
//               ),
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }
