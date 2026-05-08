class NutritionSnapshot {
  const NutritionSnapshot({
    required this.calories,
    required this.proteinGrams,
    required this.carbsGrams,
    required this.fatGrams,
  });

  final int calories;
  final double proteinGrams;
  final double carbsGrams;
  final double fatGrams;

  factory NutritionSnapshot.fromJson(Map<String, Object?> json) {
    return NutritionSnapshot(
      calories: (json['calories'] as num).toInt(),
      proteinGrams: (json['proteinGrams'] as num).toDouble(),
      carbsGrams: (json['carbsGrams'] as num).toDouble(),
      fatGrams: (json['fatGrams'] as num).toDouble(),
    );
  }
}

class MealItem {
  const MealItem({
    required this.name,
    required this.quantity,
    required this.unit,
    required this.calories,
    required this.proteinGrams,
    required this.carbsGrams,
    required this.fatGrams,
    required this.source,
    this.originalText,
    this.canonicalName,
    this.externalSource,
    this.externalId,
    this.sourceUrl,
    this.license,
    this.confidence,
    this.needsReview,
  });

  final String name;
  final double quantity;
  final String unit;
  final int calories;
  final double proteinGrams;
  final double carbsGrams;
  final double fatGrams;
  final String source;
  final String? originalText;
  final String? canonicalName;
  final String? externalSource;
  final String? externalId;
  final String? sourceUrl;
  final String? license;
  final double? confidence;
  final bool? needsReview;

  factory MealItem.fromJson(Map<String, Object?> json) {
    return MealItem(
      name: json['name'] as String,
      quantity: (json['quantity'] as num).toDouble(),
      unit: json['unit'] as String,
      calories: (json['calories'] as num).toInt(),
      proteinGrams: (json['proteinGrams'] as num).toDouble(),
      carbsGrams: (json['carbsGrams'] as num).toDouble(),
      fatGrams: (json['fatGrams'] as num).toDouble(),
      source: json['source'] as String? ?? 'backend_estimate',
      originalText: json['originalText'] as String?,
      canonicalName: json['canonicalName'] as String?,
      externalSource: json['externalSource'] as String?,
      externalId: json['externalId'] as String?,
      sourceUrl: json['sourceUrl'] as String?,
      license: json['license'] as String?,
      confidence: (json['confidence'] as num?)?.toDouble(),
      needsReview: json['needsReview'] as bool?,
    );
  }

  Map<String, Object?> toJson() => {
        'name': name,
        'quantity': quantity,
        'unit': unit,
        'calories': calories,
        'proteinGrams': proteinGrams,
        'carbsGrams': carbsGrams,
        'fatGrams': fatGrams,
        'source': source,
        if (originalText != null) 'originalText': originalText,
        if (canonicalName != null) 'canonicalName': canonicalName,
        if (externalSource != null) 'externalSource': externalSource,
        if (externalId != null) 'externalId': externalId,
        if (sourceUrl != null) 'sourceUrl': sourceUrl,
        if (license != null) 'license': license,
        if (confidence != null) 'confidence': confidence,
        if (needsReview != null) 'needsReview': needsReview,
      };

  MealItem copyWith({
    String? name,
    double? quantity,
    String? unit,
    int? calories,
    double? proteinGrams,
    double? carbsGrams,
    double? fatGrams,
    String? source,
    String? originalText,
    String? canonicalName,
    String? externalSource,
    String? externalId,
    String? sourceUrl,
    String? license,
    double? confidence,
    bool? needsReview,
  }) {
    return MealItem(
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      calories: calories ?? this.calories,
      proteinGrams: proteinGrams ?? this.proteinGrams,
      carbsGrams: carbsGrams ?? this.carbsGrams,
      fatGrams: fatGrams ?? this.fatGrams,
      source: source ?? this.source,
      originalText: originalText ?? this.originalText,
      canonicalName: canonicalName ?? this.canonicalName,
      externalSource: externalSource ?? this.externalSource,
      externalId: externalId ?? this.externalId,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      license: license ?? this.license,
      confidence: confidence ?? this.confidence,
      needsReview: needsReview ?? this.needsReview,
    );
  }
}

class FoodMention {
  const FoodMention({
    required this.originalText,
    required this.canonicalEnglishName,
    required this.quantity,
    required this.unit,
    required this.confidence,
    required this.marketProduct,
    this.brand,
    this.barcode,
  });

  final String originalText;
  final String canonicalEnglishName;
  final double quantity;
  final String unit;
  final double confidence;
  final bool marketProduct;
  final String? brand;
  final String? barcode;

  factory FoodMention.fromJson(Map<String, Object?> json) {
    return FoodMention(
      originalText: json['originalText'] as String,
      canonicalEnglishName: json['canonicalEnglishName'] as String,
      quantity: (json['quantity'] as num).toDouble(),
      unit: json['unit'] as String,
      confidence: (json['confidence'] as num).toDouble(),
      marketProduct: json['marketProduct'] as bool? ?? false,
      brand: json['brand'] as String?,
      barcode: json['barcode'] as String?,
    );
  }
}

class FoodCandidateGroup {
  const FoodCandidateGroup({
    required this.mention,
    required this.candidates,
    this.reason,
  });

  final FoodMention mention;
  final List<MealItem> candidates;
  final String? reason;

  factory FoodCandidateGroup.fromJson(Map<String, Object?> json) {
    return FoodCandidateGroup(
      mention: FoodMention.fromJson(json['mention'] as Map<String, Object?>),
      candidates: (json['candidates'] as List<Object?>? ?? const [])
          .cast<Map<String, Object?>>()
          .map(MealItem.fromJson)
          .toList(),
      reason: json['reason'] as String?,
    );
  }
}

class MealProposal {
  const MealProposal({
    required this.id,
    required this.title,
    required this.confidence,
    required this.requiresConfirmation,
    required this.trustedAutoCommitEligible,
    required this.nutrition,
    required this.items,
  });

  final String id;
  final String title;
  final double confidence;
  final bool requiresConfirmation;
  final bool trustedAutoCommitEligible;
  final NutritionSnapshot nutrition;
  final List<MealItem> items;

  factory MealProposal.fromJson(Map<String, Object?> json) {
    return MealProposal(
      id: json['id'] as String,
      title: json['title'] as String,
      confidence: (json['confidence'] as num).toDouble(),
      requiresConfirmation: json['requiresConfirmation'] as bool,
      trustedAutoCommitEligible: json['trustedAutoCommitEligible'] as bool,
      nutrition: NutritionSnapshot.fromJson(json['nutrition'] as Map<String, Object?>),
      items: (json['items'] as List<Object?>).cast<Map<String, Object?>>().map(MealItem.fromJson).toList(),
    );
  }
}

class Meal {
  const Meal({
    required this.id,
    required this.title,
    required this.occurredAt,
    required this.nutrition,
    required this.items,
  });

  final String id;
  final String title;
  final DateTime occurredAt;
  final NutritionSnapshot nutrition;
  final List<MealItem> items;

  factory Meal.fromJson(Map<String, Object?> json) {
    return Meal(
      id: json['id'] as String,
      title: json['title'] as String,
      occurredAt: DateTime.parse(json['occurredAt'] as String),
      nutrition: NutritionSnapshot.fromJson(json['nutrition'] as Map<String, Object?>),
      items: (json['items'] as List<Object?>).cast<Map<String, Object?>>().map(MealItem.fromJson).toList(),
    );
  }
}

class DailySummary {
  const DailySummary({
    required this.date,
    required this.consumed,
    required this.target,
    required this.remaining,
    required this.meals,
  });

  final String date;
  final NutritionSnapshot consumed;
  final NutritionSnapshot target;
  final NutritionSnapshot remaining;
  final List<Meal> meals;

  factory DailySummary.fromJson(Map<String, Object?> json) {
    return DailySummary(
      date: json['date'] as String,
      consumed: NutritionSnapshot.fromJson(json['consumed'] as Map<String, Object?>),
      target: NutritionSnapshot.fromJson(json['target'] as Map<String, Object?>),
      remaining: NutritionSnapshot.fromJson(json['remaining'] as Map<String, Object?>),
      meals: (json['meals'] as List<Object?>).cast<Map<String, Object?>>().map(Meal.fromJson).toList(),
    );
  }
}

class MealTemplate {
  const MealTemplate({
    required this.id,
    required this.title,
    required this.trustedAutoCommitEnabled,
    required this.nutrition,
    required this.items,
    required this.aliases,
  });

  final String id;
  final String title;
  final bool trustedAutoCommitEnabled;
  final NutritionSnapshot nutrition;
  final List<MealItem> items;
  final List<String> aliases;

  factory MealTemplate.fromJson(Map<String, Object?> json) {
    return MealTemplate(
      id: json['id'] as String,
      title: json['title'] as String,
      trustedAutoCommitEnabled: json['trustedAutoCommitEnabled'] as bool,
      nutrition: NutritionSnapshot.fromJson(json['nutrition'] as Map<String, Object?>),
      items: (json['items'] as List<Object?>).cast<Map<String, Object?>>().map(MealItem.fromJson).toList(),
      aliases: (json['aliases'] as List<Object?>? ?? const []).cast<String>(),
    );
  }

  Map<String, Object?> toUpdateJson() => {
        'title': title,
        'trustedAutoCommitEnabled': trustedAutoCommitEnabled,
        'items': items.map((item) => item.toJson()).toList(),
        'aliases': aliases,
      };
}
