import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:space_texting/app/modules/chat/views/chat_view.dart';
import 'package:space_texting/app/modules/selectChat/controllers/select_chat_controller.dart';
import 'package:space_texting/app/routes/app_pages.dart';
import 'package:space_texting/app/services/date_format.dart';
import 'package:space_texting/app/services/responsive_size.dart';
import 'package:space_texting/constants/assets.dart';
import '../controllers/chat_screen_controller.dart';

// Reusable ChatCard widget
class ChatCard extends StatelessWidget {
  final Map userMap;

  const ChatCard({super.key, required this.userMap});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection("users")
          .doc(userMap["userId"])
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox(); // Placeholder for loading state
        }

        UserHome user =
            UserHome.fromJson(snapshot.data!.data()! as Map<String, dynamic>);

        return ListTile(
          leading: Stack(
            children: [
              CircleAvatar(
                backgroundImage: user.profilePic.isNotEmpty
                    ? NetworkImage(user.profilePic) as ImageProvider
                    : const AssetImage(Assets.assetsDefaultUser),
                radius: 25,
              ),
              if (user.status == "active")
                const Positioned(
                  bottom: 0,
                  right: 0,
                  child: CircleAvatar(
                    backgroundColor: Colors.green,
                    radius: 6,
                  ),
                ),
            ],
          ),
          title: Text(
            "${userMap["name"]}",
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          // subtitle: Text(
          //   userMap["lastMessage"].toString().contains("http")
          //       ? "Media"
          //       : "${userMap["lastMessage"]}", // Update with actual message
          //   style: TextStyle(
          //     fontSize: 14,
          //     color: Colors.grey[400],
          //   ),
          // ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                "${userMap["time"]}", // Replace with actual time
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[400],
                ),
              ),
              // Replace with actual unread message count
              Text(
                getFormattedDate(
                    userMap["date"]), // Update with actual unread message count
                style: const TextStyle(
                  fontSize: 10,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          contentPadding:
              const EdgeInsets.symmetric(vertical: 5, horizontal: 15),
          onTap: () {
            // Navigate to ChatView and pass necessary data
            Get.to(ChatView(
                name: userMap["name"],
                profileImage: user.profilePic,
                targetUserId: user.uid,
                userId: FirebaseAuth.instance.currentUser!.uid));
          },
        );
      },
    );
  }
}

// Main Chat Screen with Background and List of Chat Cards
class ChatScreenView extends GetView<ChatScreenController> {
  const ChatScreenView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Get.toNamed(Routes.SELECT_CHAT);
        },
        child: Container(
          height: 60,
          width: 60,
          decoration: BoxDecoration(
            color: Colors.deepPurple,
            borderRadius: BorderRadius.circular(13),
          ),
          child: const Center(
            child: Icon(
              Icons.add,
              color: Colors.white,
              size: 34,
            ),
          ),
        ),
      ),
      body: Container(
        height: 100.h,
        width: 100.w,
        padding: const EdgeInsets.only(top: 10),
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage(Assets.assetsBackground),
            fit: BoxFit.cover,
          ),
        ),
        child: Obx(
          () => controller.isLoading.value
              ? const Center(
                  child: CircularProgressIndicator(),
                )
              : ListView(
                  physics: const BouncingScrollPhysics(),
                  children: [
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16.0),
                      child: Center(
                        child: Text(
                          "Chats",
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 26,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    ...controller.allChats.map((e) => ChatCard(userMap: e)),
                  ],
                ),
        ),
      ),
    );
  }
}
