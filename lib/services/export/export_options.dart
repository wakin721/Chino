enum UnassignedPolicy { train, flat, reject }

class ExportOptions {
  const ExportOptions({
    required this.destinationPath,
    this.unassignedPolicy = UnassignedPolicy.train,
    this.overwriteExisting = false,
  });

  final String destinationPath;
  final UnassignedPolicy unassignedPolicy;
  final bool overwriteExisting;
}
