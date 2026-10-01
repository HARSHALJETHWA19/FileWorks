import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/constants/route_constants.dart';
import '../features/file_tools/presentation/rename/batch_rename_screen.dart';
import '../features/file_tools/presentation/unzip/extract_zip_screen.dart';
import '../features/file_tools/presentation/zip/create_zip_screen.dart';
import '../features/history/presentation/history_screen.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/image/presentation/compress/image_compress_screen.dart';
import '../features/image/presentation/convert/image_convert_screen.dart';
import '../features/image/presentation/resize/image_resize_screen.dart';
import '../features/pdf/presentation/compress/pdf_compress_screen.dart';
import '../features/pdf/presentation/image_to_pdf/image_to_pdf_screen.dart';
import '../features/pdf/presentation/merge/pdf_merge_screen.dart';
import '../features/pdf/presentation/pdf_to_image/pdf_to_image_screen.dart';
import '../features/pdf/presentation/reorder/pdf_reorder_screen.dart';
import '../features/pdf/presentation/rotate/pdf_rotate_screen.dart';
import '../features/pdf/presentation/split/pdf_split_screen.dart';
import '../features/settings/presentation/privacy_policy_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/monetization/presentation/ad_diagnostics_screen.dart';
import '../shared/models/processing_result.dart';
import '../shared/presentation/result_screen.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<NavigatorState> _shellNavigatorKey = GlobalKey<NavigatorState>();

final appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: RouteConstants.home,
  routes: [
    // Shell Route with persistent BottomNavigationBar
    ShellRoute(
      navigatorKey: _shellNavigatorKey,
      builder: (context, state, child) {
        return ScaffoldWithNavBar(child: child);
      },
      routes: [
        GoRoute(
          path: RouteConstants.home,
          pageBuilder: (context, state) => const NoTransitionPage(
            child: HomeScreen(),
          ),
        ),
        GoRoute(
          path: RouteConstants.history,
          pageBuilder: (context, state) => const NoTransitionPage(
            child: HistoryScreen(),
          ),
        ),
        GoRoute(
          path: RouteConstants.settings,
          pageBuilder: (context, state) => const NoTransitionPage(
            child: SettingsScreen(),
          ),
        ),
      ],
    ),

    // PDF Tool Screens
    GoRoute(
      path: RouteConstants.pdfMerge,
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const PdfMergeScreen(),
    ),
    GoRoute(
      path: RouteConstants.pdfSplit,
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const PdfSplitScreen(),
    ),
    GoRoute(
      path: RouteConstants.pdfRotate,
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const PdfRotateScreen(),
    ),
    GoRoute(
      path: RouteConstants.pdfReorder,
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const PdfReorderScreen(),
    ),
    GoRoute(
      path: RouteConstants.pdfCompress,
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const PdfCompressScreen(),
    ),
    GoRoute(
      path: RouteConstants.pdfToImage,
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const PdfToImageScreen(),
    ),
    GoRoute(
      path: RouteConstants.imageToPdf,
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const ImageToPdfScreen(),
    ),

    // Image Tool Screens
    GoRoute(
      path: RouteConstants.imageCompress,
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const ImageCompressScreen(),
    ),
    GoRoute(
      path: RouteConstants.imageResize,
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const ImageResizeScreen(),
    ),
    GoRoute(
      path: RouteConstants.imageConvert,
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const ImageConvertScreen(),
    ),

    // File Tool Screens
    GoRoute(
      path: RouteConstants.createZip,
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const CreateZipScreen(),
    ),
    GoRoute(
      path: RouteConstants.extractZip,
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const ExtractZipScreen(),
    ),
    GoRoute(
      path: RouteConstants.batchRename,
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const BatchRenameScreen(),
    ),

    // Settings Sub-Screens
    GoRoute(
      path: RouteConstants.privacyPolicy,
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const PrivacyPolicyScreen(),
    ),
    GoRoute(
      path: RouteConstants.adDiagnostics,
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const AdDiagnosticsScreen(),
    ),

    // Result Screen
    GoRoute(
      path: RouteConstants.result,
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final result = state.extra as ProcessingResult;
        return ResultScreen(result: result);
      },
    ),
  ],
);

class ScaffoldWithNavBar extends StatelessWidget {
  final Widget child;

  const ScaffoldWithNavBar({super.key, required this.child});

  int _calculateSelectedIndex(BuildContext context) {
    final String location = GoRouterState.of(context).uri.toString();
    if (location.startsWith(RouteConstants.history)) {
      return 1;
    }
    if (location.startsWith(RouteConstants.settings)) {
      return 2;
    }
    return 0;
  }

  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0:
        GoRouter.of(context).go(RouteConstants.home);
        break;
      case 1:
        GoRouter.of(context).go(RouteConstants.history);
        break;
      case 2:
        GoRouter.of(context).go(RouteConstants.settings);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _calculateSelectedIndex(context),
        onDestinationSelected: (idx) => _onItemTapped(idx, context),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.grid_view_rounded),
            selectedIcon: Icon(Icons.grid_view_rounded),
            label: 'Tools',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_rounded),
            selectedIcon: Icon(Icons.history_rounded),
            label: 'History',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings_rounded),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
