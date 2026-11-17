import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lamsa_app/core/router/routes.dart';
import 'package:lamsa_app/core/strings.dart';
import 'package:lamsa_app/core/theme/lamsa_colors.dart';
import 'package:lamsa_app/core/theme/spacing.dart';
import 'package:lamsa_app/features/catalog/cubit/product_list_cubit.dart';
import 'package:lamsa_app/features/catalog/data/catalog_repository.dart';
import 'package:lamsa_app/features/catalog/data/list_filters.dart';
import 'package:lamsa_app/features/catalog/presentation/widgets/product_list_body.dart';

/// Category, brand, "new" and "sale" screens: one screen, four scopes.
class ProductListScreen extends StatelessWidget {
  const ProductListScreen({required this.scope, super.key});

  final ListScope scope;

  String? get _fixedTitle => switch (scope) {
        NewScope() => Strings.newArrivals,
        SaleScope() => Strings.sale,
        _ => null,
      };

  String? get _subtitle => switch (scope) {
        NewScope() => Strings.subNew,
        SaleScope() => Strings.subSale,
        _ => null,
      };

  String get _emptyMessage => switch (scope) {
        CategoryScope() => Strings.emptyCategory,
        BrandScope() => Strings.emptyBrand,
        NewScope() => Strings.emptyNew,
        SaleScope() => Strings.emptySale,
        SearchScope() => Strings.searchEmptyTitle,
      };

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          ProductListCubit(context.read<CatalogRepository>(), scope)..load(),
      child: Scaffold(
        appBar: AppBar(
          title: _fixedTitle != null
              ? Text(_fixedTitle!)
              : BlocBuilder<ProductListCubit, ProductListState>(
                  buildWhen: (a, b) =>
                      a.category != b.category || a.brand != b.brand,
                  builder: (context, state) => Text(
                    state.category?.name ?? state.brand?.name ?? '',
                  ),
                ),
          actions: [
            IconButton(
              icon: const Icon(Icons.search),
              tooltip: Strings.search,
              onPressed: () => context.push(Routes.search),
            ),
          ],
        ),
        body: ProductListBody(
          emptyMessage: _emptyMessage,
          subtitle: _subtitle,
        ),
      ),
    );
  }
}

/// Search: a field that sends the raw query to the backend on submit (the
/// backend does the Arabic normalization), then the shared list below it.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ProductListCubit(
        context.read<CatalogRepository>(),
        const SearchScope(),
      ),
      child: Builder(
        builder: (context) {
          final cubit = context.read<ProductListCubit>();
          void submit(String q) => cubit.search(q);
          return Scaffold(
            appBar: AppBar(
              titleSpacing: 0,
              title: Padding(
                padding: const EdgeInsets.only(left: Spacing.pageGutter),
                child: TextField(
                  controller: _controller,
                  autofocus: true,
                  textInputAction: TextInputAction.search,
                  onSubmitted: submit,
                  decoration: InputDecoration(
                    hintText: Strings.searchHint,
                    isDense: true,
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        _controller.clear();
                        submit('');
                      },
                    ),
                  ),
                ),
              ),
            ),
            body: ProductListBody(
              emptyMessage: Strings.searchEmptyTitle,
              subtitleOf: (s) {
                final q = s.filters.value('q');
                return q == null ? null : Strings.searchResultsFor(q);
              },
              idle: _SearchHints(
                onPick: (term) {
                  _controller.text = term;
                  submit(term);
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SearchHints extends StatelessWidget {
  const _SearchHints({required this.onPick});

  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(Spacing.pageGutter),
      children: [
        Text(
          Strings.searchTryHint,
          style: Theme.of(context)
              .textTheme
              .bodyMedium!
              .copyWith(color: context.lamsa.muted),
        ),
        const SizedBox(height: Spacing.sm),
        Wrap(
          spacing: Spacing.sm,
          children: [
            for (final term in Strings.searchSuggestions)
              ActionChip(label: Text(term), onPressed: () => onPick(term)),
          ],
        ),
      ],
    );
  }
}
