import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Chino')),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.dataset_outlined, size: 56),
                    const SizedBox(height: 16),
                    Text('YOLO dataset annotation', style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.folder_open),
                      label: const Text('Import dataset'),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.description_outlined),
                      label: const Text('Open project'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}
