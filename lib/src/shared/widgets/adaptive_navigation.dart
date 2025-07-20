import 'package:flutter/material.dart';
import '../providers/navigation_provider.dart';
import 'responsive_layout.dart';

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

  List<NavigationDestinationInfo> get _destinations => AppPage.values
      .map(
        (page) => NavigationDestinationInfo(title: page.title, icon: page.icon),
      )
      .toList();

  @override
  Widget build(BuildContext context) {
    return ResponsiveLayout(
      mobileLayout: _MobileNavigation(
        onDestinationSelected: onDestinationSelected,
        currentIndex: currentIndex,
        destinations: _destinations,
        child: child,
      ),
      tabletLayout: _TabletNavigation(
        onDestinationSelected: onDestinationSelected,
        currentIndex: currentIndex,
        destinations: _destinations,
        child: child,
      ),
      desktopLayout: _DesktopNavigation(
        onDestinationSelected: onDestinationSelected,
        currentIndex: currentIndex,
        destinations: _destinations,
        child: child,
      ),
    );
  }
}

class NavigationDestinationInfo {
  final String title;
  final IconData icon;

  NavigationDestinationInfo({required this.title, required this.icon});
}

/// 移动端导航（Drawer）
class _MobileNavigation extends StatelessWidget {
  final Widget child;
  final Function(int) onDestinationSelected;
  final int currentIndex;
  final List<NavigationDestinationInfo> destinations;

  const _MobileNavigation({
    required this.child,
    required this.onDestinationSelected,
    required this.currentIndex,
    required this.destinations,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(destinations[currentIndex].title)),
      drawer: _buildDrawer(context),
      body: child,
    );
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
          for (int i = 0; i < destinations.length; i++)
            ListTile(
              leading: Icon(destinations[i].icon),
              title: Text(destinations[i].title),
              selected: currentIndex == i,
              onTap: () {
                onDestinationSelected(i);
                Navigator.pop(context);
              },
            ),
        ],
      ),
    );
  }
}

/// 平板端导航（NavigationRail）
class _TabletNavigation extends StatelessWidget {
  final Widget child;
  final Function(int) onDestinationSelected;
  final int currentIndex;
  final List<NavigationDestinationInfo> destinations;

  const _TabletNavigation({
    required this.child,
    required this.onDestinationSelected,
    required this.currentIndex,
    required this.destinations,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            extended: MediaQuery.of(context).size.width >= 800,
            destinations: destinations
                .map(
                  (d) => NavigationRailDestination(
                    icon: Icon(d.icon),
                    label: Text(d.title),
                  ),
                )
                .toList(),
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
  final List<NavigationDestinationInfo> destinations;

  const _DesktopNavigation({
    required this.child,
    required this.onDestinationSelected,
    required this.currentIndex,
    required this.destinations,
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
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(28, 16, 16, 10),
                  child: Text(
                    'OldSun相机工具箱',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                for (final dest in destinations)
                  NavigationDrawerDestination(
                    icon: Icon(dest.icon),
                    label: Text(dest.title),
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
