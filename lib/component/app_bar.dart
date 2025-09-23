import 'package:badminton/shared/function.dart';
import 'package:flutter/material.dart';

class AppBarHome extends StatelessWidget implements PreferredSizeWidget {
  final int amountItemInCart;

  const AppBarHome({super.key, this.amountItemInCart = 0});

  @override
  Widget build(BuildContext context) {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.white,
      automaticallyImplyLeading: false,
      flexibleSpace: Container(
        margin: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 10),
        padding: const EdgeInsets.symmetric(horizontal: 15),
        child: Row(
          children: [
            Image.asset(
              'assets/icon/home.png',
              color: const Color(0xFF000000),
              width: 25,
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: 15),
                child: Text(
                  'Home',
                  style: TextStyle(
                    fontSize: getResponsiveFontSize(context, fontSize: 20),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),

            IconButton(
              icon: Icon(Icons.settings, color: Color(0xFF000000), size: 25),
              onPressed: () {
                Navigator.pop(context);
              },
            ),
            Stack(
              children: [
                IconButton(
                  icon: Icon(
                    Icons.notifications,
                    color: Color(0xFF000000),
                    size: 25,
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                  },
                ),
                if (amountItemInCart > 0)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      height: 15,
                      width: 15,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFFe4253f),
                      ),
                      child: Text(
                        amountItemInCart > 99
                            ? '99+'
                            : amountItemInCart.toString(),
                        style: TextStyle(
                          fontFamily: 'Kanit',
                          fontSize: amountItemInCart.toString().length <= 1
                              ? 10
                              : amountItemInCart.toString().length == 2
                              ? 9
                              : 8,
                          color: Color.fromARGB(255, 255, 255, 255),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
           ],
        ),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class AppBarSubMain extends StatelessWidget implements PreferredSizeWidget {
  final bool isBack;
  final int amountItemInCart;
  final String title;

  const AppBarSubMain({
    super.key,
    this.isBack = true,
    this.amountItemInCart = 0,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      elevation: 0,
      backgroundColor: Theme.of(context).colorScheme.primary,
      automaticallyImplyLeading: false,
      flexibleSpace: Container(
        margin: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 10),
        padding: const EdgeInsets.symmetric(horizontal: 15),
        child: Row(
          children: [
            if (isBack)
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Color(0xFFFFFFFF)),
                onPressed: () => Navigator.pop(context),
              ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(left: isBack ? 0 : 15),
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: getResponsiveFontSize(context, fontSize: 20),
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFFFFFFFF),
                  ),
                ),
              ),
            ),
            IconButton(
              icon: Icon(Icons.settings, color: Color(0xFFFFFFFF), size: 25),
              onPressed: () {
                Navigator.pop(context);
              },
            ),
            Stack(
              children: [
                IconButton(
                  icon: Icon(
                    Icons.notifications,
                    color: Color(0xFFFFFFFF),
                    size: 25,
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                  },
                ),
                if (amountItemInCart > 0)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      height: 15,
                      width: 15,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFFe4253f),
                      ),
                      child: Text(
                        amountItemInCart > 99
                            ? '99+'
                            : amountItemInCart.toString(),
                        style: TextStyle(
                          fontFamily: 'Kanit',
                          fontSize: amountItemInCart.toString().length <= 1
                              ? 10
                              : amountItemInCart.toString().length == 2
                              ? 9
                              : 8,
                          color: Color.fromARGB(255, 255, 255, 255),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
