import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:space_texting/app/services/dialog_helper.dart';
import 'package:space_texting/app/services/socket_io_service.dart';
import 'package:space_texting/app/services/database_helper.dart';
import 'package:space_texting/constants/assets.dart'; // Import the database helper

class ChatController extends GetxController {
  late SocketService socketService;
  var messages = <Map<String, dynamic>>[].obs; // Store messages
  var isConnected = false.obs;
  DatabaseHelper dbHelper = DatabaseHelper(); // Initialize the database helper
  RxBool isBgActive = true.obs;

  RxInt currentIndex = 0.obs;

  RxList<String> backgroundImages = <String>[
    Assets.assetsBackground,
    Assets.assetsBg2,
  ].obs;

  @override
  void onInit() {
    super.onInit();
    socketService = SocketService();
  }

  // Connect to the socket
  void connectSocket(String userId, String targetUserId) {
    print("connection request send");
    socketService.connectSocket(userId, targetUserId);

    // Load previous chat history from the database
    loadMessagesFromDb(userId, targetUserId);

    // Listen for socket connection events
    socketService.socket?.on('connect', (_) {
      isConnected.value = true;
      print('Connected to the socket');
    });

    socketService.socket?.on('disconnect', (_) {
      isConnected.value = false;
      print('Disconnected from the socket');
    });

    // Listen for incoming messages
    socketService.socket?.on('receive_message', (data) async {
      print("data get ${data}");
      messages.add(data); // Add the received message to the list

      // Save message to the local database
      await dbHelper.insertMessage(data);
    });

    // Listen for incoming messages
    socketService.socket?.on('message_deleted', (data) async {
      print("data get ${data}");
      messages.add(data); // Add the received message to the list

      // Save message to the local database
      deleteMessage(data["message"], data["date"], data["time"]);
    });
  }

  // Send a message
  void sendMessage(String senderId, String receiverId, String message,
      String type, String time, String date, String receverName) async {
    if (isConnected.value) {
      // Send the message via the socket
      socketService.sendMessage(
          senderId, receiverId, message, type, time, date);

      // Add the message to the local list and database
      Map<String, dynamic> newMessage = {
        'senderId': senderId,
        'receiverId': receiverId,
        'message': message,
        'isSender': 1,
        'type': type,
        'time': time,
        'date': date,
      };

      messages.add(newMessage);
      await dbHelper.insertMessage(newMessage);

      // Save the user ID to the chat users list
      await dbHelper.insertOrUpdateChatUser(
          receiverId, receverName, date, time, message);
      currentIndex.value = messages.length - 1;
    } else {
      print('Not connected to the socket');
    }
  }

  Future<void> loadMessagesFromDb(String userId, String targetUserId) async {
    // Fetch messages from the database
    List<Map<String, dynamic>> localMessages = List<Map<String, dynamic>>.from(
        await dbHelper.getMessages(
            userId, targetUserId)); // Make a mutable copy

    // Sort messages by date and time
    localMessages.sort((a, b) {
      DateTime dateA = DateFormat('MM-dd-yy').parse(a['date']);
      DateTime dateB = DateFormat('MM-dd-yy').parse(b['date']);

      // If the dates are the same, compare time
      if (dateA.compareTo(dateB) == 0) {
        try {
          // Ensure the time strings are trimmed
          String timeAString = a['time'].trim();
          String timeBString = b['time'].trim();

          // Parse the times with 'hh:mma' format (without space between time and AM/PM)
          DateTime timeA = DateFormat('hh:mma').parse(timeAString);
          DateTime timeB = DateFormat('hh:mma').parse(timeBString);

          return timeA.compareTo(timeB);
        } catch (e) {
          // Log the problematic time and the error for debugging
          print("Error parsing time: ${a['time']} or ${b['time']}. Error: $e");
          return 0; // Fallback in case of error
        }
      }
      return dateA.compareTo(dateB); // Compare dates if not the same
    });

    // Add sorted messages to the observable list
    messages.addAll(localMessages);
    currentIndex.value = messages.value.length - 1;

    print("Current Index : ${currentIndex.value}");
  }

  @override
  void onClose() {
    socketService.disconnectSocket();
    super.onClose();
  }

  RxBool isMoreLoading = false.obs;
  void goUp() async {
    print("Current Index : ${currentIndex.value}");
    if ((currentIndex.value >= 2)) {
      isMoreLoading.value = true;
      DialogHelper.showLoading();
      currentIndex.value = currentIndex.value - 2;
      await Future.delayed(const Duration(seconds: 1));
      DialogHelper.hideDialog();
      isMoreLoading.value = false;
      print("Current Index : ${currentIndex.value}");
    }
  }

  void goDown() async {
    if (!(currentIndex.value + 2 > messages.length)) {
      isMoreLoading.value = true;
      DialogHelper.showLoading();
      currentIndex.value = currentIndex.value + 2;
      await Future.delayed(const Duration(seconds: 1));
      DialogHelper.hideDialog();
      isMoreLoading.value = false;
      print("Current Index : ${currentIndex.value}");
    }
  }

  Future<void> clearChat(String senderId, String receiverId) async {
    messages.value = [];
    currentIndex.value = 0;
    dbHelper.clearAllMessages(senderId, receiverId);
  }

  Future<void> deleteMessage(
      String messageText, String messageDate, String messageTime) async {
    currentIndex.value = currentIndex.value - 1;
    // Find the index of the message that matches the given messageText, messageDate, and messageTime
    int messageIndex = messages.indexWhere((message) =>
        message['message'] == messageText &&
        message['date'] == messageDate &&
        message['time'] == messageTime);

    if (messageIndex != -1) {
      // If a match is found, remove the message from the list
      messages.removeAt(messageIndex);

      // Optionally, remove the message from the database if needed
      await dbHelper.deleteMessage(messageText, messageDate, messageTime);

      // Update the current index
      currentIndex.value = messages.value.length - 1;

      print("Message deleted. Current index: ${currentIndex.value}");
    } else {
      print("No matching message found to delete.");
    }
  }
}
