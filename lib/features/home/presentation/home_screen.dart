import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/route_constants.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/privacy_badge.dart';
import '../../monetization/presentation/banner_ad_widget.dart';
import '../../monetization/presentation/pro_upgrade_sheet.dart';
import '../../monetization/providers/monetization_provider.dart';
import '../providers/recent_tools_provider.dart';
import 'widgets/tool_card.dart';
import 'widgets/tool_category_section.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  void _navigateToTool(BuildContext context, WidgetRef ref, String route) {
    ref.read(recentToolsProvider.notifier).recordToolUsage(route);
    context.push(route);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isPro = ref.watch(isProProvider);

    return AppScaffold(
      title: AppConstants.appName,
      showBackButton: false,
      actions: [
        IconButton(
          icon: Icon(
            isPro ? Icons.star_rounded : Icons.auto_awesome_rounded,
            color: isPro ? Colors.amber : theme.colorScheme.primary,
          ),
          tooltip: isPro ? 'Pro Active' : 'FileWorks Pro',
          onPressed: () => ProUpgradeSheet.show(context),
        ),
      ],
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(top: 8, bottom: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // App Tagline & Privacy Badge
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppConstants.appTagline,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'All tools run 100% on your device',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      const PrivacyBadge(compact: true),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // PDF Category
                  ToolCategorySection(
                    title: 'PDF TOOLS',
                    subtitle: 'Local document processing',
                    children: [
                      ToolCard(
                        title: 'Merge PDF',
                        description: 'Combine multiple documents',
                        icon: Icons.call_merge_rounded,
                        color: const Color(0xFF2563EB),
                        onTap: () => _navigateToTool(context, ref, RouteConstants.pdfMerge),
                      ),
                      ToolCard(
                        title: 'Split PDF',
                        description: 'Extract pages or split by range',
                        icon: Icons.call_split_rounded,
                        color: const Color(0xFF0284C7),
                        onTap: () => _navigateToTool(context, ref, RouteConstants.pdfSplit),
                      ),
                      ToolCard(
                        title: 'Rotate PDF',
                        description: 'Turn pages 90°, 180° or 270°',
                        icon: Icons.rotate_right_rounded,
                        color: const Color(0xFF0D9488),
                        onTap: () => _navigateToTool(context, ref, RouteConstants.pdfRotate),
                      ),
                      ToolCard(
                        title: 'Reorder PDF',
                        description: 'Drag & re-arrange pages',
                        icon: Icons.reorder_rounded,
                        color: const Color(0xFF4F46E5),
                        onTap: () => _navigateToTool(context, ref, RouteConstants.pdfReorder),
                      ),
                      ToolCard(
                        title: 'Compress PDF',
                        description: 'Reduce file size locally',
                        icon: Icons.compress_rounded,
                        color: const Color(0xFF7C3AED),
                        onTap: () => _navigateToTool(context, ref, RouteConstants.pdfCompress),
                      ),
                      ToolCard(
                        title: 'PDF to Image',
                        description: 'Export pages to JPG or PNG',
                        icon: Icons.photo_library_rounded,
                        color: const Color(0xFFD97706),
                        onTap: () => _navigateToTool(context, ref, RouteConstants.pdfToImage),
                      ),
                      ToolCard(
                        title: 'Image to PDF',
                        description: 'Convert pictures into a PDF',
                        icon: Icons.picture_as_pdf_rounded,
                        color: const Color(0xFFDC2626),
                        onTap: () => _navigateToTool(context, ref, RouteConstants.imageToPdf),
                      ),
                    ],
                  ),

                  // Image Category
                  ToolCategorySection(
                    title: 'IMAGE TOOLS',
                    subtitle: 'Fast offline compression & resizing',
                    children: [
                      ToolCard(
                        title: 'Compress Image',
                        description: 'Reduce image file size',
                        icon: Icons.tune_rounded,
                        color: const Color(0xFF059669),
                        onTap: () => _navigateToTool(context, ref, RouteConstants.imageCompress),
                      ),
                      ToolCard(
                        title: 'Resize Image',
                        description: 'Change pixel dimensions',
                        icon: Icons.aspect_ratio_rounded,
                        color: const Color(0xFF0891B2),
                        onTap: () => _navigateToTool(context, ref, RouteConstants.imageResize),
                      ),
                      ToolCard(
                        title: 'Convert Image',
                        description: 'JPG, PNG, and WEBP',
                        icon: Icons.transform_rounded,
                        color: const Color(0xFFEA580C),
                        onTap: () => _navigateToTool(context, ref, RouteConstants.imageConvert),
                      ),
                    ],
                  ),

                  // File Category
                  ToolCategorySection(
                    title: 'FILE TOOLS',
                    subtitle: 'Local archives and organization',
                    children: [
                      ToolCard(
                        title: 'Create ZIP',
                        description: 'Compress files into an archive',
                        icon: Icons.folder_zip_rounded,
                        color: const Color(0xFF9333EA),
                        onTap: () => _navigateToTool(context, ref, RouteConstants.createZip),
                      ),
                      ToolCard(
                        title: 'Extract ZIP',
                        description: 'Safe extraction without Zip Slip',
                        icon: Icons.unarchive_rounded,
                        color: const Color(0xFF475569),
                        onTap: () => _navigateToTool(context, ref, RouteConstants.extractZip),
                      ),
                      ToolCard(
                        title: 'Batch Rename',
                        description: 'Rename files with patterns',
                        icon: Icons.drive_file_rename_outline_rounded,
                        color: const Color(0xFF0284C7),
                        onTap: () => _navigateToTool(context, ref, RouteConstants.batchRename),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const BannerAdContainer(),
        ],
      ),
    );
  }
}
