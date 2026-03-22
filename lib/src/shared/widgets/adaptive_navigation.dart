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
    return StableWidthBuilder<({AppLayoutMode layoutMode, bool railExtended})>(
      cacheKey: (currentIndex, child),
      resolve: (width) {
        final layoutMode = ResponsiveLayout.resolveMode(width);
        return (
          layoutMode: layoutMode,
          railExtended: layoutMode == AppLayoutMode.tablet && width >= 800,
        );
      },
      builder: (context, layoutState) {
        final layoutMode = layoutState.layoutMode;
        final isMobile = layoutMode == AppLayoutMode.mobile;
        final isTablet = layoutMode == AppLayoutMode.tablet;
        final isDesktop = layoutMode == AppLayoutMode.desktop;

        return Scaffold(
          appBar: isMobile
              ? AppBar(title: Text(_destinations[currentIndex].title))
              : null,
          drawer: isMobile
              ? Drawer(
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
                      for (int i = 0; i < _destinations.length; i++)
                        ListTile(
                          leading: Icon(_destinations[i].icon),
                          title: Text(_destinations[i].title),
                          selected: currentIndex == i,
                          onTap: () {
                            onDestinationSelected(i);
                            Navigator.pop(context);
                          },
                        ),
                    ],
                  ),
                )
              : null,
          body: Row(
            children: [
              if (isDesktop)
                SizedBox(
                  width: 280,
                  child: NavigationDrawer(
                    selectedIndex: currentIndex,
                    onDestinationSelected: onDestinationSelected,
                    children: [
                      const Padding(
                        padding: EdgeInsets.fromLTRB(28, 16, 16, 10),
                        child: Text(
                          'OldSun相机工具箱',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      for (final dest in _destinations)
                        NavigationDrawerDestination(
                          icon: Icon(dest.icon),
                          label: Text(dest.title),
                        ),
                    ],
                  ),
                ),
              if (isTablet)
                NavigationRail(
                  extended: layoutState.railExtended,
                  destinations: _destinations
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
              if (isTablet || isDesktop)
                const VerticalDivider(thickness: 1, width: 1),
              Expanded(child: child),
            ],
          ),
        );
      },
    );
  }
}

class NavigationDestinationInfo {
  final String title;
  final IconData icon;

  NavigationDestinationInfo({required this.title, required this.icon});
}
