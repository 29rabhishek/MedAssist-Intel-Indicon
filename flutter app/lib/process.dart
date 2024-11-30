import 'dart:convert';

import 'package:dio/dio.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:image_picker/image_picker.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {

  final TextEditingController _controller = TextEditingController();
  String? _response = '';
  String? detected_words='';
  File? _imageFile;
  List<String> _messages = [];
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();

  
  }

  Future<void> _pickImage(ImageSource source) async {
    final XFile? pickedFile = await _picker.pickImage(source: source);

    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
        sendMessage(null,pickedFile);
      });
    }
  }

 void _sendMessage() {
    if (_controller.text.isNotEmpty) {
      setState(() {
        _messages.add(_controller.text);
        sendMessage(_messages.last,null);
        _controller.clear();
      });
    }
  }
  Future<void> sendMessage(String? message, XFile? img) async {

    // Create a Dio instance
    var dio = Dio();
    var imageFile,data_txt,data_img,response_txt,response_img;
    // Send the POST request with error handling
  if(img!=null){
   imageFile = await MultipartFile.fromFile(img!.path, filename: img.name);
    data_img=FormData.fromMap({
      'file': imageFile
    });
    response_img = await dio.post(
      'http://172.18.42.51:8000/upload_file', 
      
      data: data_img,
      options: Options(method: 'POST'));
  }
  if(message!=null){
    data_txt=json.encode({
      'prompt': message,
    });
    response_txt = await dio.post(
      'http://172.18.42.51:8000/generate', 
      
      data: data_txt,
      options: Options(headers: {
          'Content-Type': 'application/json',
        },method: 'POST'));
  }
    
  if (response_txt.statusCode == 200) {
      var decodedJson=json.decode(json.encode(response_txt.data));
      _response = decodedJson['response'];
      // detected_words=decodedJson['detected_words'];
      setState(() {
           _messages.add(_response!);});
          //  _messages.add(detected_words!); 
  }
  if (response_img.statusCode == 200) {
      var decodedJson_img=json.decode(json.encode(response_img.data));
      // _response = decodedJson['response'];
      detected_words=decodedJson_img['detected_words'];
      setState(() {
          //  _messages.add(_response!);
           _messages.add(detected_words!); });
  }
  }

//   String extractResponseSection(String input) {
//   int startIndex = input.indexOf('response'); // Start index of "response"
//   int endIndex = input.indexOf(',done true'); // End index of ",done true"
  
//   // Ensure both "response" and ",done true" are found and startIndex comes before endIndex
//   if (startIndex != -1 && endIndex != -1 && startIndex < endIndex) {
//     String result = input.substring(startIndex+8, endIndex); // Extract the substring
//     return result;
//   }
//   return ''; // Return empty string if conditions aren't met
// }

  void _showImagePickerOptions() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: Icon(Icons.camera),
                title: Text('Take a picture'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: Icon(Icons.photo_library),
                title: Text('Choose from gallery'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Welcome to MedAssist'),
      ),
      body: SafeArea(
      child:Expanded(child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Expanded(
            child: Column(children: [  
        Container(child:  _imageFile != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(20.0),
                child: Container(
                  width: 200,  // Bounded width
                  height: 150, // Bounded height
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.blueAccent, width: 3),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Image.file(
                    _imageFile!,
                    fit: BoxFit.cover, // Adjust to fit within bounds
                  ),
                ),
              )
            : ElevatedButton(
                child: Text('Upload your prescription',
                style: TextStyle(fontSize: 18),
              ),onPressed:_showImagePickerOptions ,),
        ), 
        Expanded(child: 
            Container(
              padding: EdgeInsets.all(10),
              color: const Color.fromRGBO(238, 238, 238, 1),
              child: ListView.builder(
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  return Container(
                    margin: EdgeInsets.symmetric(vertical: 5),
                    padding: EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.blue[100],
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(_messages[index]),
                  );
                },
              ),
          ),),
           
            Container(
            padding: EdgeInsets.symmetric(horizontal: 8),
            color: Colors.white,
            child:
             Row(
              children: [
                Expanded(child: 
              TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      border: InputBorder.none,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.send),
                  color: Colors.blue,
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),]) 
          
          )    
          
        ),
      )),);
  
  }
}

