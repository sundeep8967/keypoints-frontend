import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/news/news_bloc.dart';
import '../widgets/news_article_card.dart';
import '../widgets/category_selector.dart';
import '../widgets/loading_shimmer.dart';
import '../../injection_container.dart';
import '../../widgets/native_ad_card.dart';
import '../../services/ad_integration_service.dart';
import '../../services/color_extraction_service.dart';

class NewsFeedPage extends StatefulWidget {
  const NewsFeedPage({super.key});

  @override
  State<NewsFeedPage> createState() => _NewsFeedPageState();
}

class _NewsFeedPageState extends State<NewsFeedPage> {
  String _selectedCategory = 'All';
  final PageController _pageController = PageController();
  
  final List<String> _categories = [
    'All', 'Technology', 'Business', 'Sports', 'Entertainment', 
    'Health', 'Science', 'World', 'Politics'
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<NewsBloc>()..add(const LoadNewsEvent()),
      child: CupertinoPageScaffold(
        backgroundColor: CupertinoColors.black,
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              _buildCategorySelector(),
              Expanded(
                child: _buildNewsContent(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'News',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: CupertinoColors.white,
            ),
          ),
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () {
              context.read<NewsBloc>().add(const RefreshNewsEvent());
            },
            child: const Icon(
              CupertinoIcons.refresh,
              color: CupertinoColors.white,
              size: 24,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySelector() {
    return CategorySelector(
      categories: _categories,
      selectedCategory: _selectedCategory,
      onCategorySelected: (category) {
        setState(() {
          _selectedCategory = category;
        });
        
        if (category == 'All') {
          context.read<NewsBloc>().add(const LoadNewsEvent());
        } else {
          context.read<NewsBloc>().add(LoadNewsByCategoryEvent(category: category));
        }
      },
    );
  }

  Widget _buildNewsContent() {
    return BlocBuilder<NewsBloc, NewsState>(
      builder: (context, state) {
        if (state is NewsLoading) {
          return const LoadingShimmer();
        } else if (state is NewsLoaded || state is NewsByCategoryLoaded) {
          final mixedFeed = state is NewsLoaded 
              ? state.mixedFeed 
              : (state as NewsByCategoryLoaded).mixedFeed;
          
          if (mixedFeed.isEmpty) {
            return const Center(
              child: Text(
                'No content found',
                style: TextStyle(
                  color: CupertinoColors.white,
                  fontSize: 18,
                ),
              ),
            );
          }

          return PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            itemCount: mixedFeed.length,
            itemBuilder: (context, index) {
              final item = mixedFeed[index];
              
              // Check if this item is an ad or an article
              if (AdIntegrationService.isAd(item)) {
                return NativeAdCard(
                  adModel: item,
                  palette: const ColorPalette(
                    primary: CupertinoColors.black,
                    secondary: Color(0xFF1C1C1E),
                    accent: Color(0xFF007AFF),
                    background: CupertinoColors.black,
                    surface: Color(0xFF1C1C1E),
                    onPrimary: CupertinoColors.white,
                    onSecondary: CupertinoColors.white,
                    onAccent: CupertinoColors.white,
                  ),
                );
              } else if (AdIntegrationService.isNewsArticle(item)) {
                return NewsArticleCard(
                  article: item,
                  onRead: () {
                    context.read<NewsBloc>().add(
                      MarkArticleAsReadEvent(articleId: item.id),
                    );
                  },
                );
              } else {
                // Fallback for unknown item types
                return const Center(
                  child: Text(
                    'Unknown content type',
                    style: TextStyle(color: CupertinoColors.white),
                  ),
                );
              }
            },
          );
        } else if (state is NewsError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  CupertinoIcons.exclamationmark_triangle,
                  color: CupertinoColors.systemRed,
                  size: 48,
                ),
                const SizedBox(height: 16),
                Text(
                  'Error: ${state.message}',
                  style: const TextStyle(
                    color: CupertinoColors.white,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                CupertinoButton(
                  onPressed: () {
                    context.read<NewsBloc>().add(const LoadNewsEvent());
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }
        
        return const SizedBox.shrink();
      },
    );
  }
}