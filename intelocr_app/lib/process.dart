import 'dart:convert';

import 'package:dio/dio.dart';
import 'dart:io';
import 'drawerPage.dart';
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

class _MyHomePageState extends State<MyHomePage> with SingleTickerProviderStateMixin{

  final TextEditingController _controller = TextEditingController();
  List<String>? mednameList;
  String? _response = '';
  String? detected_words='';
  bool loading_img_results=false;
  File? _imageFile;
  List<String> _messages = [];
  final ImagePicker _picker = ImagePicker();
  late AnimationController animationController;
  late Animation<Color?> _colorAnimation;

  @override
  void initState() {
    super.initState();
    
    animationController= AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);

    _colorAnimation = ColorTween(
      begin: Colors.blueAccent,
      end: Colors.redAccent,
    ).animate(animationController);
  
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

   Widget _showLoader(File? img){
    return  Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            Text('Fetching results...',style: TextStyle(fontSize: 15)),
            CircularProgressIndicator(
              strokeWidth: 8.0,
              color: Colors.blue,
            ),
          ],
        ),
      );
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

     String? out_txt="";
    final dio = Dio(BaseOptions(
      // baseUrl: 'http://172.18.42.51:8000',
      connectTimeout: Duration(minutes: 50), 
      receiveTimeout: Duration(seconds: 150),
      sendTimeout: Duration(seconds: 50),
    ),);
    var imageFile,data_txt,data_img,response_txt,response_img;
    // Send the POST request with error handling
  if(img!=null){
    setState(() {
           _messages.add("Wait fetching results for your prescription...");
           loading_img_results=true;
           });
           
    imageFile = await MultipartFile.fromFile(img.path,filename: img.name);
    data_img=FormData.fromMap({
      'file': imageFile
    });
    
    try {
     response_img = await dio.post(
      'http://172.18.42.51:8000/upload_file',
      data: data_img);
    if (response_img.statusCode == 200) {
      var decodedImg=json.decode(json.encode(response_img.data));
      // _response = decodedJson['response'];
      detected_words=decodedImg["detected_words"].join(", ");
      out_txt="These are the detected medicine names: "+detected_words!;
      setState(() {
          //  _messages.add(_response!);});
           _messages.add(out_txt!);
           loading_img_results=false; });
      if(detected_words!="" || detected_words!=null){
        mednameList = detected_words!.split(", ");
        String input_txt="Give me the use of "+mednameList!.first +" as well as it's side effects.";
        sendMessage(input_txt,null);
      }
      
      
  }
  } 
  on DioError catch (e) {
    if (e.response?.statusCode == 405) {
      print('Error 405: Method Not Allowed. Check if POST is supported by the server.');
    } else {
      print('Error: ${e.message}');
    }
  }
      
  }
  
  if(message!=null){
    data_txt=json.encode({
      'prompt': message,
    });
    response_txt = await dio.post(
      'http://172.18.42.51:8000/generate', 
      data: data_txt);
        if (response_txt.statusCode == 200) {
      var decodedJson=json.decode(json.encode(response_txt.data));
      _response = decodedJson['response'];
      // detected_words=decodedJson['detected_words'];
      setState(() {
           _messages.add(_response!);});
      if(mednameList!="" || mednameList!=null){
      String input_txt="What are the substitute medicines for "+mednameList!.first +" as well as it's side effects.";
      setState(() {
           _messages.add(input_txt);});
      sendMessage(input_txt,null);
      mednameList=null;
  
        }
        
  }
  }
    
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

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
      drawer: DrawerScreen(),
      body: SafeArea(
      child:Expanded(child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Expanded(
            child: Column(children: [  
        Container(child:  _imageFile != null
            ? (loading_img_results&& mednameList==null) ?_showLoader(_imageFile): GestureDetector(child:  ClipRRect(
                borderRadius: BorderRadius.circular(20.0),
                child: AnimatedBuilder(
        animation: _colorAnimation,
        builder: (context, child) {
          return Container(
                  width: 200,  // Bounded width
                  height: 200, // Bounded height
                  decoration: BoxDecoration(
              border: Border.all(
                color: _colorAnimation.value ?? Colors.transparent,
                width: 4,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
                  child: child, // Adjust to fit within bounds
                  );
                },
                child: Image.file(
                    _imageFile!,
                    fit: BoxFit.cover,
                ),
              )),onTap: _showImagePickerOptions,)
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

