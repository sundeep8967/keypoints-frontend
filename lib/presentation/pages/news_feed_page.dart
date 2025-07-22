import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/news/news_bloc.dart';
import '../widgets/news_article_card.dart';
import '../widgets/category_selector.dart';
import '../widgets/loading_shimmer.dart';
import '../../injection_container.dart';

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
          final articles = state is NewsLoaded 
              ? state.articles 
              : (state as NewsByCategoryLoaded).articles;
          
          if (articles.isEmpty) {
            return const Center(
              child: Text(
                'No articles found',
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
            itemCount: articles.length,
            itemBuilder: (context, index) {
              return NewsArticleCard(
                article: articles[index],
                onRead: () {
                  context.read<NewsBloc>().add(
                    MarkArticleAsReadEvent(articleId: articles[index].id),
                  );
                },
              );
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