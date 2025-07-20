import 'package:flutter/material.dart';
import '../../widgets/common/responsive_layout.dart';

/// 自适应导航组件
class AdaptiveNavigation extends StatelessWidget {
  final Widget child;
  final Function(int) onDestinationSelected;
  final int currentIndex;

  const AdaptiveNavigation({
    super.key,
    required this.child,
    required this.onDestinationSelected,
    required this.currentIndex,
  });

  @override
  Widget build(BuildContext context) {
    return ResponsiveLayout(
      mobileLayout: _MobileNavigation(
        onDestinationSelected: onDestinationSelected,
        currentIndex: currentIndex,
        child: child,
      ),
      tabletLayout: _TabletNavigation(
        onDestinationSelected: onDestinationSelected,
        currentIndex: currentIndex,
        child: child,
      ),
      desktopLayout: _DesktopNavigation(
        onDestinationSelected: onDestinationSelected,
        currentIndex: currentIndex,
        child: child,
      ),
    );
  }
}

/// 移动端导航（Drawer）
class _MobileNavigation extends StatelessWidget {
  final Widget child;
  final Function(int) onDestinationSelected;
  final int currentIndex;

  const _MobileNavigation({
    required this.child,
    required this.onDestinationSelected,
    required this.currentIndex,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_getPageTitle(currentIndex))),
      drawer: _buildDrawer(context),
      body: child,
    );
  }

  String _getPageTitle(int index) {
    switch (index) {
      case 0:
        return 'Exif读取器';
      case 1:
        return '快速分片';
      case 2:
        return '设置';
      case 3:
        return '关于';
      default:
        return 'OldSun相机工具箱';
    }
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(color: Colors.blue),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Icon(Icons.camera, size: 48, color: Colors.white),
                SizedBox(height: 8),
                Text(
                  'OldSun相机工具箱',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          _buildDrawerItem(context, 0, Icons.photo_camera, 'Exif读取器'),
          _buildDrawerItem(context, 1, Icons.folder, '快速分片'),
          _buildDrawerItem(context, 2, Icons.settings, '设置'),
          _buildDrawerItem(context, 3, Icons.info_outline, '关于'),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(
    BuildContext context,
    int index,
    IconData icon,
    String title,
  ) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      selected: currentIndex == index,
      onTap: () {
        onDestinationSelected(index);
        Navigator.pop(context);
      },
    );
  }
}

/// 平板端导航（NavigationRail）
class _TabletNavigation extends StatelessWidget {
  final Widget child;
  final Function(int) onDestinationSelected;
  final int currentIndex;

  const _TabletNavigation({
    required this.child,
    required this.onDestinationSelected,
    required this.currentIndex,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            extended: MediaQuery.of(context).size.width >= 800,
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.photo_camera),
                label: Text('Exif读取器'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.folder),
                label: Text('快速分片'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.settings),
                label: Text('设置'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.info_outline),
                label: Text('关于'),
              ),
            ],
            selectedIndex: currentIndex,
            onDestinationSelected: onDestinationSelected,
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(child: child),
        ],
      ),
    );
  }
}

/// 桌面端导航（永久侧边栏）
class _DesktopNavigation extends StatelessWidget {
  final Widget child;
  final Function(int) onDestinationSelected;
  final int currentIndex;

  const _DesktopNavigation({
    required this.child,
    required this.onDestinationSelected,
    required this.currentIndex,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          SizedBox(
            width: 200,
            child: NavigationDrawer(
              selectedIndex: currentIndex,
              onDestinationSelected: onDestinationSelected,
              children: const [
                Padding(
                  padding: EdgeInsets.fromLTRB(28, 16, 16, 10),
                  child: Text(
                    'OldSun相机工具箱',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                NavigationDrawerDestination(
                  icon: Icon(Icons.photo_camera),
                  label: Text('Exif读取器'),
                ),
                NavigationDrawerDestination(
                  icon: Icon(Icons.folder),
                  label: Text('快速分片'),
                ),
                NavigationDrawerDestination(
                  icon: Icon(Icons.settings),
                  label: Text('设置'),
                ),
                NavigationDrawerDestination(
                  icon: Icon(Icons.info_outline),
                  label: Text('关于'),
                ),
              ],
            ),
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(child: child),
        ],
      ),
    );
  }
}
