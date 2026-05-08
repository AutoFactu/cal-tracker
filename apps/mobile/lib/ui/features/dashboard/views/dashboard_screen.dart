import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/content_frame.dart';
import '../view_models/dashboard_view_model.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<DashboardViewModel>().load());
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<DashboardViewModel>();
    final summary = viewModel.summary;
    return ContentFrame(
      title: 'Today',
      actions: [IconButton(onPressed: viewModel.load, icon: const Icon(Icons.refresh))],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (viewModel.isLoading) const LinearProgressIndicator(),
          if (viewModel.error != null) Text(viewModel.error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          if (summary != null) ...[
            _MetricRow(label: 'Consumed', value: '${summary.consumed.calories} kcal'),
            _MetricRow(label: 'Remaining', value: '${summary.remaining.calories} kcal'),
            _MetricRow(label: 'Protein left', value: '${summary.remaining.proteinGrams} g'),
            const SizedBox(height: 16),
            for (final meal in summary.meals) ListTile(title: Text(meal.title), trailing: Text('${meal.nutrition.calories} kcal')),
          ],
        ],
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(value, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}
